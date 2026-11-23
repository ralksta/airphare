// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AirPhare",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AirPhareCore", targets: ["AirPhareCore"]),
        .executable(name: "AirPhare", targets: ["AirPhare"])
    ],
    targets: [
        .target(
            name: "AirPhareCore",
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("Network")
            ]
        ),
        .executableTarget(
            name: "AirPhare",
            dependencies: ["AirPhareCore"],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "AirPhareCoreTests",
            dependencies: ["AirPhareCore"]
        )
    ]
)
