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
    dependencies: [
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", from: "0.1.0"),
        .package(url: "https://github.com/material-components/material-components-ios.git", from: "125.0.0")
    ],
    targets: [
        .target(
            name: "LoopaCore",
            dependencies: [
                .product(name: "SwiftUIX", package: "SwiftUIX"),
                .product(name: "MaterialComponents", package: "material-components-ios")
            ],
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