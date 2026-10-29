// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Orrery",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OrreryCore"),
        .testTarget(name: "OrreryCoreTests", dependencies: ["OrreryCore"]),
    ]
)
