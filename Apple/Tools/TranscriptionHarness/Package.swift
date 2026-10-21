// swift-tools-version: 6.2

import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility")
]

let package = Package(
    name: "TranscriptionHarness",
    platforms: [.macOS("26.1")],
    dependencies: [
        // Same pin as SakuraRSS.xcodeproj; see the dependency notes before bumping.
        .package(
            url: "https://github.com/FluidInference/FluidAudio",
            revision: "372eb32a3b23342d11dca41ed75cd4d11d3f8955"
        )
    ],
    targets: [
        // Symlinks the app's Transcriber files so they're tested as-is.
        // SpeechTranscriberEngine is the candidate replacement for FluidTranscriberEngine.
        .target(
            name: "HanamiTranscriber",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "TranscriptionHarness",
            dependencies: ["HanamiTranscriber"],
            swiftSettings: sharedSwiftSettings
        )
    ]
)
