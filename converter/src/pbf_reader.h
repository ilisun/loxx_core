#pragma once

#include <string>
#include <unordered_map>
#include <vector>
#include <optional>

#ifdef HAVE_LIBOSMIUM
#  include <osmium/io/any_input.hpp>
#  include <osmium/visitor.hpp>
#  include <osmium/handler.hpp>
#  include <osmium/relations/relations_manager.hpp>
#  include <osmium/osm/way.hpp>
#  include <osmium/osm/node.hpp>
#endif

#include "tiler.h"

struct SimpleNode {
  int64_t id;
  double lat;
  double lon;
};

struct SimpleEdge {
  int64_t from_node_id;
  int64_t to_node_id;
  std::vector<SimpleNode> shape; // includes endpoints
  bool oneway {false};
  int road_class {3}; // default RESIDENTIAL
  bool car_access {true};
  bool foot_access {true};
};

struct TileData {
  TileKey key;
  std::vector<SimpleNode> nodes;
  std::vector<SimpleEdge> edges;
  BBox bbox;
};

class PbfReader {
public:
  explicit PbfReader(std::string input_path, int zoom);
  // Возвращает карту тайл-ключ -> данные тайла
  std::unordered_map<long long, TileData> readAndTile();

private:
  std::string input_path_;
  int zoom_ {14};
};


