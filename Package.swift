// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Multiformat",
    // Necessary for swift crypto
    platforms: [
        .iOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Multiformat",
            targets: ["Multiformat"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/jmmaloney4/VarInt.git", from: "1.0.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "Multiformat",
            dependencies: ["VarInt", "BigInt", .product(name: "Crypto", package: "swift-crypto")]
        ),
        .testTarget(
            name: "MultiformatTests",
            dependencies: ["Multiformat"]
        ),
    ]
)
