import SwiftUI
import SwiftData

struct ProvidersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]

    @State private var selectedProviderID: UUID?

    private var selectedProvider: Provider? {
        providers.first { $0.id == selectedProviderID }
    }

    var body: some View {
        HSplitView {
            providerList
                .frame(minWidth: 180, maxWidth: 220, maxHeight: .infinity)

            Group {
                if let provider = selectedProvider {
                    ProviderDetailView(provider: provider)
                } else {
                    ContentUnavailableView("Select a provider", systemImage: "cloud")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var providerList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedProviderID) {
                ForEach(providers) { provider in
                    HStack(alignment: .center) {
                        Image(systemName: provider.iconName)
                        VStack(alignment: .leading) {
                            Text(provider.name)
                            Text(provider.kind.displayName)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(
                                provider.isEnabled ? .green : .secondary
                            )
                    }
                    .tag(provider.id)
                    .padding(8)
                }
            }

            Divider()

            HStack {
                Menu {
                    ForEach(ProviderKind.allCases) { kind in
                        Button(kind.displayName) {
                            addProvider(kind: kind)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    removeSelectedProvider()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedProvider == nil)

                Spacer()
            }
            .padding(8)
        }
    }

    private func addProvider(kind: ProviderKind) {
        let provider = Provider(
            name: "New \(kind.displayName) Provider",
            kind: kind,
            sortOrder: providers.count,
            baseURL: kind == .anthropic ? "https://api.anthropic.com/v1" : nil,
            requiresAPIKey: kind.requiresAPIKey
        )
        modelContext.insert(provider)
        try? modelContext.save()
        selectedProviderID = provider.id
    }

    private func removeSelectedProvider() {
        guard let provider = selectedProvider else { return }
        // Clean up the API key from Keychain
        KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
        selectedProviderID = nil
        modelContext.delete(provider)
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    ProvidersSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 650, height: 500)
}
