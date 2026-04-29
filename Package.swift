// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CatRest",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CatRest", targets: ["CatRest"])
    ],
    targets: [
        .executableTarget(
            name: "CatRest",
            path: "Sources/CatRest"
        )
    ]
)
