import SwiftUI
import SwiftData

struct ProvidersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]

    @State private var editingProvider: Provider?
    @State private var confirmDelete: Provider?

    var body: some View {
        Form {
            Section {
                if providers.isEmpty {
                    ContentUnavailableView(
                        "No Providers",
                        systemImage: "cloud",
                        description: Text("Add a provider to get started.")
                    )
                } else {
                    ForEach(providers) { provider in
                        HStack(spacing: 12) {
                            Image(systemName: provider.iconName)
                                .foregroundStyle(provider.isEnabled ? .primary : .secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)

                                Text("\(provider.kind.displayName) \(provider.isEnabled ? "" : " (Disabled)")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(provider.defaultModel)
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            if providerService.defaultProviderID == provider.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.callout)
                                    .help("Default provider")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingProvider = provider
                        }
                    }
                    .onDelete(perform: deleteProviders)
                }
            } header: {
                Text("Providers")
            } footer: {
                Text("Click a provider to configure it. Swipe to delete.")
            }

            Section {
                Menu {
                    ForEach(ProviderKind.allCases) { kind in
                        Button {
                            addProvider(kind: kind)
                        } label: {
                            Label(kind.displayName, systemImage: kind == .openAICompatible ? "network" : kind == .anthropic ? "sparkle" : "apple.logo")
                        }
                    }
                } label: {
                    Label("Add Provider...", systemImage: "plus.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .sheet(item: $editingProvider) { provider in
            ProviderDetailView(provider: provider)
        }
        .alert("Delete Provider?", isPresented: .init(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmDelete = nil }
            Button("Delete", role: .destructive) {
                if let provider = confirmDelete {
                    KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
                    modelContext.delete(provider)
                    try? modelContext.save()
                    confirmDelete = nil
                }
            }
        } message: {
            Text("This will permanently remove the provider and its API key.")
        }
    }

    // MARK: - Actions

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
        editingProvider = provider
    }

    private func deleteProviders(at offsets: IndexSet) {
        for index in offsets {
            let provider = providers[index]
            KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
            modelContext.delete(provider)
        }
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    ProvidersSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}
