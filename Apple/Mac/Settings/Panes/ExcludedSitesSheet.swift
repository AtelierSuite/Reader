import SwiftUI

struct ExcludedSitesSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var domains = ExcludedSites.domains
    @State private var selection: Set<String> = []
    @State private var newDomain = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(SettingsText.settings("ExcludedSites"))
                .font(.headline)
            Text(SettingsText.settings("ExcludedSites.Footer"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            List(selection: $selection) {
                ForEach(domains, id: \.self) { domain in
                    Text(verbatim: domain)
                }
                .onDelete { offsets in
                    domains.remove(atOffsets: offsets)
                }
            }
            .onDeleteCommand(perform: removeSelection)
            .frame(height: 220)
            HStack {
                TextField(SettingsText.settings("ExcludedSites.Placeholder"), text: $newDomain)
                    .onSubmit(addDomain)
                Button(SettingsText.settings("ExcludedSites.Confirm"), action: addDomain)
                    .disabled(ExcludedSites.normalizedDomain(from: newDomain) == nil)
                Button {
                    removeSelection()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
            }
            HStack {
                Button(SettingsText.settings("ExcludedSites.RestoreDefaults")) {
                    domains = ExcludedSites.defaultDomains
                }
                .disabled(domains == ExcludedSites.defaultDomains)
                Spacer()
                Button(String(localized: "Shared.Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onChange(of: domains) { _, newValue in
            ExcludedSites.domains = newValue
        }
    }

    private func addDomain() {
        guard let domain = ExcludedSites.normalizedDomain(from: newDomain) else { return }
        if !domains.contains(domain) {
            domains.append(domain)
        }
        newDomain = ""
    }

    private func removeSelection() {
        domains.removeAll { selection.contains($0) }
        selection.removeAll()
    }
}
