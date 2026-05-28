// swift-tools-version: 5.9
// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

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
