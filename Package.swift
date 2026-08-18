// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bed",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Bed", targets: ["Bed"])
    ],
    targets: [
        .executableTarget(
            name: "Bed",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("MediaToolbox"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreMedia")
            ]
        )
    ]
)
