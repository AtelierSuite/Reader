import SwiftUI

/// The address capsule hands its content over to the edit controls while
/// editing, so the bar keeps its shape and only what is inside it changes.
struct TakeoverCapsuleContent: View {

    @Environment(FollowingEditModel.self) private var model

    var body: some View {
        ZStack {
            switch model.mode {
            case .browsing:
                browsingContent
                    .transition(.blurReplace)
            case .editing:
                editingContent
                    .transition(.blurReplace)
            case .selecting:
                selectingContent
                    .transition(.blurReplace)
            }
        }
    }

    private var browsingContent: some View {
        HStack(spacing: 0) {
            FollowingLocationLabel()
            Button {
                model.beginEditing()
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 36, height: BarMetrics.itemHeight)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(model.feeds.isEmpty)
            .accessibilityLabel("Edit")
            AddFeedMenu()
        }
        .padding(.leading, BarMetrics.contentInset)
        .padding(.trailing, 6)
    }

    private var editingContent: some View {
        HStack {
            Button("Select") { model.toggleSelectMode() }
            Spacer()
            Button("Done") { model.endEditing() }
                .fontWeight(.semibold)
        }
        .buttonStyle(.plain)
        .frame(minHeight: BarMetrics.itemHeight)
        .padding(.horizontal, BarMetrics.contentInset + 3)
    }

    private var selectingContent: some View {
        HStack(spacing: 0) {
            Button("Cancel") { model.toggleSelectMode() }
            Spacer()
            Button {
                model.isPresentingBulkEdit = true
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 40, height: BarMetrics.itemHeight)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Edit Selected")
            Button {
                model.isPresentingBulkDelete = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(model.selectedIDs.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.red))
                    .frame(width: 40, height: BarMetrics.itemHeight)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Delete Selected")
        }
        .buttonStyle(.plain)
        .disabled(model.selectedIDs.isEmpty)
        .overlay {
            Text(model.selectedIDs.isEmpty ? "Select Feeds" : "\(model.selectedIDs.count) Selected")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .allowsHitTesting(false)
        }
        .padding(.leading, BarMetrics.contentInset + 3)
        .padding(.trailing, 8)
    }
}
