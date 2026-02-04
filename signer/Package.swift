// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "signer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "signer",
            targets: ["signer"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/vapor/jwt-kit.git",
            from: "4.0.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "signer",
            dependencies: [
                .product(name: "JWTKit", package: "jwt-kit")
            ]
        )
    ]
)
