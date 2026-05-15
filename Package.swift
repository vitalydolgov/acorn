// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Acorn",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AcornDomain", targets: ["AcornDomain"]),
        .library(name: "AcornApplication", targets: ["AcornApplication"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
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
        .testTarget(
            name: "AcornDomainTests",
            dependencies: ["AcornDomain"]
        ),
        .testTarget(
            name: "AcornApplicationTests",
            dependencies: ["AcornApplication"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
