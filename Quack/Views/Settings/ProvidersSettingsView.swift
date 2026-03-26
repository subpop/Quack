import SwiftUI
import SwiftData

struct ProvidersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]

    @State private var editingProvider: Provider?
    @State private var providerToDelete: Provider?
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(providers) { provider in
                    ProviderRow(
                        provider: provider,
                        isDefault: providerService.defaultProviderID == provider.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingProvider = provider
                    }
                    .contextMenu {
                        Button("Edit\u{2026}") {
                            editingProvider = provider
                        }

                        Divider()

                        if providerService.defaultProviderID != provider.id {
                            Button("Set as Default") {
                                providerService.defaultProviderID = provider.id
                            }
                        }

                        Toggle("Enabled", isOn: Binding(
                            get: { provider.isEnabled },
                            set: { newValue in
                                provider.isEnabled = newValue
                                try? modelContext.save()
                                providerService.invalidateCache()
                            }
                        ))

                        Divider()

                        Button("Delete\u{2026}", role: .destructive) {
                            providerToDelete = provider
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Add a Provider\u{2026}") {
                    showingAddSheet = true
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(item: $editingProvider) { provider in
            ProviderDetailSheet(provider: provider)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProviderSheet { provider in
                editingProvider = provider
            }
        }
        .alert(
            "Delete Provider",
            isPresented: Binding(
                get: { providerToDelete != nil },
                set: { if !$0 { providerToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                providerToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let provider = providerToDelete {
                    removeProvider(provider)
                }
                providerToDelete = nil
            }
        } message: {
            if let provider = providerToDelete {
                Text("Are you sure you want to delete \"\(provider.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func removeProvider(_ provider: Provider) {
        KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
        if providerService.defaultProviderID == provider.id {
            providerService.defaultProviderID = nil
        }
        modelContext.delete(provider)
        try? modelContext.save()
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    let provider: Provider
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rounded-square icon like Xcode
            providerIcon
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .fontWeight(.medium)
                Text(provider.kind.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isDefault {
                Text("Default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !provider.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var providerIcon: some View {
        if provider.kind.isCustomIcon {
            provider.kind.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            provider.kind.icon
                .font(.title2)
        }
    }

    private var iconColor: Color {
        switch provider.kind {
        case .openAICompatible: .green
        case .anthropic: .orange
        case .foundationModels: .blue
        case .gemini: .blue
        case .vertexGemini: .indigo
        case .vertexAnthropic: .purple
        }
    }
}

// MARK: - Add Provider Sheet

private struct AddProviderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]

    var onAdd: (Provider) -> Void

    @State private var selectedKind: ProviderKind = .openAICompatible
    @State private var name: String = ""
    @State private var baseURL: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                kindIcon
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.gradient)
                    )

                Text("Add a Provider")
                    .font(.headline)
                Text("Enter the information for the provider.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Form
            Form {
                Picker("Type", selection: $selectedKind) {
                    ForEach(ProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: selectedKind) {
                    // Auto-fill defaults when type changes
                    if name.isEmpty || name.hasPrefix("New ") {
                        name = ""
                    }
                    baseURL = selectedKind.providerType.defaultBaseURL ?? ""
                }

                if selectedKind.providerType.requiresBaseURL {
                    TextField("URL", text: $baseURL, prompt: Text("https://api.example.com/v1"))
                        .font(.system(.body, design: .monospaced))
                }

                TextField("Name", text: $name, prompt: Text(selectedKind.displayName))
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addProvider()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 340)
        .onAppear {
            baseURL = selectedKind.providerType.defaultBaseURL ?? ""
        }
    }

    @ViewBuilder
    private var kindIcon: some View {
        if selectedKind.isCustomIcon {
            selectedKind.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
        } else {
            selectedKind.icon
                .font(.system(size: 28))
        }
    }

    private func addProvider() {
        let providerName = name.isEmpty ? selectedKind.displayName : name
        let provider = Provider(
            name: providerName,
            kind: selectedKind,
            sortOrder: providers.count,
            baseURL: baseURL.isEmpty ? nil : baseURL,
            requiresAPIKey: selectedKind.providerType.requiresAPIKey
        )
        modelContext.insert(provider)
        try? modelContext.save()
        dismiss()
        // Slight delay so the add sheet dismisses before edit sheet opens
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onAdd(provider)
        }
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    ProvidersSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}
