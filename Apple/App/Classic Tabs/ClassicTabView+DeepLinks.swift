import SwiftUI
import Hanami

extension ClassicTabView {

    /// Cold launch sets the request before the feeds are loaded, so the row is
    /// looked up once they are in.
    func handlePendingArticleIfNeeded() {
        guard let articleID = pendingArticleID else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard pendingArticleID == articleID else { return }
            openPendingArticle(articleID)
            pendingArticleID = nil
        }
    }

    private func openPendingArticle(_ articleID: Int64) {
        guard let article = feedManager.article(byID: articleID) else { return }
        if article.isYouTubeURL, youTubeOpenMode == .youTubeApp {
            feedManager.markRead(article)
            YouTubeHelper.openInApp(url: article.url)
            return
        }
        pushOntoNavigableTab(article)
    }

    func handlePendingOpenRequestIfNeeded() {
        guard let request = pendingOpenRequest else { return }
        pendingOpenRequest = nil
        let article = Article.ephemeral(url: request.url, title: request.url)
        if article.isYouTubeURL, youTubeOpenMode == .youTubeApp {
            YouTubeHelper.openInApp(url: article.url)
            return
        }
        pushOntoNavigableTab(EphemeralArticleDestination(
            article: article, mode: request.mode, textMode: request.textMode
        ))
    }

    /// Profile runs its own settings stack, so content opened from outside
    /// lands on Following instead.
    private func pushOntoNavigableTab<Value: Hashable>(_ value: Value) {
        if selectedTab == .profile {
            selectedTab = .following
        }
        var path = paths[selectedTab] ?? NavigationPath()
        path.append(value)
        paths[selectedTab] = path
    }
}
