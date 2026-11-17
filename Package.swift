// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ImageConverterUltra",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ImageConverterUltra", path: "Sources/ImageConverterUltra")
    ]
)
