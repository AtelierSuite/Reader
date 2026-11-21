import Foundation

nonisolated extension PixivProvider {

    static func fetchUser(_ userID: String) async throws -> PixivUser {
        try await fetchBody(
            PixivUser.self,
            percentEncodedPath: "/ajax/user/\(userID)",
            queryItems: [URLQueryItem(name: "full", value: "1")]
        )
    }

    static func fetchProfileAll(_ userID: String) async throws -> PixivProfileAll {
        try await fetchBody(PixivProfileAll.self, percentEncodedPath: "/ajax/user/\(userID)/profile/all")
    }

    static func fetchUserArtworks(_ userID: String, profile: PixivProfileAll) async throws -> [PixivArtwork] {
        let ids = Array(profile.newestIllustMangaIDs.prefix(worksPerRefresh))
        guard !ids.isEmpty else { return [] }
        let queryItems = ids.map { URLQueryItem(name: "ids[]", value: $0) } + [
            URLQueryItem(name: "work_category", value: "illustManga"),
            URLQueryItem(name: "is_first_page", value: "1")
        ]
        let response = try await fetchBody(
            PixivProfileWorks<PixivIllustThumbnail>.self,
            percentEncodedPath: "/ajax/user/\(userID)/profile/illusts",
            queryItems: queryItems
        )
        return ids.compactMap { response.works.values[$0].flatMap(PixivArtwork.init(thumbnail:)) }
    }

    static func fetchUserNovels(_ userID: String, profile: PixivProfileAll) async throws -> [PixivNovel] {
        let ids = Array(profile.newestNovelIDs.prefix(novelsPerRefresh))
        guard !ids.isEmpty else { return [] }
        let response = try await fetchBody(
            PixivProfileWorks<PixivNovelThumbnail>.self,
            percentEncodedPath: "/ajax/user/\(userID)/profile/novels",
            queryItems: ids.map { URLQueryItem(name: "ids[]", value: $0) }
        )
        return ids.compactMap { response.works.values[$0].flatMap(PixivNovel.init(thumbnail:)) }
    }

    static func fetchFollowingArtworks() async throws -> [PixivArtwork] {
        guard hasSession() else { throw PixivFetchError.signInRequired }
        let response = try await fetchBody(
            PixivFollowLatest.self,
            percentEncodedPath: "/ajax/follow_latest/illust",
            queryItems: [URLQueryItem(name: "p", value: "1"), URLQueryItem(name: "mode", value: "all")]
        )
        return (response.thumbnails?.illust ?? []).compactMap(PixivArtwork.init(thumbnail:))
    }

    static func fetchTagArtworks(_ tag: String) async throws -> [PixivArtwork] {
        let response = try await fetchBody(
            PixivTagSearch.self,
            percentEncodedPath: "/ajax/search/artworks/\(PixivFeedTarget.encodedPathSegment(tag))",
            queryItems: [
                URLQueryItem(name: "word", value: tag),
                URLQueryItem(name: "order", value: "date_d"),
                URLQueryItem(name: "mode", value: includesRestrictedWorks ? "all" : "safe"),
                URLQueryItem(name: "s_mode", value: "s_tag"),
                URLQueryItem(name: "p", value: "1")
            ]
        )
        return (response.illustManga?.data ?? []).compactMap(PixivArtwork.init(thumbnail:))
    }

    static func fetchRankingArtworks(_ mode: String) async throws -> [PixivArtwork] {
        let data = try await fetchData(
            percentEncodedPath: "/ranking.php",
            queryItems: [
                URLQueryItem(name: "mode", value: mode),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "p", value: "1")
            ]
        )
        let ranking = try JSONDecoder().decode(PixivRanking.self, from: data)
        return (ranking.contents ?? []).compactMap(PixivArtwork.init(rankingEntry:))
    }

    static func fetchIllustDetail(_ illustID: String) async throws -> PixivIllustDetail {
        try await fetchBody(PixivIllustDetail.self, percentEncodedPath: "/ajax/illust/\(illustID)")
    }

    static func fetchNovelDetail(_ novelID: String) async throws -> PixivNovelDetail {
        try await fetchBody(PixivNovelDetail.self, percentEncodedPath: "/ajax/novel/\(novelID)")
    }

    static func fetchInsertedIllustURLs(novelID: String, references: [String]) async -> [String: String] {
        guard !references.isEmpty,
              let response = try? await fetchBody(
                PixivKeyedCollection<PixivInsertedIllust>.self,
                percentEncodedPath: "/ajax/novel/\(novelID)/insert_illusts",
                queryItems: references.map { URLQueryItem(name: "id[]", value: $0) }
              ) else { return [:] }
        return response.values.compactMapValues(\.imageURL)
    }
}
