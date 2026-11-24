import SwiftUI

struct SignedInAccountRow: View {

    let account: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Integration.SignedInAccount", table: "Integrations"))
            Text(account)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
