// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RetroPlayer",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "RetroPlayer", targets: ["RetroPlayer"])
    ],
    targets: [
        .target(
            name: "CMPVBridge",
            path: "Sources/CMPVBridge",
            publicHeadersPath: "include",
            cSettings: [.unsafeFlags(["-I/opt/homebrew/include"])],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/lib", "-Xlinker", "-rpath", "-Xlinker", "/opt/homebrew/lib"]),
                .linkedLibrary("mpv"),
                .linkedFramework("OpenGL")
            ]
        ),
        .executableTarget(
            name: "RetroPlayer",
            dependencies: ["CMPVBridge"],
            path: "Sources/RetroPlayer",
            exclude: ["Resources"]
        )
    ]
)
