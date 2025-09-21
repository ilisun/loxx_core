cmake_minimum_required(VERSION 3.20)

project(routing_core LANGUAGES CXX)

add_library(routing_core STATIC
  src/router.cpp
  src/tile_store.cpp
)

# FlatBuffers headers (system-installed)
find_path(FLATBUFFERS_INCLUDE_DIR flatbuffers/flatbuffers.h
          HINTS /opt/homebrew/include /usr/local/include /usr/include)

target_include_directories(routing_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_BINARY_DIR}/core/generated
    ${FLATBUFFERS_INCLUDE_DIR}
)

find_package(SQLite3 REQUIRED)
target_link_libraries(routing_core PUBLIC SQLite::SQLite3)

set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
target_include_directories(routing_core
  PRIVATE
    ${CMAKE_BINARY_DIR}/core/generated
    ${FLATBUFFERS_INCLUDE_DIR}
)

find_program(FLATC_EXECUTABLE NAMES flatc)
set(FBS_SCHEMA ${CMAKE_SOURCE_DIR}/converter/src/land_tile.fbs)
if(FLATC_EXECUTABLE)
  add_custom_command(
    OUTPUT ${GENERATED_DIR}/land_tile_generated.h
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums -o ${GENERATED_DIR} ${FBS_SCHEMA}
    DEPENDS ${FBS_SCHEMA}
    COMMENT "Generating FlatBuffers C++ code for core"
  )
  add_custom_target(core_generate_fbs ALL DEPENDS ${GENERATED_DIR}/land_tile_generated.h)
  add_dependencies(routing_core core_generate_fbs)
endif()

add_executable(route_demo examples/route_demo.cpp)
target_link_libraries(route_demo PRIVATE routing_core)
target_include_directories(route_demo PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
