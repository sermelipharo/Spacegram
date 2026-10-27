// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UIPlayground",
    platforms: [.macOS(.v14)],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "UIPlayground",
            dependencies: [
            ],
            path: "Sources/UIPlayground"),
    ]
)
