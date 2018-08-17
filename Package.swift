// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SwiftMQTT",
    products: [
        .library(name: "SwiftMQTT", targets: ["SwiftMQTT"]),
        ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftMQTT",
            dependencies: [],
            path: "SwiftMQTT/SwiftMQTT/"
        ),
        .testTarget(
            name: "SwiftMQTTTests", 
            dependencies: ["SwiftMQTT"],
            path: "SwiftMQTT/SwiftMQTTTests/"
        ),
    ]
)

