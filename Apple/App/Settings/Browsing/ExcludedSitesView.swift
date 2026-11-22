import SwiftUI

struct ExcludedSitesView: View {

    @State private var domains = ExcludedSites.domains
    @State private var isAddingSite = false
    @State private var newDomain = ""

    var body: some View {
        List {
            Section {
                ForEach(domains, id: \.self) { domain in
                    Text(verbatim: domain)
                }
                .onDelete { offsets in
                    domains.remove(atOffsets: offsets)
                }
            } footer: {
                Text(String(localized: "ExcludedSites.Footer", table: "Settings"))
            }

            if domains != ExcludedSites.defaultDomains {
                Section {
                    Button(String(localized: "ExcludedSites.RestoreDefaults", table: "Settings")) {
                        domains = ExcludedSites.defaultDomains
                    }
                }
            }
        }
        .settingsListStyle()
        .animation(.smooth.speed(2.0), value: domains)
        .navigationTitle(String(localized: "ExcludedSites", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newDomain = ""
                    isAddingSite = true
                } label: {
                    Label(String(localized: "ExcludedSites.Add", table: "Settings"), systemImage: "plus")
                }
            }
        }
        .alert(String(localized: "ExcludedSites.Add", table: "Settings"), isPresented: $isAddingSite) {
            TextField(String(localized: "ExcludedSites.Placeholder", table: "Settings"), text: $newDomain)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
            Button(String(localized: "ExcludedSites.Confirm", table: "Settings")) {
                addDomain()
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) {}
        }
        .onChange(of: domains) { _, newValue in
            ExcludedSites.domains = newValue
        }
    }

    private func addDomain() {
        guard let domain = ExcludedSites.normalizedDomain(from: newDomain), !domains.contains(domain) else { return }
        domains.append(domain)
    }
}
