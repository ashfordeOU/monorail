// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Monorail",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Monorail", targets: ["Monorail"]),
        .library(name: "MonorailCore", targets: ["MonorailCore"]),
        .library(name: "MonorailEngine", targets: ["MonorailEngine"]),
    ],
    targets: [
        // Pure layout model: no AppKit, builds and tests on any platform.
        .target(name: "MonorailCore"),
        // The platform-free window manager: decides where windows go and talks to the OS
        // only through the WindowSystem protocol (macOS today, Windows next; see docs/PLATFORMS.md).
        .target(name: "MonorailEngine", dependencies: ["MonorailCore"]),
        // The macOS app: Accessibility engine, input, menu bar and settings.
        .executableTarget(
            name: "Monorail",
            dependencies: ["MonorailCore", "MonorailEngine"],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("ServiceManagement", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(name: "MonorailCoreTests", dependencies: ["MonorailCore"]),
        .testTarget(name: "MonorailEngineTests", dependencies: ["MonorailEngine", "MonorailCore"]),
    ]
)
