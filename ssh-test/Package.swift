// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SSHTest",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "SSHTest",
            dependencies: ["Citadel"]
        )
    ]
)
