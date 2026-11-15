// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIClient",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AIClient", targets: ["AIClient"]),
    ],
    targets: [
        .target(name: "AIClient"),
    ]
)
