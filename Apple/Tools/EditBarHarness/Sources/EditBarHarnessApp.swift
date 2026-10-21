import SwiftUI

@main
struct EditBarHarnessApp: App {

    @State private var model = FollowingEditModel()

    var body: some Scene {
        WindowGroup {
            FollowingHarnessPage()
                .environment(model)
        }
    }
}

struct FollowingHarnessPage: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VariantControls()
                    FeedGrid()
                }
                .padding()
            }
            .navigationTitle("Feeds")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HarnessBottomBar()
            }
            .sheet(item: $model.feedBeingEdited) { feed in
                PlaceholderSheet(title: feed.name, message: "Edit Feed sheet")
            }
            .sheet(isPresented: $model.isPresentingBulkEdit) {
                PlaceholderSheet(title: "Edit \(model.selectedIDs.count) Feeds", message: "Bulk edit sheet")
            }
            .alert("Unfollow \(model.selectedIDs.count) Feeds?", isPresented: $model.isPresentingBulkDelete) {
                Button("Unfollow", role: .destructive) { model.deleteSelected() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

private struct VariantControls: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Text("Feeds")
                .font(.largeTitle.bold())
            Picker("Variant", selection: $model.variant.animation(FollowingEditModel.barAnimation)) {
                ForEach(BarVariant.allCases) { variant in
                    Text(variant.rawValue).tag(variant)
                }
            }
            .pickerStyle(.segmented)
            Toggle(
                "Hide Back and Tabs while editing",
                isOn: $model.collapsesNavigationWhileEditing.animation(FollowingEditModel.barAnimation)
            )
                .font(.subheadline)
            Button("Reset Feeds") {
                withAnimation(.smooth) {
                    model.feeds = HarnessFeed.samples
                    model.endEditing()
                }
            }
            .font(.subheadline)
        }
    }
}

private struct PlaceholderSheet: View {

    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "pencil", description: Text(message))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium])
    }
}
