import Hanami

extension FeedSection {
    var browserSymbolName: String {
        switch self {
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram: "photo.on.rectangle"
        case .bluesky, .fediverse, .note, .reddit, .x: "person.2"
        case .substack: "envelope"
        case .vimeo, .youtube, .niconico, .netflix: "play.rectangle"
        case .dmm, .dlsite: "bag"
        case .pixiv: "paintpalette"
        case .telegram: "paperplane"
        case .tumblr: "person.2"
        case .github, .qiita, .zenn: "chevron.left.forwardslash.chevron.right"
        case .hackerNews: "text.bubble"
        case .appStore, .playStore: "app.badge"
        }
    }
}
