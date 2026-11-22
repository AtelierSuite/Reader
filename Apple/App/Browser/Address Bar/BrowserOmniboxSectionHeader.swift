import SwiftUI

struct BrowserOmniboxSectionHeader: View {

    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }
}
