// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Loopa",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "LoopaCore",
            targets: ["LoopaCore"]
        )
    ],
    targets: [
        .target(
            name: "LoopaCore",
            path: "Loopa",
            exclude: ["LoopaApp.swift"]
        ),
        .testTarget(
            name: "LoopaTests",
            dependencies: ["LoopaCore"],
            path: "LoopaTests",
            resources: [
                .process("Resources")
            ]
        )
    ]
) 