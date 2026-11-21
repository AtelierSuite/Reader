import SwiftUI
import WebKit
import Hanami

/// Web view presenting the pixiv login page; cookies persist for PixivProvider.
struct PixivLoginView: View {

    @Environment(\.dismiss) var dismiss
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            PixivLoginWebView(isLoggedIn: $isLoggedIn)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(String(localized: "PixivLogin.Title", table: "Integrations"))
                .inlineNavigationTitle()
                .compatibleSoftScrollEdgeEffectStyle()
                .toolbar {
                    ToolbarItem(placement: .sheetClose) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
                .onChange(of: isLoggedIn) { _, loggedIn in
                    if loggedIn {
                        dismiss()
                    }
                }
        }
    }
}

private struct PixivLoginWebView: WebViewRepresentable {

    @Binding var isLoggedIn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoggedIn: $isLoggedIn)
    }

    func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = sakuraUserAgent

        if let loginURL = PixivProvider.loginURL {
            webView.load(URLRequest(url: loginURL))
        }
        return webView
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoggedIn: Bool
        private var checkTask: Task<Void, Never>?

        init(isLoggedIn: Binding<Bool>) {
            _isLoggedIn = isLoggedIn
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isLoggedIn else { return }
            checkTask?.cancel()
            checkTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }

                await PixivProvider.syncCookiesFromWebKit()

                if PixivProvider.hasSession() {
                    self.isLoggedIn = true
                }
            }
        }
    }
}
