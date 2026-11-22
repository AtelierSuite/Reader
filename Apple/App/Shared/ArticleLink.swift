import SwiftUI
import Hanami

/// Routes article taps based on the per-feed open mode; iPad splits route to the detail column.
struct ArticleLink<Label: View>: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.iPadArticleSelection) private var iPadArticleSelection
    @Environment(\.bookmarkReadingOptions) private var bookmarkReadingOptions
    let article: Article
    var onNavigate: ((Article) -> Void)?
    /// When false, opening the article does not mark it as read.
    /// Used by the Cards style where the swipe gesture is the canonical read trigger.
    var marksRead: Bool = true
    @ViewBuilder let label: () -> Label

    @AppStorage(ContentOpenMode.storageKey) private var contentOpenMode: ContentOpenMode = .inAppViewer
    @State private var showSafari = false
    @State private var showSafariReader = false
    private let mediaPresenter = MediaPresenter.shared

    private var preferredOpenMode: FeedOpenMode? {
        if let folderMode = bookmarkReadingOptions[article.id]?.openMode {
            return folderMode
        }
        guard let feed = feedManager.feed(forArticle: article),
              let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)") else {
            return nil
        }
        return FeedOpenMode(rawValue: raw)
    }

    private var openMode: FeedOpenMode {
        _ = contentOpenMode
        return ContentOpenMode.resolvedMode(for: article.url, preferredMode: preferredOpenMode)
    }

    private var usesiPadDetailColumn: Bool {
        iPadArticleSelection != nil
    }

    private func markReadIfEnabled() {
        if let folderPreference = bookmarkReadingOptions[article.id]?.marksReadOnOpen {
            guard folderPreference else { return }
            feedManager.markRead(article)
            return
        }
        guard marksRead else { return }
        feedManager.markRead(article)
    }

    private func selectForiPadDetail() {
        markReadIfEnabled()
        iPadArticleSelection?.wrappedValue = article
    }

    var body: some View {
        let openMode = openMode
        let isYouTube = article.isYouTubeURL
        Group {
            if article.isPodcastEpisode {
                if usesiPadDetailColumn {
                    Button { selectForiPadDetail() } label: { label() }
                } else {
                    Button {
                        markReadIfEnabled()
                        mediaPresenter.presentPodcast(article)
                    } label: {
                        label()
                    }
                }
            } else if openMode == .browser {
                Button {
                    markReadIfEnabled()
                    if let url = URL(string: article.url) {
                        openURL(url)
                    }
                } label: {
                    label()
                }
            } else if isYouTube {
                if usesiPadDetailColumn {
                    Button { selectForiPadDetail() } label: { label() }
                } else {
                    Button {
                        markReadIfEnabled()
                        mediaPresenter.presentYouTube(article)
                    } label: {
                        label()
                    }
                }
            } else if openMode == .inAppBrowser {
                Button {
                    markReadIfEnabled()
                    showSafari = true
                } label: {
                    label()
                }
            } else if openMode == .inAppBrowserReader {
                Button {
                    markReadIfEnabled()
                    showSafariReader = true
                } label: {
                    label()
                }
            } else if openMode == .clearThisPage || openMode == .archivePh {
                if usesiPadDetailColumn {
                    Button { selectForiPadDetail() } label: { label() }
                } else if let onNavigate {
                    Button { onNavigate(article) } label: { label() }
                } else {
                    NavigationLink(value: article) { label() }
                }
            } else {
                if usesiPadDetailColumn {
                    Button { selectForiPadDetail() } label: { label() }
                } else if let onNavigate {
                    Button { onNavigate(article) } label: { label() }
                } else {
                    NavigationLink(value: article) { label() }
                }
            }
        }
        .modifier(MoveBookmarkToFolderRowModifier(article: article))
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSafariReader) {
            if let url = URL(string: article.url) {
                SafariView(url: url, entersReaderIfAvailable: true)
                    .ignoresSafeArea()
            }
        }
    }
}
