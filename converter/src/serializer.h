#pragma once

#include <vector>
#include <cstdint>
#include <unordered_map>

#include "pbf_reader.h"

// Возвращает FlatBuffers blob для одного тайла
std::vector<uint8_t> buildLandTileBlob(const TileData& tile,
                                       uint32_t version,
                                       uint32_t profile_mask);


