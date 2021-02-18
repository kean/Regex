// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Regex",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "Regex",
            targets: ["Regex"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Regex",
            dependencies: [],
            path: "Source/"
        ),
        .testTarget(
            name: "RegexTests",
            dependencies: ["Regex"]
        ),
    ]
)
