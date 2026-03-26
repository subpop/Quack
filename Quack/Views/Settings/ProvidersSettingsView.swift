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

    @State private var selectedPreset: ProviderPreset = .ollama

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                presetIcon(for: selectedPreset, size: 32)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(presetColor.gradient)
                    )

                Text("Add a Provider")
                    .font(.headline)
                Text("Choose a provider to get started quickly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Preset picker — grid of labelled buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ProviderPreset.allCases) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPreset = preset
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    if selectedPreset == .custom {
                        addCustomProvider()
                    } else {
                        addProvider()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 380)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func presetIcon(for preset: ProviderPreset, size: CGFloat) -> some View {
        if preset.isCustomIcon {
            preset.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            preset.icon
                .font(.system(size: size * 0.75))
        }
    }

    private var presetColor: Color {
        switch selectedPreset {
        case .ollama:     .gray
        case .openAI:     .green
        case .anthropic:  .orange
        case .gemini:     .blue
        case .openRouter: .purple
        case .groq:       .indigo
        case .together:   .cyan
        case .mistral:    .orange
        case .custom:     .secondary
        }
    }

    private func addProvider() {
        let provider = Provider(
            name: selectedPreset.displayName,
            kind: selectedPreset.kind,
            sortOrder: providers.count,
            baseURL: selectedPreset.baseURL,
            requiresAPIKey: selectedPreset.requiresAPIKey,
            defaultModel: selectedPreset.defaultModel
        )
        modelContext.insert(provider)
        try? modelContext.save()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onAdd(provider)
        }
    }

    private func addCustomProvider() {
        let provider = Provider(
            name: "New Provider",
            kind: .openAICompatible,
            sortOrder: providers.count
        )
        modelContext.insert(provider)
        try? modelContext.save()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onAdd(provider)
        }
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let preset: ProviderPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                presetIcon
                    .frame(height: 24)

                Text(preset.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var presetIcon: some View {
        if preset.isCustomIcon {
            preset.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            preset.icon
                .font(.title2)
        }
    }
}

#Preview("Provider List") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    ProvidersSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}

#Preview("Add Provider Sheet") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    AddProviderSheet { _ in }
        .previewEnvironment(container: container)
}
