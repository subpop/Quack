import SwiftUI
import SwiftData

// MARK: - Provider Detail Sheet

struct ProviderDetailSheet: View {
    @Bindable var provider: Provider

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderService.self) private var providerService

    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            sheetForm
            Divider()
            sheetFooter
        }
        .frame(width: 500, height: 580)
        .onAppear {
            loadAPIKey()
        }
        .alert(
            "Delete Provider",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteProvider()
            }
        } message: {
            Text("Are you sure you want to delete \"\(provider.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 6) {
            providerIcon
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.gradient)
                )

            Text(provider.name)
                .font(.headline)
            Text(provider.kind.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Form

    private var sheetForm: some View {
        Form {
            // MARK: - Identity
            Section {
                TextField("Name", text: $provider.name, prompt: Text("Provider name"))
                    .onChange(of: provider.name) { save() }

                Picker("Kind", selection: Binding(
                    get: { provider.kind },
                    set: { newValue in
                        provider.kind = newValue
                        provider.baseURL = newValue.providerType.defaultBaseURL
                        save()
                        providerService.invalidateCache()
                    }
                )) {
                    ForEach(ProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }

                Toggle("Enabled", isOn: $provider.isEnabled)
                    .onChange(of: provider.isEnabled) {
                        save()
                        providerService.invalidateCache()
                    }
            }

            // MARK: - Connection
            if provider.requiresAPIKey || provider.kind.providerType.requiresBaseURL {
                Section {
                    if provider.kind.providerType.requiresBaseURL {
                        LabeledContent("URL") {
                            TextField(
                                "",
                                text: Binding(
                                    get: { provider.baseURL ?? "" },
                                    set: { provider.baseURL = $0.isEmpty ? nil : $0 }
                                ),
                                prompt: Text("https://api.example.com/v1")
                            )
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: provider.baseURL) {
                                save()
                                providerService.invalidateCache()
                            }
                        }
                    }

                    if provider.requiresAPIKey {
                        LabeledContent("API Key") {
                            HStack {
                                if showAPIKey {
                                    TextField("", text: $apiKey, prompt: Text("•••••••••••••••"))
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    SecureField("", text: $apiKey, prompt: Text("sk-01234deadbeef"))
                                }

                                Button {
                                    showAPIKey.toggle()
                                } label: {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.borderless)
                            }
                            .onChange(of: apiKey) {
                                if apiKey.isEmpty {
                                    KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
                                    apiKey = ""
                                    providerService.invalidateCache()
                                } else {
                                    saveAPIKey()
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - Model
            Section {
                ModelPicker(
                    selection: Binding(
                        get: { provider.defaultModel },
                        set: { newValue in
                            provider.defaultModel = newValue
                            save()
                            providerService.invalidateCache()
                        }
                    ),
                    provider: provider
                )

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

            // MARK: - Advanced
            Section("Advanced") {
                LabeledContent(content: {
                    TextField("",
                              value: $provider.maxTokens,
                              format: .number,
                              prompt: Text("4096"))
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: provider.maxTokens) {
                        save()
                        providerService.invalidateCache()
                    }
                }, label: {
                    Text("Maximum Tokens")
                    Text("The maximum number of tokens the model can generate in a single response before it stops producing output.")
                })

                LabeledContent(content: {
                    TextField("",
                              value: $provider.contextWindowSize,
                              format: .number,
                              prompt: Text("auto"))
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: provider.contextWindowSize) {
                            save()
                            providerService.invalidateCache()
                        }
                }, label: {
                    Text("Context Window")
                    Text("The total number of tokens the conversation can consume before the app compresses (summarizes) the context to free up space.")
                })

                if provider.kind.providerType.supportsCaching {
                    LabeledContent(content: {
                        Toggle("", isOn: $provider.cachingEnabled)
                            .onChange(of: provider.cachingEnabled) {
                                save()
                                providerService.invalidateCache()
                            }
                    }, label: {
                        Text("Prompt Caching")
                        Text("When enabled, allows the provider to cache prompt prefixes so repeated or similar requests can be processed faster and at lower cost (only shown for providers that support it).")
                    })
                }

                LabeledContent(content:  {
                    TextField("", value: $provider.retryMaxAttempts, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: provider.retryMaxAttempts) { save() }
                }, label: {
                    Text("Maximum Retry Attempts")
                    Text("The number of times a failed API request will be retried before the app gives up and surfaces an error.")
                })

                LabeledContent(content: {
                    TextField("", value: $provider.retryBaseDelay, format: .number, prompt: Text("30"))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: provider.retryBaseDelay) { save() }
                }, label: {
                    Text("Base Delay")
                    Text("The initial number of seconds to wait before retrying a failed request, typically used as the base for exponential backoff.")
                })

                LabeledContent(content: {
                    TextField("", value: $provider.retryMaxDelay, format: .number, prompt: Text("30"))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: provider.retryMaxDelay) { save() }
                }, label: {
                    Text("Max Delay")
                    Text("The maximum number of seconds the app will wait between retries, capping the exponential backoff so delays don't grow indefinitely.")
                })
            }

            // Default Provider
            Section {
                let isDefault = providerService.defaultProviderID == provider.id
                Button(isDefault ? "This is the default provider" : "Set as Default Provider") {
                    providerService.defaultProviderID = provider.id
                }
                .disabled(isDefault)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            Button("Delete\u{2026}", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var providerIcon: some View {
        if provider.kind.isCustomIcon {
            provider.kind.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
        } else {
            provider.kind.icon
                .font(.system(size: 28))
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

    private func loadAPIKey() {
        apiKey = KeychainService.load(key: KeychainService.apiKeyKey(for: provider.id)) ?? ""
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        try? KeychainService.save(key: KeychainService.apiKeyKey(for: provider.id), value: apiKey)
        providerService.invalidateCache()
    }

    private func save() {
        try? modelContext.save()
    }

    private func deleteProvider() {
        KeychainService.delete(key: KeychainService.apiKeyKey(for: provider.id))
        if providerService.defaultProviderID == provider.id {
            providerService.defaultProviderID = nil
        }
        modelContext.delete(provider)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Previews

#Preview("Provider Sheet - OpenAI") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailSheet(provider: data.providers[0])
        .previewEnvironment(container: container)
}

#Preview("Provider Sheet - Anthropic") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailSheet(provider: data.providers[1])
        .previewEnvironment(container: container)
}
