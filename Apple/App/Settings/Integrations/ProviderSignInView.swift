import Hanami
import SwiftUI

struct ProviderSignInView: View {

    struct Configuration {
        let section: FeedSection?
        let fallbackSymbolName: String
        let serviceName: String
        let prompt: String
        let helpLinkTitle: String?
        let helpLinkURL: URL?
        let usernameLabel: String
        let usernamePlaceholder: String
        let passwordLabel: String
        let passwordPlaceholder: String
        let submitTitle: String
        let onSubmit: @Sendable (String, String) async throws -> Void
    }

    let configuration: Configuration

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private enum Field {
        case username
        case password
    }

    private var canSubmit: Bool {
        !isSubmitting
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    credentialsSection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .compatibleInteractiveKeyboardDismissal()
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
            .toolbar {
                ToolbarItem(placement: .sheetClose) {
                    Button(role: .close) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProviderSignInIcon(
                section: configuration.section,
                fallbackSymbolName: configuration.fallbackSymbolName
            )
            Text(configuration.serviceName)
                .font(.title.bold())
            Text(configuration.prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let helpLinkTitle = configuration.helpLinkTitle,
               let helpLinkURL = configuration.helpLinkURL {
                Link(helpLinkTitle, destination: helpLinkURL)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(configuration.usernameLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                usernameField
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(configuration.passwordLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                passwordField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var usernameField: some View {
        TextField(configuration.usernamePlaceholder, text: $username)
            .textFieldStyle(.plain)
            .textContentType(.username)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            #endif
            .submitLabel(.next)
            .focused($focusedField, equals: .username)
            .onSubmit { focusedField = .password }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
            .disabled(isSubmitting)
    }

    private var passwordField: some View {
        SecureField(configuration.passwordPlaceholder, text: $password)
            .textFieldStyle(.plain)
            .textContentType(.password)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .submitLabel(.done)
            .focused($focusedField, equals: .password)
            .onSubmit { submit() }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
            .disabled(isSubmitting)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(configuration.submitTitle)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .compatibleGlassProminentButtonStyle()
        .buttonBorderShape(.capsule)
        .disabled(!canSubmit)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        let submittedUsername = username
        let submittedPassword = password
        let action = configuration.onSubmit
        Task {
            do {
                try await action(submittedUsername, submittedPassword)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

private struct ProviderSignInIcon: View {

    let section: FeedSection?
    let fallbackSymbolName: String

    private let size: CGFloat = 56

    var body: some View {
        Group {
            if let symbolName = section?.providerSymbolName {
                Image(symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(
                        section?.providerStyle ?? AnyShapeStyle(.tint),
                        section?.providerStyle == nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.white)
                    )
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(tileBackground, in: .rect(cornerRadius: 14))
    }

    private var tileBackground: AnyShapeStyle {
        if let tileTint = section?.providerTileTint {
            return AnyShapeStyle(tileTint)
        }
        return AnyShapeStyle(Color.accentColor.gradient)
    }
}
