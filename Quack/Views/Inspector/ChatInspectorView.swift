import SwiftUI
import SwiftData

struct ChatInspectorView: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Environment(MCPService.self) private var mcpService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]
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
            let fallback = providerService.fallbackProfile(from: profiles)

            Picker("Provider", selection: providerBinding) {
                Text("Default (\(fallback?.name ?? "None"))")
                    .tag(nil as UUID?)
                Divider()
                ForEach(profiles.filter(\.isEnabled)) { profile in
                    Text(profile.name).tag(profile.id as UUID?)
                }
            }

            let effectiveProfile = providerService.resolvedProfile(for: session, profiles: profiles)

            if let effectiveProfile {
                ModelPicker(
                    selection: modelBinding,
                    profile: effectiveProfile,
                    placeholder: "Default (\(providerService.resolvedModel(for: session, profiles: profiles)))"
                )
            }
        }
    }

    // MARK: - Parameters Section

    private var parametersSection: some View {
        Section("Parameters") {
            // Temperature
            LabeledContent(content: {
                Slider(
                    value: temperatureBinding,
                    in: 0...2,
                    step: 0.1
                )
                if session.temperature != nil {
                    Button {
                        session.temperature = nil
                        save()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default")
                }
            }, label: {
                Text("Temperature")
                Text("Controls randomness of responses.")
            })

            // Max Tokens
            LabeledContent(content:  {
                TextField(
                    "",
                    value: $session.maxTokens,
                    format: .number,
                    prompt: Text(effectiveMaxTokensPlaceholder)
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: session.maxTokens) { save() }
            }, label: {
                Text("Maximum Tokens")
                Text("Max output length per response.")
            })

            // Reasoning Effort
            LabeledContent(content: {
                Picker("", selection: reasoningBinding) {
                    Text("Default").tag(nil as String?)
                    Divider()
                    Text("None").tag("none" as String?)
                    Text("Low").tag("low" as String?)
                    Text("Medium").tag("medium" as String?)
                    Text("High").tag("high" as String?)
                    Text("Extra High").tag("xhigh" as String?)
                }
                .labelsHidden()
            }, label: {
                Text("Reasoning")
                Text("Thinking depth for capable models.")
            })
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
            let enabledServers = mcpServerConfigs.filter(\.isEnabled)

            if enabledServers.isEmpty {
                Text("No MCP servers configured.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(enabledServers) { server in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Toggle(
                                server.name.isEmpty ? server.command : server.name,
                                isOn: mcpToggleBinding(for: server)
                            )

                            Spacer()

                            mcpStatusIndicator(for: server)
                        }

                        // Show discovered tools with per-tool permission pickers
                        let isEnabledForSession = session.enabledMCPServerIDs?.contains(server.id) ?? false
                        if isEnabledForSession, mcpService.state(for: server.id) == .connected {
                            let tools = mcpService.toolSummaries(for: server.id)
                            if !tools.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(tools) { tool in
                                        HStack(spacing: 6) {
                                            Image(systemName: "wrench.and.screwdriver")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text(tool.name)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .help(tool.description)

                                            Spacer()

                                            toolPermissionPicker(
                                                for: tool.name,
                                                serverDefault: server.toolPermission
                                            )
                                        }
                                    }
                                }
                                .padding(.leading, 20)
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mcpStatusIndicator(for server: MCPServerConfig) -> some View {
        let isEnabledForSession = session.enabledMCPServerIDs?.contains(server.id) ?? false

        if !isEnabledForSession {
            // Not enabled for this session — no status to show
            EmptyView()
        } else {
            switch mcpService.state(for: server.id) {
            case .connecting:
                ProgressView()
                    .controlSize(.mini)
                    .help("Connecting...")
            case .connected:
                let count = mcpService.toolCount(for: server.id)
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.small)
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .help("Connected - \(count) tool(s)")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.small)
                    .help("Error: \(message)")
            case .disconnected:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                    .help("Disconnected")
            }
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        Section("Context Management") {
            LabeledContent(content: {
                Slider(
                    value: compactionBinding,
                    in: 0.3...0.95,
                    step: 0.05
                )
                if session.compactionThreshold != nil {
                    Button {
                        session.compactionThreshold = nil
                        save()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default")
                }
            }, label: {
                Text("Compaction Threshold")
                Text("When to summarize context.")
            })

            LabeledContent(content:  {
                TextField(
                    "",
                    value: $session.maxMessages,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: session.maxMessages) { save() }
            }, label: {
                Text("Maximum Messages")
                Text("Limit messages sent to the model.")
            })
        }
    }

    // MARK: - Bindings

    private var effectiveMaxTokensPlaceholder: String {
        let profile = providerService.resolvedProfile(for: session, profiles: profiles)
        let tokens = profile?.maxTokens ?? 4096
        return tokens.formatted()
    }

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
                session.enabledMCPServerIDs?.contains(server.id) ?? false
            },
            set: { isEnabled in
                var ids = session.enabledMCPServerIDs ?? []
                if isEnabled {
                    if !ids.contains(server.id) { ids.append(server.id) }
                } else {
                    ids.removeAll { $0 == server.id }
                }
                session.enabledMCPServerIDs = ids.isEmpty ? nil : ids
                save()
                // MainView observes enabledMCPServerIDsRaw and calls syncMCPServers()
            }
        )
    }

    private func toolPermissionPicker(for toolName: String, serverDefault: ToolPermission) -> some View {
        let effective = session.effectivePermission(for: toolName, serverDefault: serverDefault)

        return Picker("", selection: Binding(
            get: { effective },
            set: { newValue in
                session.setToolPermission(newValue, for: toolName, serverDefault: serverDefault)
                save()
            }
        )) {
            ForEach(ToolPermission.allCases, id: \.self) { perm in
                Label(perm.label, systemImage: permissionIcon(for: perm))
                    .tag(perm)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
        .foregroundStyle(permissionColor(for: effective))
    }

    private func permissionIcon(for permission: ToolPermission) -> String {
        switch permission {
        case .always: "checkmark.circle.fill"
        case .ask: "questionmark.circle.fill"
        case .deny: "xmark.circle.fill"
        }
    }

    private func permissionColor(for permission: ToolPermission) -> Color {
        switch permission {
        case .always: .green
        case .ask: .orange
        case .deny: .red
        }
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
