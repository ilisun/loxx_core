#pragma once

#include <cstdint>
#include <cmath>
#include <tuple>

struct BBox {
  double lat_min;
  double lon_min;
  double lat_max;
  double lon_max;
};

struct TileKey {
  int z;
  int x;
  int y;
};

inline TileKey tileKeyFor(double lat_deg, double lon_deg, int z = 14) {
  const double lat_rad = lat_deg * M_PI / 180.0;
  const int n = 1 << z;
  int x = static_cast<int>(std::floor((lon_deg + 180.0) / 360.0 * n));
  int y = static_cast<int>(std::floor((1.0 - std::log(std::tan(lat_rad) + 1.0 / std::cos(lat_rad)) / M_PI) / 2.0 * n));
  if (x < 0) x = 0; if (x >= n) x = n - 1;
  if (y < 0) y = 0; if (y >= n) y = n - 1;
  return {z, x, y};
}

inline BBox tileBounds(const TileKey& key) {
  const int n = 1 << key.z;
  const double unit = 1.0 / static_cast<double>(n);
  const double lon_min = key.x * unit * 360.0 - 180.0;
  const double lon_max = (key.x + 1) * unit * 360.0 - 180.0;
  const double y0 = key.y * unit;
  const double y1 = (key.y + 1) * unit;
  const double lat_max = (std::atan(std::sinh(M_PI * (1.0 - 2.0 * y0))) * 180.0 / M_PI);
  const double lat_min = (std::atan(std::sinh(M_PI * (1.0 - 2.0 * y1))) * 180.0 / M_PI);
  return {lat_min, lon_min, lat_max, lon_max};
}


