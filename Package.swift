// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Orrery",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Orrery", targets: ["OrreryApp"]),
    ],
    targets: [
        .target(name: "OrreryCore"),
        .executableTarget(name: "OrreryApp", dependencies: ["OrreryCore"]),
        .testTarget(name: "OrreryCoreTests", dependencies: ["OrreryCore"]),
    ]
)
