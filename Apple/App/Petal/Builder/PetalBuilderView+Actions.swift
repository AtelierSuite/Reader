import SwiftUI
import Hanami

@MainActor
extension PetalBuilderView {

    // MARK: - Derived state

    var canSave: Bool {
        !recipe.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !recipe.siteURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !recipe.itemSelector.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Fetch & Preview

    func fetchAndPreview(force: Bool = false) async {
        if !force, fetchedHTML != nil {
            runPreviewFromCache()
            return
        }
        let requestID = UUID()
        fetchRequestID = requestID
        let requestedRecipe = recipe
        isFetching = true
        errorMessage = nil
        let result = await PetalEngine.preview(for: requestedRecipe)
        guard !Task.isCancelled, fetchRequestID == requestID,
              recipe.siteURL == requestedRecipe.siteURL,
              recipe.fetchMode == requestedRecipe.fetchMode else { return }
        isFetching = false
        fetchedHTML = result.fetchedHTMLSample
        runPreviewFromCache()
        if fetchedHTML == nil {
            previewArticles = []
            errorMessage = result.errorMessage
        }
    }

    func schedulePreview() {
        previewTask?.cancel()
        guard fetchedHTML != nil else { return }
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run { runPreviewFromCache() }
        }
    }

    func runPreviewFromCache() {
        guard let html = fetchedHTML else { return }
        previewArticles = PetalEngine.parse(html: html, recipe: recipe)
        errorMessage = previewArticles.isEmpty
            ? String(localized: "Error.NoMatches", table: "Petal") : nil
    }

    func runAutoDetect() {
        guard let html = fetchedHTML else { return }
        guard PetalAgent.isAvailable else {
            applyHeuristicSuggestion(html: html)
            return
        }
        let siteURL = recipe.siteURL
        agentStep = .readingPage
        errorMessage = nil
        agentTask = Task {
            let suggestion = try? await PetalAgent.buildRecipe(html: html, siteURL: siteURL) { step in
                Task { @MainActor in
                    if agentStep != nil { agentStep = step }
                }
            }
            guard !Task.isCancelled, recipe.siteURL == siteURL else { return }
            agentStep = nil
            if let suggestion {
                apply(suggestion)
            } else {
                applyHeuristicSuggestion(html: html)
            }
        }
    }

    private func applyHeuristicSuggestion(html: String) {
        guard let suggestion = PetalAutoDetect.detect(
            html: html, siteURL: recipe.siteURL
        ) else {
            errorMessage = String(localized: "Builder.AutoDetect.Failed", table: "Petal")
            return
        }
        apply(suggestion)
    }

    private func apply(_ suggestion: PetalRecipe) {
        if recipe.name.isEmpty {
            recipe.name = suggestion.name
        }
        recipe.itemSelector = suggestion.itemSelector
        recipe.titleSelector = suggestion.titleSelector
        recipe.linkSelector = suggestion.linkSelector
        recipe.summarySelector = suggestion.summarySelector
        recipe.imageSelector = suggestion.imageSelector
        recipe.dateSelector = suggestion.dateSelector
        recipe.dateAttribute = suggestion.dateAttribute
        recipe.authorSelector = suggestion.authorSelector
        errorMessage = nil
        runPreviewFromCache()
    }

    // MARK: - Save / Delete

    func save() {
        do {
            switch mode {
            case .create:
                _ = try feedManager.addPetalFeed(recipe: recipe)
            case .edit(let feed, _):
                try feedManager.updatePetalRecipe(feed: feed, recipe: recipe)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePetal() {
        guard case .edit(let feed, _) = mode else { return }
        do {
            let recipeID = PetalStore.shared.recipe(forFeedURL: feed.url)?.id
            try feedManager.deleteFeed(feed)
            if let recipeID {
                try PetalStore.shared.deleteRecipe(id: recipeID)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
