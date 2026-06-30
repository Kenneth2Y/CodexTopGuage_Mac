// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexTopGuage_Mac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexTopGuageMac", targets: ["CodexTopGuageMac"])
    ],
    targets: [
        .executableTarget(
            name: "CodexTopGuageMac",
            path: "Sources/CodexTopGuageMac"
        )
    ]
)
