import SwiftUI

/// One service's sign-in: its state, a button to sign in or out, and the
/// sign-in web page in a sheet.
struct AccountSessionRow<LoginView: View>: View {

    let signInTitle: String
    let signOutTitle: String
    let checkSession: () async -> Bool
    let cachedAccount: () -> String?
    let fetchAccount: () async -> String?
    let signOut: () async -> Void
    var onSessionChange: ((Bool) -> Void)?
    @ViewBuilder let loginView: () -> LoginView

    @State private var isSignedIn: Bool?
    @State private var signedInAccount: String?
    @State private var isShowingLogin = false

    var body: some View {
        Group {
            switch isSignedIn {
            case .none:
                ProgressView()
                    .controlSize(.small)
            case .some(true):
                VStack(alignment: .leading, spacing: 8) {
                    if let signedInAccount, !signedInAccount.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(IntegrationText.string("Integration.SignedInAccount"))
                            Text(signedInAccount)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    Button(signOutTitle + "…", role: .destructive) {
                        Task {
                            await signOut()
                            signedInAccount = nil
                            isSignedIn = await checkSession()
                        }
                    }
                }
            case .some(false):
                Button(signInTitle + "…") { isShowingLogin = true }
            }
        }
        .task { await refreshSession() }
        .onChange(of: isSignedIn) { _, signedIn in
            onSessionChange?(signedIn == true)
        }
        .sheet(isPresented: $isShowingLogin) {
            Task { await refreshSession() }
        } content: {
            loginView()
                .frame(width: 520, height: 640)
        }
    }

    private func refreshSession() async {
        let signedIn = await checkSession()
        isSignedIn = signedIn
        if signedIn {
            signedInAccount = cachedAccount()
            if let fetchedAccount = await fetchAccount() {
                signedInAccount = fetchedAccount
            }
        } else {
            signedInAccount = nil
        }
    }
}
