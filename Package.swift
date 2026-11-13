// swift-tools-version: 5.9
import PackageDescription
import Foundation
let coreLibrary = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("rust/target/release").path
let package = Package(
    name: "OpenNotebook",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenNotebook", targets: ["OpenNotebook"])],
    targets: [
        .systemLibrary(name: "COneStore", path: "Sources/COneStore"),
        .executableTarget(name: "OpenNotebook", dependencies: ["COneStore"],
            linkerSettings: [
                .unsafeFlags(["-L", coreLibrary]),
                .linkedLibrary("onestore"),
                .linkedFramework("Security"), .linkedFramework("SystemConfiguration")
            ]),
        .testTarget(name: "OpenNotebookTests", dependencies: ["OpenNotebook"])
    ])
