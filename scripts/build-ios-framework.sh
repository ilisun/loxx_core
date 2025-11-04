#!/bin/bash
set -e

# loxx-core iOS XCFramework Builder
# Собирает C++ ядро в XCFramework для iOS

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_ROOT/build-xcframework"
OUTPUT_DIR="$PROJECT_ROOT/releases"

echo "🔨 Building loxx-core XCFramework..."

# Очистка
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================
# 1. Создать Xcode проект для C++ фреймворка
# ============================================
echo "📦 Creating Xcode project..."

cat > "$BUILD_DIR/CMakeLists.txt" << 'EOF'
cmake_minimum_required(VERSION 3.20)
project(loxx-core VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Framework настройки
set(CMAKE_FRAMEWORK TRUE)
set(CMAKE_MACOSX_RPATH TRUE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

# ============================================
# FlatBuffers - генерация заголовков
# ============================================
find_program(FLATC_EXECUTABLE NAMES flatc)
if(NOT FLATC_EXECUTABLE)
    message(FATAL_ERROR "flatc not found! Install FlatBuffers: brew install flatbuffers")
endif()

set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
set(FBS_SCHEMA ${CMAKE_CURRENT_SOURCE_DIR}/../converter/src/land_tile.fbs)

file(MAKE_DIRECTORY ${GENERATED_DIR})

add_custom_command(
    OUTPUT ${GENERATED_DIR}/land_tile_generated.h
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums -o ${GENERATED_DIR} ${FBS_SCHEMA}
    DEPENDS ${FBS_SCHEMA}
    COMMENT "Generating FlatBuffers headers for iOS XCFramework"
)

add_custom_target(generate_fbs ALL DEPENDS ${GENERATED_DIR}/land_tile_generated.h)

# ============================================
# loxx-core Framework
# ============================================
# Добавить исходники C++ ядра
file(GLOB_RECURSE SOURCES 
    "${CMAKE_CURRENT_SOURCE_DIR}/../core/src/*.cpp"
)

# Создать framework
add_library(loxx-core SHARED ${SOURCES})

# FlatBuffers include directories
find_path(FLATBUFFERS_INCLUDE_DIR flatbuffers/flatbuffers.h
          HINTS /opt/homebrew/include /usr/local/include /usr/include)

target_include_directories(loxx-core
    PUBLIC 
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../core/include>
        $<INSTALL_INTERFACE:Headers>
    PRIVATE
        ${GENERATED_DIR}
        ${FLATBUFFERS_INCLUDE_DIR}
)

# Зависимость от генерации FlatBuffers
add_dependencies(loxx-core generate_fbs)

# Framework свойства
set_target_properties(loxx-core PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER com.loxx.loxx-core
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
    PUBLIC_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/../core/include/routing_core/router.h;${CMAKE_CURRENT_SOURCE_DIR}/../core/include/routing_core/profile.h;${CMAKE_CURRENT_SOURCE_DIR}/../core/include/routing_core/tile_store.h"
)

# SQLite линковка
find_package(SQLite3 REQUIRED)
target_link_libraries(loxx-core PRIVATE SQLite::SQLite3)

install(TARGETS loxx-core
    FRAMEWORK DESTINATION .
)
EOF

# ============================================
# 2. Сборка для iOS Device (arm64)
# ============================================
echo "📱 Building for iOS Device (arm64)..."

cmake -S "$BUILD_DIR" -B "$BUILD_DIR/ios-arm64" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install/ios-arm64" \
    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO

cmake --build "$BUILD_DIR/ios-arm64" --config Release
cmake --install "$BUILD_DIR/ios-arm64" --config Release

# ============================================
# 3. Сборка для iOS Simulator (arm64 + x86_64)
# ============================================
echo "🖥️  Building for iOS Simulator (arm64 + x86_64)..."

cmake -S "$BUILD_DIR" -B "$BUILD_DIR/ios-simulator" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install/ios-simulator" \
    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO

cmake --build "$BUILD_DIR/ios-simulator" --config Release
cmake --install "$BUILD_DIR/ios-simulator" --config Release

# ============================================
# 4. Создать XCFramework
# ============================================
echo "📦 Creating XCFramework..."

xcodebuild -create-xcframework \
    -framework "$BUILD_DIR/install/ios-arm64/loxx-core.framework" \
    -framework "$BUILD_DIR/install/ios-simulator/loxx-core.framework" \
    -output "$OUTPUT_DIR/loxx-core.xcframework"

# ============================================
# 5. Упаковать в ZIP
# ============================================
echo "🗜️  Creating ZIP archive..."

cd "$OUTPUT_DIR"
zip -r loxx-core.xcframework.zip loxx-core.xcframework

# ============================================
# 6. Вычислить checksum
# ============================================
echo "🔐 Computing checksum..."

CHECKSUM=$(swift package compute-checksum loxx-core.xcframework.zip)

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 Output:"
echo "   Framework: $OUTPUT_DIR/loxx-core.xcframework"
echo "   Archive:   $OUTPUT_DIR/loxx-core.xcframework.zip"
echo ""
echo "🔐 Checksum for Package.swift:"
echo "   $CHECKSUM"
echo ""
echo "📝 Next steps:"
echo "   1. Upload loxx-core.xcframework.zip to GitHub Release"
echo "   2. Use checksum in loxx-router-ios Package.swift"

