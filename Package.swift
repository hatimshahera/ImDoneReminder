// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ImDoneReminder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ImDoneReminder", targets: ["ImDoneReminder"])
    ],
    targets: [
        .executableTarget(
            name: "ImDoneReminder",
            path: "Sources/ImDoneReminder"
        )
    ]
)
