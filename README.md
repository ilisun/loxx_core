# LoxxCore — Offline/Online Routing Core на данных OpenStreetMap

Кроссплатформенное ядро маршрутизации (C++20) с поддержкой оффлайн‑пакетов и онлайн‑API.

- Профили: Car, Foot, Boat
- Режимы: оффлайн (iOS/Android), онлайн (серверный API)
- Данные: тайловая структура, FlatBuffers + SQLite контейнер
- Поиск: оффлайн/онлайн геокодинг (SQLite FTS5)
- Инкрементальное перестроение маршрута

## Документация

- Спецификация: `docs/main_spec.md`
- Дорожная карта: `docs/plan.md`
- Задача 1 (конвертер PBF → routingdb): `docs/it_1_task_1.md`

## Быстрый старт (конвертер)

1) Зависимости (macOS/Homebrew):

```bash
brew install cmake flatbuffers libosmium protozero expat zstd lz4 bzip2
```

2) Сборка:

```bash
cmake -S . -B build
cmake --build build -j 4
```

3) Запуск конвертера на небольшом PBF (Liechtenstein):

```bash
curl -L -o /tmp/liechtenstein.osm.pbf https://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf
./build/converter/converter --z 14 /tmp/liechtenstein.osm.pbf ./build/test.routingdb
```

Проверка результата:

```bash
sqlite3 ./build/test.routingdb "SELECT COUNT(*) FROM land_tiles;"
```

Примечания:

- На macOS `libosmium` и `protozero` ставятся как headers‑only; CMake ищет их в `/opt/homebrew/include` и `/usr/local/include`.
- При нестандартных путях можно указать их явно:

```bash
cmake -S . -B build \
  -DOSMIUM_INCLUDE_DIR=/custom/include \
  -DPROTOZERO_INCLUDE_DIR=/custom/include
```

## Структура репозитория (основное)

- `converter/` — CLI-конвертер PBF → SQLite+FlatBuffers
- `docs/` — спецификации и планы
- `CMakeLists.txt` — корневой билд

## Лицензия

Уточняется (MIT/Apache‑2.0). Данные OSM: ODbL — «© OpenStreetMap contributors».
