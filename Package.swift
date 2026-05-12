// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Acorn",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AcornDomain", targets: ["AcornDomain"]),
        .library(name: "AcornApplication", targets: ["AcornApplication"]),
    ],
    targets: [
        .target(name: "AcornDomain"),
        .target(name: "AcornApplication", dependencies: ["AcornDomain"]),
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
