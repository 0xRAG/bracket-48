// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WorldCupBracketCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WorldCupBracketCore",
            targets: ["WorldCupBracketCore"]
        )
    ],
    targets: [
        .target(name: "WorldCupBracketCore"),
        .testTarget(
            name: "WorldCupBracketCoreTests",
            dependencies: ["WorldCupBracketCore"]
        )
    ]
)
