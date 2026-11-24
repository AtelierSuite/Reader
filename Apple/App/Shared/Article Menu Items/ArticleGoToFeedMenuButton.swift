import Hanami
import SwiftUI

struct ArticleGoToFeedMenuButton: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.navigateToFeed) private var navigateToFeed
    @Environment(\.currentFeedID) private var currentFeedID
    let article: Article

    var body: some View {
        if !article.isEphemeral,
           let navigateToFeed,
           let feed = feedManager.feed(forArticle: article),
           currentFeedID != feed.id {
            Button {
                navigateToFeed(feed)
            } label: {
                Label(
                    String(localized: "Article.GoToFeed", table: "Articles"),
                    systemImage: "dot.radiowaves.up.forward"
                )
            }
        }
    }
}
