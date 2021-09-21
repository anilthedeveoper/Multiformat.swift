// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Multiformat",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Multiformat",
            targets: ["Multiformat"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/jmmaloney4/VarInt.git", .branch("master")),
        .package(name: "Multihash", url: "https://github.com/jmmaloney4/Multihash.swift.git", .branch("master")),
        .package(url: "https://github.com/jmmaloney4/Base58.swift.git", .branch("master")),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Multiformat",
            dependencies: ["VarInt", "Multihash", "BigInt"]
        ),
        .testTarget(
            name: "MultiformatTests",
            dependencies: ["Multiformat"]
        ),
    ]
)
