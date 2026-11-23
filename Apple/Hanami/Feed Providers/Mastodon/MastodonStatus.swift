import Foundation

nonisolated struct MastodonContext: Decodable, Sendable {
    let ancestors: [MastodonStatus]
    let descendants: [MastodonStatus]
}

nonisolated struct MastodonStatus: Decodable, Sendable {
    let id: String
    let uri: String?
    let url: String?
    let content: String
    let spoilerText: String?
    let createdAt: String?
    let inReplyToID: String?
    let account: MastodonAccount
    let mediaAttachments: [MastodonMediaAttachment]?
    let card: MastodonPreviewCard?
    let reblog: MastodonRebloggedStatus?

    enum CodingKeys: String, CodingKey {
        case id, uri, url, content, account, card, reblog
        case spoilerText = "spoiler_text"
        case createdAt = "created_at"
        case inReplyToID = "in_reply_to_id"
        case mediaAttachments = "media_attachments"
    }

    var createdDate: Date? {
        MastodonDate.parse(createdAt)
    }

    var displayAuthor: String {
        account.displayName.isEmpty ? "@\(account.acct)" : account.displayName
    }
}

nonisolated struct MastodonRebloggedStatus: Decodable, Sendable {
    let id: String
    let uri: String?
    let url: String?
    let content: String
    let spoilerText: String?
    let createdAt: String?
    let account: MastodonAccount
    let mediaAttachments: [MastodonMediaAttachment]?
    let card: MastodonPreviewCard?

    enum CodingKeys: String, CodingKey {
        case id, uri, url, content, account, card
        case spoilerText = "spoiler_text"
        case createdAt = "created_at"
        case mediaAttachments = "media_attachments"
    }

    var displayAuthor: String {
        account.displayName.isEmpty ? "@\(account.acct)" : account.displayName
    }
}

nonisolated struct MastodonMediaAttachment: Decodable, Sendable {
    let type: String
    let url: String?
    let previewURL: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case type, url, description
        case previewURL = "preview_url"
    }
}

nonisolated struct MastodonPreviewCard: Decodable, Sendable {
    let url: String?
    let title: String?
    let image: String?
}

nonisolated struct MastodonAccount: Decodable, Sendable {
    let username: String
    let acct: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case username, acct
        case displayName = "display_name"
    }
}

nonisolated enum MastodonDate {
    private static let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plainStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = try? fractionalStyle.parse(value) { return date }
        return try? plainStyle.parse(value)
    }
}
