# Спецификация задачи 1: Парсер OSM (PBF) → тайлы Land Graph → SQLite + FlatBuffers

## 1. Цель
Реализовать инструмент (`converter`), который из OSM PBF-файла (страна/регион) создаёт один контейнер `.routingdb` с тайлами land-графа, пригодный для оффлайн-маршрутизации.

## 2. Исходные данные
- **Вход**: `input.osm.pbf` — PBF-файл отдельной страны (например `russia-latest.osm.pbf`) или региона (например Архангельская область).
- **Параметры**: конвертер сам нарезает входные данные на тайлы 4×4 км.
- **Выход**: `output.routingdb` — SQLite контейнер с таблицей тайлов и метаданными.

## 3. Структура контейнера SQLite

### 3.1 Таблица `land_tiles`
```sql
CREATE TABLE land_tiles (
  z INTEGER NOT NULL,
  x INTEGER NOT NULL,
  y INTEGER NOT NULL,
  lat_min REAL NOT NULL,
  lon_min REAL NOT NULL,
  lat_max REAL NOT NULL,
  lon_max REAL NOT NULL,
  version INTEGER NOT NULL,
  checksum TEXT NOT NULL,
  profile_mask INTEGER NOT NULL,
  data BLOB NOT NULL
);
CREATE UNIQUE INDEX idx_land_tiles_zxy ON land_tiles(z,x,y);
```
- z,x,y — классический идентификатор тайла.
- bbox — координаты тайла.
- version — версия схемы.
- checksum — SHA-256 BLOB данных для контроля.
- profile_mask — битовая маска профилей (Car/Foot/Boat).
- data — FlatBuffers blob графа.

### 3.2 Таблица metadata
```sql
CREATE TABLE metadata (
  key TEXT PRIMARY KEY,
  value TEXT
);
```
- Хранит: версию схемы, дату OSM extract, bbox всего пакета, регион.

## 4. Формат FlatBuffers (BLOB)

### 4.1 Черновая схема
```fbs
namespace Routing;

enum RoadClass : byte {
  MOTORWAY = 0,
  PRIMARY = 1,
  SECONDARY = 2,
  RESIDENTIAL = 3,
  FOOTWAY = 4,
  PATH = 5,
  STEPS = 6
}

table Node {
  id: uint;           // id внутри тайла
  lat_q: int;         // квантованные lat * 1e6
  lon_q: int;         // квантованные lon * 1e6
  first_edge: uint;   // смещение первого ребра
  edge_count: ushort; // количество рёбер
}

table Edge {
  from_node: uint;
  to_node: uint;
  length_m: float;
  speed_mps: float;       // одна скорость по умолчанию (Car)
  foot_speed_mps: float;  // отдельная константа для Foot
  oneway: bool;
  road_class: RoadClass;
  access_mask: ushort;    // биты: 1=car, 2=foot, 4=bike
  shape_start: uint;
  shape_count: ushort;
  encoded_polyline: string; // закодированный polyline
}

table ShapePoint {
  lat_q: int;
  lon_q: int;
}

table LandTile {
  z: ushort;
  x: uint;
  y: uint;
  nodes: [Node];
  edges: [Edge];
  shapes: [ShapePoint];
  version: uint;
  checksum: string;
  profile_mask: uint;
}

root_type LandTile;
```
- lat_q/lon_q = квантованные int32 (lat/lon × 1e6).
- Храним и массив ShapePoint, и encoded polyline (оба варианта).
- У каждого Edge — bitmask доступа.

## 5. Конвертер

### 5.1 CLI
```lua
converter input.osm.pbf output.routingdb
```

### 5.2 Алгоритм работы

1. Считать PBF (libosmium/OSM2) — выделить только нужные объекты:
   - автомобильные и пешеходные пути (highway=* включая motor/residential/footway/path/steps);
   - фильтрация по регионам внутри страны (bbox или poly).
2. Разбить на тайлы 4×4 км по WebMercator или WGS84.
3. Для каждого тайла:
   - собрать массив узлов Node;
   - собрать массив рёбер Edge (с геометрией);
   - рассчитать квантованные координаты;
   - рассчитать скорости: одна для Car, отдельная константа для Foot.
4. Сериализовать LandTile в FlatBuffers.
5. Посчитать SHA-256 checksum, version, profile_mask.
6. Записать строку в land_tiles.
7. Заполнить metadata (версия схемы, дата, bbox, регион).
8. Сформировать лог:
   - количество узлов, рёбер, тайлов;
   - ошибки/предупреждения.

### 5.3 Логи
- По завершении вывести статистику (узлы/рёбра/тайлы).
- По каждому тайлу — warn, если пустой или слишком большой.

### 5.4 Тестовые данные
- Прогнать на регионе «Россия, Архангельская область».
- Проверить:
  - кол-во тайлов,
  - корректность bbox,
  - выборка по z,x,y даёт FlatBuffers, который десериализуется.

### 6. Ожидаемый результат
- На выходе: один файл archangelsk.routingdb.
- Внутри: таблица land_tiles с FlatBuffers, таблица metadata.
- Конвертер CLI выдаёт лог и успешно открывается в ядре маршрутизатора.







