// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IPWatch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "IPWatch",
            path: "Sources/IPWatch"
        )
    ]
)
