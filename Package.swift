// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "combr",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [],
    targets: [
        .target(
            name: "combr",
            dependencies: []
        ),
        .testTarget(
            name: "combrTests",
            dependencies: ["combr"]
        ),
    ]
)