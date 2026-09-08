// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LofiHouse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LofiHouse", targets: ["Bed"])
    ],
    targets: [
        .executableTarget(
            name: "Bed",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("MediaPlayer"),
                .linkedFramework("CoreAudio")
            ]
        )
    ]
)
