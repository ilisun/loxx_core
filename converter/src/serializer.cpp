#include "serializer.h"

#include <cmath>
#include <unordered_map>
#include <flatbuffers/flatbuffers.h>
#include "land_tile_generated.h"

using namespace Routing;

std::vector<uint8_t> buildLandTileBlob(const TileData& tile,
                                       uint32_t version,
                                       uint32_t profile_mask) {
  flatbuffers::FlatBufferBuilder fbb(1024);

  // Build local node index used by edges
  std::unordered_map<long long, uint32_t> node_id_to_local;
  std::vector<SimpleNode> local_nodes;
  local_nodes.reserve(tile.nodes.size());
  auto add_node = [&](const SimpleNode& n) {
    auto it = node_id_to_local.find(n.id);
    if (it != node_id_to_local.end()) return it->second;
    uint32_t idx = static_cast<uint32_t>(local_nodes.size());
    node_id_to_local.emplace(n.id, idx);
    local_nodes.push_back(n);
    return idx;
  };

  for (const auto& e : tile.edges) {
    if (!e.shape.empty()) {
      add_node(e.shape.front());
      add_node(e.shape.back());
    }
  }

  std::vector<flatbuffers::Offset<Node>> node_offsets;
  node_offsets.reserve(local_nodes.size());
  for (uint32_t local_id = 0; local_id < local_nodes.size(); ++local_id) {
    const auto& n = local_nodes[local_id];
    int lat_q = static_cast<int>(std::lround(n.lat * 1e6));
    int lon_q = static_cast<int>(std::lround(n.lon * 1e6));
    node_offsets.push_back(CreateNode(fbb,
                                      local_id, // id внутри тайла
                                      lat_q,
                                      lon_q,
                                      0u,
                                      0));
  }
  auto nodes_vec = fbb.CreateVector(node_offsets);

  // Shapes: concatenate per-edge polylines and record start/count
  std::vector<flatbuffers::Offset<ShapePoint>> shape_offsets;
  shape_offsets.reserve(tile.edges.size() * 2);

  // Edges
  std::vector<flatbuffers::Offset<Edge>> fb_edges;
  fb_edges.reserve(tile.edges.size());
  auto haversine = [](double lat1, double lon1, double lat2, double lon2) -> float {
    constexpr double R = 6371000.0;
    const double phi1 = lat1 * M_PI / 180.0;
    const double phi2 = lat2 * M_PI / 180.0;
    const double dphi = (lat2 - lat1) * M_PI / 180.0;
    const double dl = (lon2 - lon1) * M_PI / 180.0;
    const double a = std::sin(dphi/2)*std::sin(dphi/2) + std::cos(phi1)*std::cos(phi2)*std::sin(dl/2)*std::sin(dl/2);
    const double c = 2 * std::atan2(std::sqrt(a), std::sqrt(1-a));
    return static_cast<float>(R * c);
  };

  auto car_speed_for_class = [](int road_class) -> float {
    switch (road_class) {
      case 0: return 27.78f; // MOTORWAY ~100 km/h
      case 1: return 22.22f; // PRIMARY ~80
      case 2: return 16.67f; // SECONDARY ~60
      case 3: return 13.89f; // RESIDENTIAL ~50
      default: return 0.0f;  // foot-only
    }
  };

  for (const auto& e : tile.edges) {
    float length_m = haversine(e.shape.front().lat, e.shape.front().lon,
                               e.shape.back().lat,  e.shape.back().lon);
    float speed_mps = e.car_access ? car_speed_for_class(e.road_class) : 0.0f;
    float foot_speed_mps = e.foot_access ? 1.4f : 0.0f; // ~5 km/h
    uint16_t access_mask = (e.car_access ? 0x1 : 0) | (e.foot_access ? 0x2 : 0);

    // shapes
    uint32_t shape_start = static_cast<uint32_t>(shape_offsets.size());
    for (const auto& sp : e.shape) {
      int lat_q = static_cast<int>(std::lround(sp.lat * 1e6));
      int lon_q = static_cast<int>(std::lround(sp.lon * 1e6));
      shape_offsets.push_back(CreateShapePoint(fbb, lat_q, lon_q));
    }
    uint16_t shape_count = static_cast<uint16_t>(shape_offsets.size() - shape_start);

    // local indices
    uint32_t from_local = node_id_to_local[e.shape.front().id];
    uint32_t to_local   = node_id_to_local[e.shape.back().id];

    auto enc = fbb.CreateString("");
    fb_edges.push_back(CreateEdge(fbb,
      from_local,
      to_local,
      length_m,
      speed_mps,
      foot_speed_mps,
      e.oneway,
      static_cast<RoadClass>(e.road_class),
      access_mask,
      shape_start,
      shape_count,
      enc));
  }
  auto edges_vec = fbb.CreateVector(fb_edges);
  auto shapes_vec = fbb.CreateVector(shape_offsets);

  auto checksum_str = fbb.CreateString("");
  auto land = CreateLandTile(fbb,
                             static_cast<uint16_t>(tile.key.z),
                             static_cast<uint32_t>(tile.key.x),
                             static_cast<uint32_t>(tile.key.y),
                             nodes_vec,
                             edges_vec,
                             shapes_vec,
                             version,
                             checksum_str,
                             profile_mask);
  fbb.Finish(land);

  auto ptr = fbb.GetBufferPointer();
  auto sz = fbb.GetSize();
  return std::vector<uint8_t>(ptr, ptr + sz);
}


