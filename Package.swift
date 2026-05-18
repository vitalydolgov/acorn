// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Acorn",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AcornDomain", targets: ["AcornDomain"]),
        .library(name: "AcornApplication", targets: ["AcornApplication"]),
        .library(name: "AcornAgent", targets: ["AcornAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/mattt/JSONSchema.git", from: "1.3.1"),
    ],
    targets: [
        .target(name: "AcornDomain"),
        .macro(
            name: "AcornMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "AcornApplication",
            dependencies: ["AcornDomain", "AcornMacros"]
        ),
        .target(
            name: "AcornAgent",
            dependencies: [
                "AcornApplication",
                .product(name: "JSONSchema", package: "JSONSchema"),
            ]
        ),
        .target(
            name: "AcornInMemory",
            dependencies: ["AcornDomain", "AcornApplication"]
        ),
        .testTarget(
            name: "AcornDomainTests",
            dependencies: ["AcornDomain"]
        ),
        .testTarget(
            name: "AcornApplicationTests",
            dependencies: ["AcornApplication", "AcornInMemory"]
        ),
        .testTarget(
            name: "AcornAgentTests",
            dependencies: ["AcornAgent", "AcornInMemory"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
