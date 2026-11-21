import SwiftUI
import Hanami

struct AddFeedErrorSection: View {

    let errorMessage: String

    var body: some View {
        Section {
            Text(errorMessage)
                .foregroundStyle(.red)
        }
    }
}
