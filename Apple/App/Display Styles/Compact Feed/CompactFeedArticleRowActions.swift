import SwiftUI
import Hanami

/// Inline "Open" and "Mark Read" buttons rendered under the article title
/// in the Feed (Compact) style.
struct CompactFeedArticleRowActions: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.openURL) private var openURL

    let article: Article
    let opensInExternalApp: Bool

    var body: some View {
        HStack(spacing: 12) {
            openButton
                .disabled(!article.hasLink)
            markReadButton
            Spacer(minLength: 0)
        }
    }

    private var openButtonSystemName: String {
        if article.isYouTubeURL && YouTubeHelper.isAppInstalled {
            return "play.rectangle"
        }
        return opensInExternalApp ? "arrow.up.forward.app" : "arrow.up.forward.square"
    }

    @ViewBuilder
    private var openButton: some View {
        Button {
            if article.isYouTubeURL && ContentOpenMode.opensInReader(article.url) {
                feedManager.markRead(article)
                MediaPresenter.shared.presentYouTube(article)
            } else if article.isYouTubeURL {
                YouTubeHelper.openInApp(url: article.url)
            } else if let url = URL(string: article.url) {
                openURL(url)
            }
        } label: {
            Image(systemName: openButtonSystemName)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 36, minHeight: 36)
                .background(.secondary.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var markReadButton: some View {
        Button {
            Haptics.impact(.light)
            feedManager.toggleRead(article)
        } label: {
            Image(systemName: feedManager.isRead(article) ? "envelope" : "envelope.open")
                .offset(y: feedManager.isRead(article) ? 0 : -1)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 36, minHeight: 36)
                .background(.secondary.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .foregroundStyle(.primary)
    }
}
