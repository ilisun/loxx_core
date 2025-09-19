#pragma once

#include <sqlite3.h>
#include <stdexcept>
#include <string>

#include "tiler.h"

class SqliteError : public std::runtime_error {
public:
  explicit SqliteError(const std::string& message) : std::runtime_error(message) {}
};

class RoutingDbWriter {
public:
  explicit RoutingDbWriter(const std::string& dbPath);
  ~RoutingDbWriter();

  void createSchemaIfNeeded();
  void writeMetadata(const std::string& key, const std::string& value);

  // Future: insertTile(z,x,y, bbox, version, checksum, profile_mask, data)
  void insertLandTile(int z, int x, int y,
                      const BBox& bbox,
                      int version,
                      const std::string& checksum,
                      int profile_mask,
                      const void* blob_data,
                      size_t blob_size);

private:
  sqlite3* db_ {nullptr};
  void exec(const char* sql);
};


