import SwiftUI
import SwiftData

struct ProviderDetailView: View {
    @Bindable var provider: Provider

    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService

    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var keychainSaveStatus: String?
    @State private var suggestedModelsText: String = ""

    var body: some View {
        Form {
            identitySection
            if provider.requiresAPIKey {
                apiKeySection
            }
            connectionSection
            modelSection
            advancedSection
            if provider.kind.providerType.supportsCaching {
                cachingSection
            }
            retrySection
            defaultProviderSection
        }
        .formStyle(.grouped)
        .onAppear {
            loadAPIKey()
            suggestedModelsText = provider.suggestedModels.joined(separator: "\n")
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        Section {
            Toggle("Enabled", isOn: $provider.isEnabled)
                .onChange(of: provider.isEnabled) {
                    save()
                    providerService.invalidateCache()
                }

            TextField("Name", text: $provider.name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: provider.name) { save() }

            HStack {
                Text("Icon")
                Spacer()
                TextField("SF Symbol name", text: $provider.iconName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onChange(of: provider.iconName) { save() }
                Image(systemName: provider.iconName)
                    .frame(width: 20)
            }

            LabeledContent("Type") {
                Text(provider.kind.displayName)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(provider.name)
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Section("API Key") {
            HStack {
                if showAPIKey {
                    TextField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Button("Save Key") {
                    saveAPIKey()
                }
                .disabled(apiKey.isEmpty)

                if !apiKey.isEmpty {
                    Button("Clear Saved Key") {
                        KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
                        apiKey = ""
                        keychainSaveStatus = "Key cleared"
                        providerService.invalidateCache()
                    }
                }

                if let status = keychainSaveStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Requires API Key", isOn: $provider.requiresAPIKey)
                .onChange(of: provider.requiresAPIKey) { save() }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section("Connection") {
            if provider.kind.providerType.requiresBaseURL {
                HStack {
                    Text("Base URL")
                    Spacer()
                    TextField(
                        "https://api.example.com/v1",
                        text: Binding(
                            get: { provider.baseURL ?? "" },
                            set: { provider.baseURL = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .onChange(of: provider.baseURL) {
                        save()
                        providerService.invalidateCache()
                    }
                }
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        Section("Model") {
            HStack {
                TextField("Default Model", text: $provider.defaultModel)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: provider.defaultModel) {
                        save()
                        providerService.invalidateCache()
                    }

                if !provider.suggestedModels.isEmpty {
                    Menu {
                        ForEach(provider.suggestedModels, id: \.self) { model in
                            Button(model) {
                                provider.defaultModel = model
                                save()
                                providerService.invalidateCache()
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            DisclosureGroup("Suggested Models") {
                TextEditor(text: $suggestedModelsText)
                    .font(.body.monospaced())
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .onChange(of: suggestedModelsText) {
                        provider.suggestedModels = suggestedModelsText
                            .split(separator: "\n", omittingEmptySubsequences: false)
                            .map(String.init)
                            .filter { !$0.isEmpty }
                        save()
                    }

                Text("One model per line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        Section("Advanced") {
            HStack {
                Text("Max Tokens")
                Spacer()
                TextField("Max Tokens", value: $provider.maxTokens, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: provider.maxTokens) {
                        save()
                        providerService.invalidateCache()
                    }
            }

            HStack {
                Text("Context Window Size")
                Spacer()
                TextField(
                    "Auto",
                    value: $provider.contextWindowSize,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
                .onChange(of: provider.contextWindowSize) {
                    save()
                    providerService.invalidateCache()
                }
            }

            Picker("Reasoning Effort", selection: Binding(
                get: { provider.reasoningEffort },
                set: { newValue in
                    provider.reasoningEffort = newValue
                    save()
                    providerService.invalidateCache()
                }
            )) {
                Text("None").tag(nil as String?)
                Text("Low").tag("low" as String?)
                Text("Medium").tag("medium" as String?)
                Text("High").tag("high" as String?)
                Text("Extra High").tag("xhigh" as String?)
            }
        }
    }

    // MARK: - Caching (Anthropic)

    private var cachingSection: some View {
        Section("Prompt Caching") {
            Toggle("Enable Prompt Caching", isOn: $provider.cachingEnabled)
                .onChange(of: provider.cachingEnabled) {
                    save()
                    providerService.invalidateCache()
                }

            Text("Caches system prompts and tool definitions for 5 minutes, reducing input token costs by up to 90%.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Retry Policy

    private var retrySection: some View {
        Section("Retry Policy") {
            HStack {
                Text("Max Attempts")
                Spacer()
                TextField("3", value: $provider.retryMaxAttempts, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: provider.retryMaxAttempts) { save() }
            }

            HStack {
                Text("Base Delay (seconds)")
                Spacer()
                TextField("1.0", value: $provider.retryBaseDelay, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: provider.retryBaseDelay) { save() }
            }

            HStack {
                Text("Max Delay (seconds)")
                Spacer()
                TextField("30.0", value: $provider.retryMaxDelay, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: provider.retryMaxDelay) { save() }
            }
        }
    }

    // MARK: - Default Provider

    @MainActor
    private var defaultProviderSection: some View {
        Section {
            let isDefault = providerService.defaultProviderID == provider.id
            Button(isDefault ? "This is the default provider" : "Set as Default Provider") {
                providerService.defaultProviderID = provider.id
            }
            .disabled(isDefault)
        }
    }

    // MARK: - Helpers

    private func loadAPIKey() {
        apiKey = KeychainService.load(key: KeychainService.apiKeyKey(for: provider.id)) ?? ""
        keychainSaveStatus = nil
    }

    private func saveAPIKey() {
        do {
            try KeychainService.save(key: KeychainService.apiKeyKey(for: provider.id), value: apiKey)
            keychainSaveStatus = "Key saved"
            providerService.invalidateCache()
        } catch {
            keychainSaveStatus = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

#Preview("OpenAI Compatible") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailView(provider: data.providers[0])
        .previewEnvironment(container: container)
        .frame(width: 500, height: 700)
}

#Preview("Anthropic") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailView(provider: data.providers[1])
        .previewEnvironment(container: container)
        .frame(width: 500, height: 700)
}
