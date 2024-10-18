// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BezierKit",
    platforms: [
        .macOS(.v10_12), .iOS(.v13),
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
            exclude: [
                "Info.plist"
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
