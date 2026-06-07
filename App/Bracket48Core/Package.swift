// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Bracket48Core",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Bracket48Core",
            targets: ["Bracket48Core"]
        )
    ],
    targets: [
        .target(name: "Bracket48Core"),
        .testTarget(
            name: "Bracket48CoreTests",
            dependencies: ["Bracket48Core"]
        )
    ]
)
