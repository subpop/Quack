// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData

// MARK: - Provider Detail Sheet

struct ProviderDetailSheet: View {
    @Bindable var profile: ProviderProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderService.self) private var providerService
    @Environment(MLXModelService.self) private var mlxModelService

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
                deleteProfile()
            }
        } message: {
            Text("Are you sure you want to delete \"\(profile.name)\"? This action cannot be undone.")
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

            Text(profile.name)
                .font(.headline)
            Text(profile.platform.displayName)
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
                TextField("Name", text: $profile.name, prompt: Text("Provider name"))
                    .onChange(of: profile.name) { save() }

                Picker("Platform", selection: Binding(
                    get: { profile.platform },
                    set: { newValue in
                        profile.platform = newValue
                        profile.baseURL = newValue.defaultBaseURL

                        // When switching to MLX, auto-select a model:
                        // prefer the currently loaded model, then the first
                        // downloaded model, so the picker isn't empty.
                        if newValue == .mlx && profile.defaultModel.isEmpty {
                            if let loaded = mlxModelService.loadedModelID {
                                profile.defaultModel = loaded
                            } else if let first = MLXModelService.downloadedModelIDs().first {
                                profile.defaultModel = first
                            }
                        }

                        save()
                        providerService.invalidateCache()
                    }
                )) {
                    ForEach(ProviderPlatform.allCases) { platform in
                        Text(platform.displayName).tag(platform)
                    }
                }

                Toggle("Enabled", isOn: $profile.isEnabled)
                    .onChange(of: profile.isEnabled) {
                        save()
                        providerService.invalidateCache()
                    }
            }

            // MARK: - Connection
            if profile.requiresAPIKey || profile.platform.requiresBaseURL || isVertexProvider {
                Section {
                    if profile.platform.requiresBaseURL {
                        TextField(
                            text: Binding(
                                get: { profile.baseURL ?? "" },
                                set: { profile.baseURL = $0.isEmpty ? nil : $0 }
                            ),
                            prompt: Text("https://api.example.com/v1")
                        ) {
                            Text("URL").font(.body)
                        }
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: profile.baseURL) {
                            save()
                            providerService.invalidateCache()
                        }
                    }

                    if isVertexProvider {
                        TextField(
                            text: Binding(
                                get: { profile.projectID ?? "" },
                                set: { profile.projectID = $0.isEmpty ? nil : $0 }
                            ),
                            prompt: Text("my-gcp-project")
                        ) {
                            Text("Project ID").font(.body)
                        }
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: profile.projectID) {
                            save()
                            providerService.invalidateCache()
                        }

                        TextField(
                            text: Binding(
                                get: { profile.location ?? "" },
                                set: { profile.location = $0.isEmpty ? nil : $0 }
                            ),
                            prompt: Text("us-central1")
                        ) {
                            Text("Location").font(.body)
                        }
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: profile.location) {
                            save()
                            providerService.invalidateCache()
                        }
                    }

                    if profile.requiresAPIKey {
                        LabeledContent("API Key") {
                            HStack {
                                if showAPIKey {
                                    TextField("", text: $apiKey, prompt: Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}"))
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
                                    KeychainService.delete(key: KeychainService.apiKeyKey(for: profile.id))
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
                        get: { profile.defaultModel },
                        set: { newValue in
                            profile.defaultModel = newValue
                            save()
                            providerService.invalidateCache()
                        }
                    ),
                    profile: profile
                )

                Picker("Reasoning Effort", selection: Binding(
                    get: { profile.reasoningEffort },
                    set: { newValue in
                        profile.reasoningEffort = newValue
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
                              value: $profile.maxTokens,
                              format: .number,
                              prompt: Text("4096"))
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: profile.maxTokens) {
                        save()
                        providerService.invalidateCache()
                    }
                }, label: {
                    Text("Maximum Tokens")
                    Text("The maximum number of tokens the model can generate in a single response before it stops producing output.")
                })

                LabeledContent(content: {
                    TextField("",
                              value: $profile.contextWindowSize,
                              format: .number,
                              prompt: Text("auto"))
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: profile.contextWindowSize) {
                            save()
                            providerService.invalidateCache()
                        }
                }, label: {
                    Text("Context Window")
                    Text("The total number of tokens the conversation can consume before the app compresses (summarizes) the context to free up space.")
                })

                if profile.platform.supportsCaching {
                    LabeledContent(content: {
                        Toggle("", isOn: $profile.cachingEnabled)
                            .onChange(of: profile.cachingEnabled) {
                                save()
                                providerService.invalidateCache()
                            }
                    }, label: {
                        Text("Prompt Caching")
                        Text("When enabled, allows the provider to cache prompt prefixes so repeated or similar requests can be processed faster and at lower cost (only shown for providers that support it).")
                    })
                }

                LabeledContent(content:  {
                    TextField("", value: $profile.retryMaxAttempts, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: profile.retryMaxAttempts) { save() }
                }, label: {
                    Text("Maximum Retry Attempts")
                    Text("The number of times a failed API request will be retried before the app gives up and surfaces an error.")
                })

                LabeledContent(content: {
                    TextField("", value: $profile.retryBaseDelay, format: .number, prompt: Text("30"))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: profile.retryBaseDelay) { save() }
                }, label: {
                    Text("Base Delay")
                    Text("The initial number of seconds to wait before retrying a failed request, typically used as the base for exponential backoff.")
                })

                LabeledContent(content: {
                    TextField("", value: $profile.retryMaxDelay, format: .number, prompt: Text("30"))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: profile.retryMaxDelay) { save() }
                }, label: {
                    Text("Maximum Delay")
                    Text("The maximum number of seconds the app will wait between retries, capping the exponential backoff so delays don't grow indefinitely.")
                })
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

    private var isVertexProvider: Bool {
        profile.platform == .vertexGemini || profile.platform == .vertexAnthropic
    }

    @ViewBuilder
    private var providerIcon: some View {
        if profile.iconIsCustom {
            profile.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
        } else {
            profile.icon
                .font(.system(size: 28))
        }
    }

    private var iconColor: Color {
        profile.iconColor
    }

    private func loadAPIKey() {
        apiKey = KeychainService.load(key: KeychainService.apiKeyKey(for: profile.id)) ?? ""
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        try? KeychainService.save(key: KeychainService.apiKeyKey(for: profile.id), value: apiKey)
        providerService.invalidateCache()
    }

    private func save() {
        try? modelContext.save()
    }

    private func deleteProfile() {
        KeychainService.delete(key: KeychainService.apiKeyKey(for: profile.id))
        modelContext.delete(profile)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Previews

#Preview("Provider Sheet - OpenAI") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailSheet(profile: data.profiles[0])
        .previewEnvironment(container: container)
}

#Preview("Provider Sheet - Anthropic") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailSheet(profile: data.profiles[1])
        .previewEnvironment(container: container)
}
#Preview("Provider Sheet - Google AI") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ProviderDetailSheet(profile: data.profiles[4])
        .previewEnvironment(container: container)
}


