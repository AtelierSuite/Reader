import Foundation

nonisolated struct InstagramPostsQuery: Codable, Equatable, Sendable {
    let docID: String
    let relayProviders: [String]

    static let fallback = InstagramPostsQuery(
        docID: "28834890909485062",
        relayProviders: [
            "PolarisMultiCaptionCarouselEnabled",
            "PolarisShortDramaEnabled",
            "PolarisThreadsStyleCommentsEnabled",
            "PolarisReelsRecoDebugOverlayEnabled"
        ]
    )

    static let enabledRelayProviders: Set<String> = ["PolarisMultiCaptionCarouselEnabled"]

    var relayProviderVariables: [String: Bool] {
        Dictionary(uniqueKeysWithValues: relayProviders.map {
            ("__relay_internal__pv__\($0)relayprovider", Self.enabledRelayProviders.contains($0))
        })
    }
}
