import SwiftUI

/// Side-by-side display mode choices, after Safari's tab layout setting.
struct DisplayModePicker: View {

    let selection: AppDisplayMode
    let onSelect: (AppDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppDisplayMode.allCases) { mode in
                option(mode)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private func option(_ mode: AppDisplayMode) -> some View {
        let isSelected = mode == selection
        return Button {
            if !isSelected {
                onSelect(mode)
            }
        } label: {
            VStack(spacing: 10) {
                DisplayModeGlyph(mode: mode)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.gray))
                Text(mode.localizedTitle)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.gray))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.localizedTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
