// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BezierKit",
    platforms: [
        .macOS(.v10_12), .iOS(.v10),
    ],
    products: [
        .library(
            name: "BezierKit",
            targets: ["BezierKit"]
        ),
    ],
    targets: [
        .target(
            name: "BezierKit",
            dependencies: [],
            path: "BezierKit/Library/"
        ),
        .testTarget(
            name: "BezierKitTests",
            dependencies: ["BezierKit"],
            path: "BezierKit/BezierKitTests",
            linkerSettings: [
              // Extend stack size on WebAssembly since the default stack size of wasm-ld (64kb)
              // is not enough for testing BezierKit.Utils.pairiteration, which heavily calls itself
              // recursively.
              .unsafeFlags(
                    ["-Xlinker", "-z", "-Xlinker", "stack-size=\(248 * 1024)"],
                    .when(platforms: [.wasi])
              ),
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
