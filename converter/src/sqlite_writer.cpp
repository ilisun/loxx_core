#include "sqlite_writer.h"

#include <cstdio>
#include <string>
#include "tiler.h"

static int noop_callback(void*, int, char**, char**) { return 0; }

RoutingDbWriter::RoutingDbWriter(const std::string& dbPath) {
  if (sqlite3_open(dbPath.c_str(), &db_) != SQLITE_OK) {
    std::string msg = "Failed to open SQLite DB: ";
    msg += sqlite3_errmsg(db_);
    throw SqliteError(msg);
  }
  exec("PRAGMA journal_mode = WAL;");
  exec("PRAGMA synchronous = NORMAL;");
  exec("PRAGMA foreign_keys = ON;");
}

RoutingDbWriter::~RoutingDbWriter() {
  if (db_) {
    sqlite3_close(db_);
    db_ = nullptr;
  }
}

void RoutingDbWriter::exec(const char* sql) {
  char* errMsg = nullptr;
  if (sqlite3_exec(db_, sql, noop_callback, nullptr, &errMsg) != SQLITE_OK) {
    std::string msg = "SQLite error: ";
    if (errMsg) {
      msg += errMsg;
      sqlite3_free(errMsg);
    }
    throw SqliteError(msg);
  }
}

void RoutingDbWriter::createSchemaIfNeeded() {
  const char* create_tiles =
      "CREATE TABLE IF NOT EXISTS land_tiles (\n"
      "  z INTEGER NOT NULL,\n"
      "  x INTEGER NOT NULL,\n"
      "  y INTEGER NOT NULL,\n"
      "  lat_min REAL NOT NULL,\n"
      "  lon_min REAL NOT NULL,\n"
      "  lat_max REAL NOT NULL,\n"
      "  lon_max REAL NOT NULL,\n"
      "  version INTEGER NOT NULL,\n"
      "  checksum TEXT NOT NULL,\n"
      "  profile_mask INTEGER NOT NULL,\n"
      "  data BLOB NOT NULL\n"
      ");";

  const char* create_idx =
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_land_tiles_zxy ON land_tiles(z,x,y);";

  const char* create_meta =
      "CREATE TABLE IF NOT EXISTS metadata (\n"
      "  key TEXT PRIMARY KEY,\n"
      "  value TEXT\n"
      ");";

  exec("BEGIN TRANSACTION;");
  exec(create_tiles);
  exec(create_idx);
  exec(create_meta);
  exec("COMMIT;");
}

void RoutingDbWriter::writeMetadata(const std::string& key, const std::string& value) {
  const char* upsert_sql =
      "INSERT INTO metadata(key, value) VALUES(?, ?)\n"
      "ON CONFLICT(key) DO UPDATE SET value=excluded.value;";

  sqlite3_stmt* stmt = nullptr;
  if (sqlite3_prepare_v2(db_, upsert_sql, -1, &stmt, nullptr) != SQLITE_OK) {
    std::string msg = "Failed to prepare statement: ";
    msg += sqlite3_errmsg(db_);
    throw SqliteError(msg);
  }

  if (sqlite3_bind_text(stmt, 1, key.c_str(), -1, SQLITE_TRANSIENT) != SQLITE_OK ||
      sqlite3_bind_text(stmt, 2, value.c_str(), -1, SQLITE_TRANSIENT) != SQLITE_OK) {
    std::string msg = "Failed to bind parameters: ";
    msg += sqlite3_errmsg(db_);
    sqlite3_finalize(stmt);
    throw SqliteError(msg);
  }

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    std::string msg = "Failed to execute statement: ";
    msg += sqlite3_errmsg(db_);
    sqlite3_finalize(stmt);
    throw SqliteError(msg);
  }

  sqlite3_finalize(stmt);
}

void RoutingDbWriter::insertLandTile(int z, int x, int y,
                                     const BBox& bbox,
                                     int version,
                                     const std::string& checksum,
                                     int profile_mask,
                                     const void* blob_data,
                                     size_t blob_size) {
  const char* sql =
      "INSERT INTO land_tiles(z,x,y,lat_min,lon_min,lat_max,lon_max,version,checksum,profile_mask,data)\n"
      "VALUES(?,?,?,?,?,?,?,?,?,?,?);";
  sqlite3_stmt* stmt = nullptr;
  if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
    std::string msg = "Failed to prepare tile insert: ";
    msg += sqlite3_errmsg(db_);
    throw SqliteError(msg);
  }
  sqlite3_bind_int(stmt, 1, z);
  sqlite3_bind_int(stmt, 2, x);
  sqlite3_bind_int(stmt, 3, y);
  sqlite3_bind_double(stmt, 4, bbox.lat_min);
  sqlite3_bind_double(stmt, 5, bbox.lon_min);
  sqlite3_bind_double(stmt, 6, bbox.lat_max);
  sqlite3_bind_double(stmt, 7, bbox.lon_max);
  sqlite3_bind_int(stmt, 8, version);
  sqlite3_bind_text(stmt, 9, checksum.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_int(stmt, 10, profile_mask);
  sqlite3_bind_blob(stmt, 11, blob_data, static_cast<int>(blob_size), SQLITE_TRANSIENT);

  if (sqlite3_step(stmt) != SQLITE_DONE) {
    std::string msg = "Failed to insert tile: ";
    msg += sqlite3_errmsg(db_);
    sqlite3_finalize(stmt);
    throw SqliteError(msg);
  }
  sqlite3_finalize(stmt);
}


