// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gamification",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Gamification", targets: ["Gamification"]),
    ],
    targets: [
        .target(name: "Gamification"),
    ]
)
