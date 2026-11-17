// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ChristmasTree",
    defaultLocalization: "en",
    /* macOS 26+ renders apps linked against an older SDK in the legacy
       compatibility design, so target 26 for the native appearance (and the
       Icon Composer app icon). */
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "ChristmasTree",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ChristmasTree",
            resources: [.process("Resources")],
            linkerSettings: [
                /* Sparkle.framework lives in Contents/Frameworks in the
                   bundled app (Scripts/bundle.sh) and next to the binary for
                   `swift run`. */
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path",
                ])
            ]
        )
    ]
)
