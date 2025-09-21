#include "routing_core/router.h"
#include "routing_core/tile_store.h"

#include <flatbuffers/flatbuffers.h>
#include <cmath>
#include <memory>
#include <stdexcept>
#include <queue>
#include <algorithm>
#include <limits>
#include <optional>

#include "land_tile_generated.h"
#include "routing_core/tile_view.h"
#include "routing_core/tiler.h"

namespace routing_core {

struct Router::Impl {
  TileStore store;
  int tileZoom;

  explicit Impl(const std::string& db, const RouterOptions& opt)
    : store(db, opt.tileCacheCapacity), tileZoom(opt.tileZoom) {
    store.setZoom(tileZoom);
  }

  // --- геодезия ---
  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    constexpr double R = 6371000.0;
    const double p1 = lat1 * M_PI/180.0;
    const double p2 = lat2 * M_PI/180.0;
    const double dphi = (lat2 - lat1) * M_PI/180.0;
    const double dl = (lon2 - lon1) * M_PI/180.0;
    const double a = std::sin(dphi/2)*std::sin(dphi/2) + std::cos(p1)*std::cos(p2)*std::sin(dl/2)*std::sin(dl/2);
    const double c = 2 * std::atan2(std::sqrt(a), std::sqrt(1-a));
    return R * c;
  }

  // --- вспомогательные структуры для снапа к ребру ---
  struct EdgeSnap {
    uint32_t edgeIdx{0};
    int segIndex{-1};           // индекс сегмента внутри формы ребра
    double t{0.0};              // параметр проекции на сегмент [0..1]
    double projLat{0.0};
    double projLon{0.0};
    double dist_m{std::numeric_limits<double>::infinity()};
  };

  static void projectPointToSegment(double ax, double ay, double bx, double by,
                                    double px, double py, double& outX, double& outY, double& t) {
    // простая проекция в евклидовой метрике на плоскости WGS84 ~ ок для малых сегментов
    const double vx = bx - ax, vy = by - ay;
    const double wx = px - ax, wy = py - ay;
    double c1 = vx*wx + vy*wy;
    double c2 = vx*vx + vy*vy;
    t = (c2 <= 1e-12) ? 0.0 : std::max(0.0, std::min(1.0, c1 / c2));
    outX = ax + t*vx;
    outY = ay + t*vy;
  }

  static double segHaversine(double lat1,double lon1,double lat2,double lon2) {
    return haversine(lat1,lon1,lat2,lon2);
  }

  // Находит ближайшую проекцию точки на форму любого ребра тайла
  static std::optional<EdgeSnap> snapToEdge(const TileView& view, double lat, double lon) {
    if (!view.valid() || view.edgeCount() == 0) return std::nullopt;
    EdgeSnap best;
    bool has = false;

    std::vector<std::pair<double,double>> tmp;
    tmp.reserve(64);

    for (int ei = 0; ei < view.edgeCount(); ++ei) {
      tmp.clear();
      view.appendEdgeShape(static_cast<uint32_t>(ei), tmp, /*skipFirst*/false);
      if (tmp.size() < 2) continue;
      for (int k = 0; k+1 < static_cast<int>(tmp.size()); ++k) {
        double px, py, t;
        projectPointToSegment(tmp[k].first,  tmp[k].second,
                              tmp[k+1].first, tmp[k+1].second,
                              lat, lon, px, py, t);
        double d = segHaversine(lat, lon, px, py);
        if (d < best.dist_m) {
          has = true;
          best.edgeIdx = static_cast<uint32_t>(ei);
          best.segIndex = k;
          best.t = t;
          best.projLat = px;
          best.projLon = py;
          best.dist_m = d;
        }
      }
    }
    if (!has) return std::nullopt;
    return best;
  }

  struct NodeLabel {
    double g{std::numeric_limits<double>::infinity()}; // стоимость от старта
    int prevNode{-1};
    uint32_t prevEdge{std::numeric_limits<uint32_t>::max()};
  };

  // Проверка доступа и направления
  static bool edgeAllowed(const Routing::Edge* e, Profile profile, int fromNode) {
    auto mask = e->access_mask();
    bool carOk  = (profile == Profile::Car)  && (mask & 1);
    bool footOk = (profile == Profile::Foot) && (mask & 2);
    if (!carOk && !footOk) return false;

    bool oneway = e->oneway();
    if (oneway && fromNode != static_cast<int>(e->from_node())) return false;
    return true;
  }

  static double edgeTraversalTimeSec(const Routing::Edge* e, Profile profile) {
    double speed = (profile == Profile::Car) ? e->speed_mps() : e->foot_speed_mps();
    if (speed <= 0.0) return std::numeric_limits<double>::infinity();
    return e->length_m() / speed;
  }

  // bi-A*: ограничение — в рамках одного тайла (см. TODO ниже)
  RouteResult routeSingleTile(Profile profile,
                              const TileKey& key,
                              TileView& view,
                              const EdgeSnap& startSnap,
                              const EdgeSnap& endSnap) {
    RouteResult rr;

    const int N = view.nodeCount();
    if (N < 2 || view.edgeCount() == 0) {
      rr.status = RouteStatus::NO_ROUTE;
      rr.error_message = "empty tile";
      return rr;
    }

    // Выбираем "ближайший" узел к стартовой проекции: тот конец сегмента ребра, к которому ближе вдоль геометрии
    auto* eStart = view.edgeAt(startSnap.edgeIdx);
    auto* eEnd   = view.edgeAt(endSnap.edgeIdx);

    // Для старта: если t<0.5 — ближе from_node, иначе to_node (грубо; можно интегрировать по длине сегмента)
    int sNode = (startSnap.t <= 0.5) ? static_cast<int>(eStart->from_node()) : static_cast<int>(eStart->to_node());
    // Для финиша — аналогично
    int tNode = (endSnap.t  <= 0.5) ? static_cast<int>(eEnd->from_node())   : static_cast<int>(eEnd->to_node());

    // Начальный/конечный оффсеты по ребру (часть ребра до/после проекции)
    // Это позволит учесть «кусочки» ребра, которые мы не прошли
    auto partialStartSec = [&] {
      // время от реальной проекции до выбранного стартового узла
      // если выбран from, то идём от проекции к from (доля t), иначе — к to (доля 1-t)
      double frac = (sNode == static_cast<int>(eStart->from_node())) ? startSnap.t : (1.0 - startSnap.t);
      return frac * edgeTraversalTimeSec(eStart, profile);
    }();
    auto partialEndSec = [&] {
      // от выбранного "узла финиша" до фактической проекции (в конце маршрута)
      double frac = (tNode == static_cast<int>(eEnd->from_node())) ? (1.0 - endSnap.t) : endSnap.t;
      return frac * edgeTraversalTimeSec(eEnd, profile);
    }();

    // Двунаправленный A*
    struct QNode { int v; double f; };
    struct Cmp { bool operator()(const QNode& a, const QNode& b) const { return a.f > b.f; } };

    std::vector<NodeLabel> F(N), B(N);
    auto hF = [&](int v)->double {
      return haversine(view.nodeLat(v), view.nodeLon(v),
                       view.nodeLat(tNode), view.nodeLon(tNode)) /
             ((profile == Profile::Car) ? 13.9 : 1.4);
    };
    auto hB = [&](int v)->double {
      return haversine(view.nodeLat(v), view.nodeLon(v),
                       view.nodeLat(sNode), view.nodeLon(sNode)) /
             ((profile == Profile::Car) ? 13.9 : 1.4);
    };

    std::priority_queue<QNode, std::vector<QNode>, Cmp> pqF, pqB;

    F[sNode].g = 0.0;
    pqF.push({sNode, hF(sNode)});

    B[tNode].g = 0.0;
    pqB.push({tNode, hB(tNode)});

    double bestMu = std::numeric_limits<double>::infinity();
    int meet = -1;

    auto relaxForward = [&](int u) {
      uint32_t start = view.firstEdge(u);
      uint16_t cnt   = view.edgeCountFrom(u);
      for (uint32_t k = 0; k < cnt; ++k) {
        uint32_t ei = start + k;
        const auto* e = view.edgeAt(ei);
        if (!edgeAllowed(e, profile, u)) continue;
        int v = static_cast<int>(e->to_node());
        double w = edgeTraversalTimeSec(e, profile);
        if (!std::isfinite(w)) continue;
        double cand = F[u].g + w;
        if (cand < F[v].g) {
          F[v].g = cand;
          F[v].prevNode = u;
          F[v].prevEdge = ei;
          pqF.push({v, cand + hF(v)});
          if (B[v].g < std::numeric_limits<double>::infinity()) {
            double mu = cand + B[v].g;
            if (mu < bestMu) { bestMu = mu; meet = v; }
          }
        }
      }
    };

    // Для обратного фронта используем inEdges (входящие)
    auto relaxBackward = [&](int u) {
      const auto& inE = view.inEdgesOf(u);
      for (auto ei : inE) {
        const auto* e = view.edgeAt(ei);
        int from = static_cast<int>(e->from_node());
        // Проверяем доступ и направление "вперёд", но теперь у нас цель — прийти в 'from' из 'u'
        if (!edgeAllowed(e, profile, from)) continue;
        double w = edgeTraversalTimeSec(e, profile);
        if (!std::isfinite(w)) continue;
        double cand = B[u].g + w;
        if (cand < B[from].g) {
          B[from].g = cand;
          B[from].prevNode = u;         // в обратном графе "следующий" — это куда мы шли
          B[from].prevEdge = ei;
          pqB.push({from, cand + hB(from)});
          if (F[from].g < std::numeric_limits<double>::infinity()) {
            double mu = cand + F[from].g;
            if (mu < bestMu) { bestMu = mu; meet = from; }
          }
        }
      }
    };

    // Основной цикл
    while (!pqF.empty() || !pqB.empty()) {
      if (!pqF.empty()) {
        auto q = pqF.top(); pqF.pop();
        if (F[q.v].g + hF(q.v) > bestMu) break; // прекращаем, если уже хуже, чем лучший
        relaxForward(q.v);
      }
      if (!pqB.empty()) {
        auto q = pqB.top(); pqB.pop();
        if (B[q.v].g + hB(q.v) > bestMu) break;
        relaxBackward(q.v);
      }
    }

    if (meet < 0 && sNode != tNode) {
      rr.status = RouteStatus::NO_ROUTE;
      rr.error_message = "no path within tile";
      return rr;
    }

    // Восстановление пути: sNode -> meet по F, meet -> tNode по B (назад)
    std::vector<uint32_t> pathEdges;
    auto v = meet;
    // вперёд
    while (v != sNode && v >= 0) {
      auto pe = F[v].prevEdge;
      if (pe == std::numeric_limits<uint32_t>::max()) break;
      pathEdges.push_back(pe);
      v = F[v].prevNode;
    }
    std::reverse(pathEdges.begin(), pathEdges.end());
    // назад (из meet до tNode по B)
    v = meet;
    while (v != tNode && v >= 0) {
      auto pe = B[v].prevEdge;
      if (pe == std::numeric_limits<uint32_t>::max()) break;
      // pe ведёт из 'from' -> v, нам нужно добавить его в прямом направлении
      // Он уже ориентирован from->to, а мы шли к v, так что нужно добавить именно pe, но порядок точек будет корректен при сборке polyline
      pathEdges.push_back(pe);
      v = B[v].prevNode;
    }

    // Сборка polyline: учесть частичные сегменты старта/финиша
    rr.polyline.clear();
    rr.edge_ids.clear();
    rr.distance_m = 0.0;
    rr.duration_s = 0.0;

    // Стартовый частичный отрезок (от проекции до sNode)
    {
      std::vector<std::pair<double,double>> tmp;
      view.appendEdgeShape(startSnap.edgeIdx, tmp, /*skipFirst*/false);
      if (tmp.size() >= 2) {
        // построим от точки проекции к выбранному узлу
        // найдем пару точек сегмента startSnap.segIndex
        auto a = tmp[startSnap.segIndex];
        auto b = tmp[startSnap.segIndex+1];
        std::pair<double,double> P{startSnap.projLat, startSnap.projLon};
        // если sNode == from, идём P->a, иначе P->b
        std::vector<std::pair<double,double>> part;
        if (sNode == static_cast<int>(view.edgeAt(startSnap.edgeIdx)->from_node())) {
          part.push_back(P); part.push_back(a);
        } else {
          part.push_back(P); part.push_back(b);
        }
        // добавить в итог (пересчитать длину/время)
        if (!rr.polyline.empty() && rr.polyline.back().lat == part.front().first && rr.polyline.back().lon == part.front().second) {
          // ok
        }
        for (size_t i=0;i<part.size();++i) {
          if (i==0 && !rr.polyline.empty() &&
              rr.polyline.back().lat == part[i].first && rr.polyline.back().lon == part[i].second) continue;
          rr.polyline.push_back(Coord{part[i].first, part[i].second});
          if (i>0) rr.distance_m += haversine(part[i-1].first, part[i-1].second, part[i].first, part[i].second);
        }
        rr.duration_s += partialStartSec;
      }
    }

    // Основные рёбра пути
    for (auto ei : pathEdges) {
      rr.edge_ids.push_back(makeEdgeId(key.z, key.x, key.y, ei));
      std::vector<std::pair<double,double>> pts;
      view.appendEdgeShape(ei, pts, /*skipFirst*/rr.polyline.size()>0);
      // добавить точки
      for (auto& p : pts) {
        // исключаем дубли
        if (!rr.polyline.empty() &&
            rr.polyline.back().lat == p.first &&
            rr.polyline.back().lon == p.second) {
          continue;
        }
        if (!rr.polyline.empty()) {
          rr.distance_m += haversine(rr.polyline.back().lat, rr.polyline.back().lon, p.first, p.second);
        }
        rr.polyline.push_back(Coord{p.first, p.second});
      }
      rr.duration_s += edgeTraversalTimeSec(view.edgeAt(ei), profile);
    }

    // Конечный частичный отрезок (от узла tNode до проекции)
    {
      std::vector<std::pair<double,double>> tmp;
      view.appendEdgeShape(endSnap.edgeIdx, tmp, /*skipFirst*/false);
      if (tmp.size() >= 2) {
        auto a = tmp[endSnap.segIndex];
        auto b = tmp[endSnap.segIndex+1];
        std::pair<double,double> P{endSnap.projLat, endSnap.projLon};
        std::vector<std::pair<double,double>> part;
        if (tNode == static_cast<int>(view.edgeAt(endSnap.edgeIdx)->from_node())) {
          part.push_back(a); part.push_back(P);
        } else {
          part.push_back(b); part.push_back(P);
        }
        // добавить
        for (size_t i=0;i<part.size();++i) {
          // исключить дубли
          if (!rr.polyline.empty()) {
            auto& last = rr.polyline.back();
            if (last.lat == part[i].first && last.lon == part[i].second && i==0) continue;
            rr.distance_m += haversine(last.lat, last.lon, part[i].first, part[i].second);
          }
          rr.polyline.push_back(Coord{part[i].first, part[i].second});
        }
        rr.duration_s += partialEndSec;
      }
    }

    rr.status = RouteStatus::OK;
    return rr;
  }

}; // Impl

Router::Router(const std::string& db_path, RouterOptions opt)
  : impl_(std::make_unique<Impl>(db_path, opt)) {}

Router::~Router() = default;

RouteResult Router::route(Profile profile, const std::vector<Coord>& waypoints) {
  RouteResult rr;
  if (waypoints.size() < 2) {
    rr.status = RouteStatus::INTERNAL_ERROR;
    rr.error_message = "need at least 2 waypoints";
    return rr;
  }

  // Пока — требуем, чтобы все точки были в одном тайле (ограничение текущей схемы).
  auto key0 = webTileKeyFor(waypoints.front().lat, waypoints.front().lon, impl_->tileZoom);
  for (size_t i=1;i<waypoints.size();++i) {
    auto ki = webTileKeyFor(waypoints[i].lat, waypoints[i].lon, impl_->tileZoom);
    if (ki.x != key0.x || ki.y != key0.y || ki.z != key0.z) {
      rr.status = RouteStatus::NO_ROUTE;
      rr.error_message = "multi-tile routing not supported yet (schema lacks cross-tile connectivity)";
      return rr;
    }
  }

  auto blob = impl_->store.load(key0.z, key0.x, key0.y);
  if (!blob) { rr.status = RouteStatus::NO_TILE; rr.error_message = "no tile for start"; return rr; }
  TileView view(blob->buffer);
  if (!view.valid() || view.edgeCount() == 0 || view.nodeCount() < 2) {
    rr.status = RouteStatus::NO_ROUTE; rr.error_message = "empty tile"; return rr;
  }

  // строим последовательно по сегментам waypoints[i] -> waypoints[i+1]
  RouteResult total;
  total.status = RouteStatus::OK;

  for (size_t i=0;i+1<waypoints.size();++i) {
    // snap start/end к ребру
    auto sSnap = Impl::snapToEdge(view, waypoints[i].lat,   waypoints[i].lon);
    auto tSnap = Impl::snapToEdge(view, waypoints[i+1].lat, waypoints[i+1].lon);
    if (!sSnap || !tSnap) {
      rr.status = RouteStatus::NO_ROUTE;
      rr.error_message = "failed to snap to edge";
      return rr;
    }

    auto segRes = impl_->routeSingleTile(profile, TileKey{key0.z,key0.x,key0.y}, view, *sSnap, *tSnap);
    if (segRes.status != RouteStatus::OK) return segRes;

    // конкатенация результатов
    if (i == 0) {
      total = segRes;
    } else {
      // склеить polyline без дублирования
      if (!total.polyline.empty() && !segRes.polyline.empty()) {
        auto& last = total.polyline.back();
        auto& first = segRes.polyline.front();
        if (last.lat == first.lat && last.lon == first.lon) {
          // уже совпадают
        } else {
          // добавить соединяющую точку (обычно совпадёт)
        }
      }
      total.polyline.insert(total.polyline.end(), segRes.polyline.begin() + (total.polyline.empty() ? 0 : 1), segRes.polyline.end());
      total.distance_m += segRes.distance_m;
      total.duration_s += segRes.duration_s;
      total.edge_ids.insert(total.edge_ids.end(), segRes.edge_ids.begin(), segRes.edge_ids.end());
    }
  }

  return total;
}

} // namespace routing_core
