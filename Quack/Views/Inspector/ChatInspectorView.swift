import SwiftUI
import SwiftData

struct ChatInspectorView: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    var body: some View {
        Form {
            modelSection
            parametersSection
            systemPromptSection
            mcpSection
            contextSection
        }
        .formStyle(.grouped)
        .navigationTitle("Inspector")
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section("Model") {
            let defaultProvider = providerService.defaultProvider(from: providers)

            Picker("Provider", selection: providerBinding) {
                Text("Default (\(defaultProvider?.name ?? "None"))")
                    .tag(nil as UUID?)
                Divider()
                ForEach(providers.filter(\.isEnabled)) { provider in
                    Text(provider.name).tag(provider.id as UUID?)
                }
            }

            let effectiveProvider = providerService.resolvedProvider(for: session, providers: providers)

            if let effectiveProvider {
                ModelPicker(
                    selection: modelBinding,
                    provider: effectiveProvider,
                    placeholder: "Default (\(providerService.resolvedModel(for: session, providers: providers)))"
                )
            }
        }
    }

    // MARK: - Parameters Section

    private var parametersSection: some View {
        Section("Parameters") {
            // Temperature
            VStack(alignment: .leading) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    if let temp = session.temperature {
                        Text(String(format: "%.1f", temp))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button("Reset") {
                            session.temperature = nil
                            save()
                        }
                        .font(.caption)
                    } else {
                        Text("Default")
                            .foregroundStyle(.tertiary)
                    }
                }
                Slider(
                    value: temperatureBinding,
                    in: 0...2,
                    step: 0.1
                )
            }

            // Max Tokens
            HStack {
                Text("Max Tokens")
                Spacer()
                TextField(
                    "Default",
                    value: $session.maxTokens,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
                .onChange(of: session.maxTokens) { save() }
            }

            // Reasoning Effort
            Picker("Reasoning", selection: reasoningBinding) {
                Text("Default").tag(nil as String?)
                Divider()
                Text("None").tag("none" as String?)
                Text("Low").tag("low" as String?)
                Text("Medium").tag("medium" as String?)
                Text("High").tag("high" as String?)
                Text("Extra High").tag("xhigh" as String?)
            }
        }
    }

    // MARK: - System Prompt Section

    private var systemPromptSection: some View {
        Section("System Prompt") {
            TextEditor(text: systemPromptBinding)
                .font(.body.monospaced())
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)

            if session.systemPrompt != nil {
                Button("Clear") {
                    session.systemPrompt = nil
                    save()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - MCP Section

    private var mcpSection: some View {
        Section("MCP Servers") {
            if mcpServerConfigs.isEmpty {
                Text("No MCP servers configured.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(mcpServerConfigs) { server in
                    Toggle(server.name.isEmpty ? server.command : server.name, isOn: mcpToggleBinding(for: server))
                }
            }
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        Section("Context Management") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Compaction Threshold")
                    Spacer()
                    if let threshold = session.compactionThreshold {
                        Text("\(Int(threshold * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button("Reset") {
                            session.compactionThreshold = nil
                            save()
                        }
                        .font(.caption)
                    } else {
                        Text("Default")
                            .foregroundStyle(.tertiary)
                    }
                }
                Slider(
                    value: compactionBinding,
                    in: 0.3...0.95,
                    step: 0.05
                )
            }

            HStack {
                Text("Max Messages")
                Spacer()
                TextField(
                    "Default",
                    value: $session.maxMessages,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
                .onChange(of: session.maxMessages) { save() }
            }
        }
    }

    // MARK: - Bindings

    private var providerBinding: Binding<UUID?> {
        Binding(
            get: { session.providerID },
            set: { newValue in
                session.providerID = newValue
                save()
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { session.modelIdentifier ?? "" },
            set: { newValue in
                session.modelIdentifier = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { session.temperature ?? 1.0 },
            set: { newValue in
                session.temperature = newValue
                save()
            }
        )
    }

    private var reasoningBinding: Binding<String?> {
        Binding(
            get: { session.reasoningEffort },
            set: { newValue in
                session.reasoningEffort = newValue
                save()
            }
        )
    }

    private var systemPromptBinding: Binding<String> {
        Binding(
            get: { session.systemPrompt ?? "" },
            set: { newValue in
                session.systemPrompt = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private var compactionBinding: Binding<Double> {
        Binding(
            get: { session.compactionThreshold ?? 0.7 },
            set: { newValue in
                session.compactionThreshold = newValue
                save()
            }
        )
    }

    private func mcpToggleBinding(for server: MCPServerConfig) -> Binding<Bool> {
        Binding(
            get: {
                guard let ids = session.enabledMCPServerIDs else { return true }
                return ids.contains(server.id)
            },
            set: { isEnabled in
                var ids = session.enabledMCPServerIDs ?? mcpServerConfigs.map(\.id)
                if isEnabled {
                    if !ids.contains(server.id) { ids.append(server.id) }
                } else {
                    ids.removeAll { $0 == server.id }
                }
                session.enabledMCPServerIDs = ids
                save()
            }
        )
    }

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatInspectorView(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 700)
}
