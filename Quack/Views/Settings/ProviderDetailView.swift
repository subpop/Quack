import SwiftUI
import SwiftData

struct ProviderDetailView: View {
    @Bindable var provider: Provider

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService

    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var keychainSaveStatus: String?
    @State private var suggestedModelsText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: provider.iconName)
                    .font(.title2)
                    .foregroundStyle(provider.isEnabled ? .primary : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.headline)
                    Text(provider.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $provider.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: provider.isEnabled) {
                        save()
                        providerService.invalidateCache()
                    }
            }
            .padding()

            Divider()

            // Content
            Form {
                identitySection
                if provider.requiresAPIKey {
                    apiKeySection
                }
                if provider.kind.requiresBaseURL {
                    connectionSection
                }
                modelSection
                parametersSection
                if provider.kind.supportsCaching {
                    cachingSection
                }
                retrySection
                defaultProviderSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 620)
        .onAppear {
            loadAPIKey()
            suggestedModelsText = provider.suggestedModels.joined(separator: "\n")
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        Section("Identity") {
            TextField("Name", text: $provider.name)
                .onChange(of: provider.name) { save() }

            TextField("Icon (SF Symbol)", text: $provider.iconName)
                .onChange(of: provider.iconName) { save() }

            LabeledContent("Type") {
                Text(provider.kind.displayName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Section("Authentication") {
            HStack {
                Group {
                    if showAPIKey {
                        TextField("API Key", text: $apiKey)
                    } else {
                        SecureField("API Key", text: $apiKey)
                    }
                }
                .font(.body.monospaced())

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Button("Save Key") { saveAPIKey() }
                    .disabled(apiKey.isEmpty)

                if !apiKey.isEmpty {
                    Button("Clear Key", role: .destructive) {
                        KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
                        apiKey = ""
                        keychainSaveStatus = "Cleared"
                        providerService.invalidateCache()
                    }
                }

                Spacer()

                if let status = keychainSaveStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section("Connection") {
            TextField(
                "Base URL",
                text: Binding(
                    get: { provider.baseURL ?? "" },
                    set: { provider.baseURL = $0.isEmpty ? nil : $0 }
                ),
                prompt: Text("https://api.example.com/v1")
            )
            .font(.body.monospaced())
            .onChange(of: provider.baseURL) {
                save()
                providerService.invalidateCache()
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        Section("Model") {
            HStack {
                TextField("Default Model", text: $provider.defaultModel)
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
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            DisclosureGroup("Suggested Models") {
                TextEditor(text: $suggestedModelsText)
                    .font(.callout.monospaced())
                    .frame(minHeight: 60, maxHeight: 120)
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
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Parameters

    private var parametersSection: some View {
        Section("Parameters") {
            LabeledContent("Max Tokens") {
                TextField("Max Tokens", value: $provider.maxTokens, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: provider.maxTokens) {
                        save()
                        providerService.invalidateCache()
                    }
            }

            LabeledContent("Context Window") {
                TextField("Auto", value: $provider.contextWindowSize, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
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
            }
        }
    }

    // MARK: - Caching

    private var cachingSection: some View {
        Section {
            Toggle("Prompt Caching", isOn: $provider.cachingEnabled)
                .onChange(of: provider.cachingEnabled) {
                    save()
                    providerService.invalidateCache()
                }
        } footer: {
            Text("Caches system prompts and tool definitions, reducing input costs.")
        }
    }

    // MARK: - Retry Policy

    private var retrySection: some View {
        Section("Retry Policy") {
            LabeledContent("Max Attempts") {
                TextField("3", value: $provider.retryMaxAttempts, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .onChange(of: provider.retryMaxAttempts) { save() }
            }

            LabeledContent("Base Delay") {
                HStack(spacing: 4) {
                    TextField("1.0", value: $provider.retryBaseDelay, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: provider.retryBaseDelay) { save() }
                    Text("s")
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Max Delay") {
                HStack(spacing: 4) {
                    TextField("30", value: $provider.retryMaxDelay, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: provider.retryMaxDelay) { save() }
                    Text("s")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Default Provider

    @MainActor
    private var defaultProviderSection: some View {
        Section {
            let isDefault = providerService.defaultProviderID == provider.id
            Button(isDefault ? "Default Provider" : "Set as Default") {
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
            keychainSaveStatus = "Saved"
            providerService.invalidateCache()
        } catch {
            keychainSaveStatus = "Error: \(error.localizedDescription)"
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
}

#Preview("Anthropic") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailView(provider: data.providers[1])
        .previewEnvironment(container: container)
}
