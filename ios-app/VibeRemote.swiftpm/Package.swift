// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "VibeRemote",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "VibeRemote",
            targets: ["VibeRemote"],
            bundleIdentifier: "com.vibeRemote.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .cloud),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "VibeRemote",
            dependencies: [
                "SwiftTerm",
                .product(name: "Citadel", package: "Citadel")
            ],
            path: "Sources"
        )
    ]
)
