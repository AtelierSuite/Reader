import PhotosUI
import SwiftUI
import Hanami

@MainActor
extension EditFeedMetadataTab {

    @ViewBuilder
    func iconSection(for feed: Feed) -> some View {
        Section {
            iconPreview(for: feed)
            #if os(macOS)
            macIconURLField
            macIconActionsRow(for: feed)
            #else
            iconURLField
            photosPickerRow
            fetchIconButton
            deleteIconButton(for: feed)
            #endif
        } header: {
            Text(String(localized: "FeedEdit.Icon", table: "Feeds"))
        }
    }

    @ViewBuilder
    private func iconPreview(for feed: Feed) -> some View {
        if useDefaultIcon {
            HStack {
                Spacer()
                if let data = feed.acronymIcon, let acronym = PlatformImage(data: data) {
                    IconImage(acronym, size: 64,
                                 cornerRadius: iconCornerRadius(size: 64),
                                 circle: feed.isCircleIcon,
                                 skipInset: true)
                } else {
                    InitialsAvatarView(
                        name.isEmpty ? feed.title : name,
                        size: 64,
                        circle: feed.isCircleIcon,
                        cornerRadius: iconCornerRadius(size: 64)
                    )
                }
                Spacer()
            }
        } else if let icon = customIconImage ?? currentIcon {
            HStack {
                Spacer()
                IconImage(
                    icon, size: 64,
                    cornerRadius: iconCornerRadius(size: 64),
                    circle: feed.isCircleIcon,
                    skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                )
                Spacer()
            }
        }
    }

    #if os(macOS)
    private var macIconURLField: some View {
        HStack {
            TextField(
                String(localized: "FeedEdit.IconURL", table: "Feeds"),
                text: $iconURLInput,
                prompt: Text(verbatim: "https://example.com/icon.png")
            )
            .urlTextInput()
            .onSubmit {
                Task {
                    if await fetchIconFromURL() {
                        commitNameAndIcon()
                    }
                }
            }
            if isFetchingIcon {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func macIconActionsRow(for feed: Feed) -> some View {
        HStack {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text(String(localized: "FeedEdit.ChooseFromPhotos", table: "Feeds"))
            }
            Button {
                Task {
                    await fetchIconFromFeed()
                    commitNameAndIcon()
                }
            } label: {
                Text(String(localized: "FeedEdit.FetchIconFromFeed", table: "Feeds"))
            }
            .disabled(isFetchingIcon)
            Spacer()
            deleteIconButton(for: feed)
        }
    }
    #endif

    private var iconURLField: some View {
        HStack {
            Text(String(localized: "FeedEdit.IconURL", table: "Feeds"))
            TextField(String("https://example.com/icon.png"), text: $iconURLInput)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
                .urlTextInput()
                .labelsHidden()
                .onSubmit {
                    Task {
                        if await fetchIconFromURL() {
                            commitNameAndIcon()
                        }
                    }
                }
            if isFetchingIcon {
                ProgressView()
            }
        }
    }

    private var photosPickerRow: some View {
        let hasCustomIcon = customIconImage != nil
        return PhotosPicker(selection: $selectedPhoto, matching: .images) {
            HStack {
                Text(String(localized: "FeedEdit.ChooseFromPhotos", table: "Feeds"))
                Spacer()
                if hasCustomIcon {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var fetchIconButton: some View {
        Button {
            Task {
                await fetchIconFromFeed()
                commitNameAndIcon()
            }
        } label: {
            HStack {
                Text(String(localized: "FeedEdit.FetchIconFromFeed", table: "Feeds"))
                Spacer()
                if isFetchingIcon {
                    ProgressView()
                }
            }
        }
        .disabled(isFetchingIcon)
    }

    @ViewBuilder
    private func deleteIconButton(for feed: Feed) -> some View {
        if !useDefaultIcon && (feed.customIconURL != nil || currentIcon != nil) {
            Button(role: .destructive) {
                useDefaultIcon = true
                customIconImage = nil
                selectedPhoto = nil
                iconURLInput = ""
                commitNameAndIcon()
            } label: {
                Text(String(localized: "FeedEdit.DeleteIcon", table: "Feeds"))
            }
        }
    }
}
