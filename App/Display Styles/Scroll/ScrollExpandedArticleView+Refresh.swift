import SwiftUI
import Hanami

extension ScrollExpandedArticleView {

    func refreshArticleContent() async {
        let articleID = article.id
        let previousText = extractedText
        await Task.detached(priority: .utility) {
            try? DatabaseManager.shared.clearCachedArticleContent(for: articleID)
        }.value

        extractedText = nil
        await extractArticleContent()

        if extractedText == nil, let previousText {
            extractedText = previousText
            await Task.detached(priority: .utility) {
                try? DatabaseManager.shared.cacheArticleContent(previousText, for: articleID)
            }.value
        }
    }
}
