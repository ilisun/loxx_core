#pragma once

#include <cstdint>

namespace routing_core::edgeid {

// 64 бита: [z:8][x:20][y:20][edgeIdx:16]
inline uint64_t make(int z, uint32_t x, uint32_t y, uint32_t edgeIdx) {
  uint64_t id = 0;
  id |= (static_cast<uint64_t>(z & 0xFF) << 56);
  id |= (static_cast<uint64_t>(x & 0xFFFFF) << 36);
  id |= (static_cast<uint64_t>(y & 0xFFFFF) << 16);
  id |= (static_cast<uint64_t>(edgeIdx & 0xFFFF));
  return id;
}

inline void parse(uint64_t id, int& z, uint32_t& x, uint32_t& y, uint32_t& edgeIdx) {
  z = static_cast<int>((id >> 56) & 0xFF);
  x = static_cast<uint32_t>((id >> 36) & 0xFFFFF);
  y = static_cast<uint32_t>((id >> 16) & 0xFFFFF);
  edgeIdx = static_cast<uint32_t>(id & 0xFFFF);
}

} // namespace routing_core::edgeid


