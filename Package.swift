// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacArkPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacArkPet", targets: ["MacArkPet"])
    ],
    targets: [
        .executableTarget(
            name: "MacArkPet",
            path: "Sources/MacArkPet"
        )
    ]
)
