import Foundation
import Hanami

/// How a piece of content opens and whether opening it marks it read, worked
/// out as iOS does: a mode the link asked for, then excluded sites, then the
/// bookmark folder's or feed's own choice, then Open Content In.
struct ContentOpening {

    let mode: FeedOpenMode
    let marksRead: Bool

    init(
        article: Article,
        feedManager: FeedManager,
        context: BrowserLocation?,
        requestedMode: OpenArticleRequest.Mode? = nil
    ) {
        let folderOptions = Self.folderOptions(for: article, feedManager: feedManager, context: context)
        if let requestedMode {
            mode = requestedMode.feedOpenMode
        } else if article.isPodcastEpisode {
            mode = folderOptions?.openMode ?? Self.feedOpenMode(for: article) ?? .inAppViewer
        } else {
            mode = ContentOpenMode.resolvedMode(
                for: article.url,
                preferredMode: folderOptions?.openMode ?? Self.feedOpenMode(for: article)
            )
        }
        marksRead = !article.isEphemeral && (folderOptions?.marksReadOnOpen ?? true)
    }

    /// Opened in the default browser rather than in a page of the app.
    var opensInBrowser: Bool {
        mode == .browser
    }

    private static func feedOpenMode(for article: Article) -> FeedOpenMode? {
        guard !article.isEphemeral,
              let raw = UserDefaults.standard.string(forKey: "openMode-\(article.feedID)") else {
            return nil
        }
        return FeedOpenMode(rawValue: raw)
    }

    /// Folder choices only apply to content opened from Bookmarks.
    private static func folderOptions(
        for article: Article,
        feedManager: FeedManager,
        context: BrowserLocation?
    ) -> BookmarkFolder? {
        switch context {
        case .bookmarks, .bookmarkFolder, .bookmarkTag:
            guard let folderID = feedManager.bookmarkFolderID(forArticleID: article.id) else { return nil }
            return feedManager.bookmarkFolders.first { $0.id == folderID }
        default:
            return nil
        }
    }
}

extension OpenArticleRequest.Mode {

    var feedOpenMode: FeedOpenMode {
        switch self {
        case .viewer: .inAppViewer
        case .clearThisPage: .clearThisPage
        case .readability: .readability
        case .archiveToday: .archivePh
        }
    }
}
