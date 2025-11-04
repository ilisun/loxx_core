// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoxxRouter",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "LoxxRouter",
            targets: ["LoxxRouter"]
        ),
    ],
    targets: [
        // Public Swift API
        .target(
            name: "LoxxRouter",
            dependencies: ["LoxxRouterCore"],
            path: "Sources/LoxxRouter",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Internal C++ + Objective-C++ bridge
        .target(
            name: "LoxxRouterCore",
            path: "Sources/LoxxRouterCore",
            exclude: ["README.md"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../../core/include"),
                .headerSearchPath("../../../core/src"),
                .define("LOXX_IOS_BUILD"),
            ]
        ),
        
        // Tests
        .testTarget(
            name: "LoxxRouterTests",
            dependencies: ["LoxxRouter"],
            path: "Tests/LoxxRouterTests",
            resources: [.copy("Resources")]
        ),
    ],
    cxxLanguageStandard: .cxx20
)

