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

struct ChatInspectorView: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Environment(MCPService.self) private var mcpService
    @Environment(BuiltInToolService.self) private var builtInToolService
    @Environment(ModelPricingService.self) private var modelPricingService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    @State private var showingPromptGenerator = false
    @State private var agentDescription = ""
    @State private var isGeneratingPrompt = false

    var body: some View {
        Form {
            sessionInfoSection
            modelSection
            parametersSection
            systemPromptSection
            toolsSection
            contextSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Session Info Section

    private var sessionInfoSection: some View {
        Section("Session") {
            let stats = sessionStats

            // Stat cards grid
            let columns = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                statCard(
                    icon: "arrow.up.circle.fill",
                    color: .blue,
                    value: stats.inputTokens,
                    label: "Input"
                )

                statCard(
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    value: stats.outputTokens,
                    label: "Output"
                )

                if stats.reasoningTokens > 0 {
                    statCard(
                        icon: "brain.fill",
                        color: .orange,
                        value: stats.reasoningTokens,
                        label: "Reasoning"
                    )
                }

                statCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .secondary,
                    value: stats.messageCount,
                    label: "Messages"
                )
            }
            .animation(.easeInOut(duration: 0.3), value: stats)

            // Token distribution bar
            if stats.totalTokens > 0 {
                tokenDistributionBar(stats: stats)
                    .padding(.top, 4)
            }

            // Cost row
            costDisplay(stats: stats)
                .padding(.top, 2)
        }
    }

    // MARK: - Stat Card

    private func statCard(icon: String, color: Color, value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text(value.formatted())
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.easeInOut(duration: 0.4), value: value)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Token Distribution Bar

    private func tokenDistributionBar(stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Token Distribution")
                .font(.caption2)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let total = max(stats.totalTokens, 1)
                let inputFraction = CGFloat(stats.inputTokens) / CGFloat(total)
                let outputFraction = CGFloat(stats.outputTokens) / CGFloat(total)
                let reasoningFraction = CGFloat(stats.reasoningTokens) / CGFloat(total)

                HStack(spacing: 2) {
                    if stats.inputTokens > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.blue)
                            .frame(width: max(inputFraction * geo.size.width - 2, 4))
                    }
                    if stats.outputTokens > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.green)
                            .frame(width: max(outputFraction * geo.size.width - 2, 4))
                    }
                    if stats.reasoningTokens > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.orange)
                            .frame(width: max(reasoningFraction * geo.size.width - 2, 4))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: stats)
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // Legend
            HStack(spacing: 12) {
                legendDot(color: .blue, label: "Input")
                legendDot(color: .green, label: "Output")
                if stats.reasoningTokens > 0 {
                    legendDot(color: .orange, label: "Reasoning")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Cost Display

    private func costDisplay(stats: SessionStats) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                Text("Estimated Cost")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let cost = stats.estimatedCost {
                    Text(cost, format: .currency(code: "USD").precision(.fractionLength(2...4)))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: cost)
                } else {
                    Text("N/A")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var sessionStats: SessionStats {
        let assistantMessages = session.messages.filter { $0.role == .assistant }
        let userMessages = session.messages.filter { $0.role == .user }

        let inputTokens = assistantMessages.compactMap(\.inputTokens).reduce(0, +)
        let outputTokens = assistantMessages.compactMap(\.outputTokens).reduce(0, +)
        let reasoningTokens = assistantMessages.compactMap(\.reasoningTokens).reduce(0, +)
        let messageCount = userMessages.count + assistantMessages.count

        let profile = providerService.resolvedProfile(for: session, profiles: profiles)
        let model = providerService.resolvedModel(for: session, profiles: profiles)
        let platform = profile?.platform ?? .openAICompatible

        let estimatedCost: Double?
        if inputTokens > 0 || outputTokens > 0,
           let pricing = modelPricingService.price(
               for: model,
               platform: platform,
               modelsDevProviderID: profile?.modelsDevProviderID
           ) {
            estimatedCost = pricing.cost(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                reasoningTokens: reasoningTokens
            )
        } else {
            estimatedCost = nil
        }

        return SessionStats(
            messageCount: messageCount,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            reasoningTokens: reasoningTokens,
            estimatedCost: estimatedCost
        )
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

            // Max Tool Rounds
            LabeledContent(content: {
                TextField(
                    "",
                    value: $session.maxToolRounds,
                    format: .number,
                    prompt: Text("10")
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: session.maxToolRounds) { save() }
            }, label: {
                Text("Max Tool Rounds")
                Text("Tool-calling iterations per response.")
            })
        }
    }

    // MARK: - System Prompt Section

    private var systemPromptSection: some View {
        Section("System Prompt") {
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: systemPromptBinding)
                    .font(.body.monospaced())
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)

                Button {
                    showingPromptGenerator = true
                } label: {
                    Image(systemName: "apple.intelligence")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Generate system prompt")
                .popover(isPresented: $showingPromptGenerator) {
                    promptGeneratorPopover
                }
            }

            if session.systemPrompt != nil {
                Button("Clear") {
                    session.systemPrompt = nil
                    save()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        Section("Tools") {
            // Built-in Tools
            ForEach(BuiltInTool.availableCases) { tool in
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Toggle(
                            tool.displayName,
                            isOn: builtInToolToggleBinding(for: tool)
                        )

                        Spacer()

                        let isEnabledForSession = session.enabledBuiltInToolIDs?.contains(tool.rawValue) ?? false
                        if isEnabledForSession, builtInToolService.isEnabled(tool) {
                            builtInToolPermissionPicker(for: tool)
                        }
                    }
                }
            }

            // MCP Servers
            let enabledServers = mcpServerConfigs.filter(\.isEnabled)

            if !enabledServers.isEmpty {
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

    private func builtInToolToggleBinding(for tool: BuiltInTool) -> Binding<Bool> {
        Binding(
            get: {
                session.enabledBuiltInToolIDs?.contains(tool.rawValue) ?? false
            },
            set: { isEnabled in
                var ids = session.enabledBuiltInToolIDs ?? []
                if isEnabled {
                    if !ids.contains(tool.rawValue) { ids.append(tool.rawValue) }
                } else {
                    ids.removeAll { $0 == tool.rawValue }
                    // Clear any per-tool permission override
                    session.setToolPermission(nil, for: tool.rawValue, serverDefault: builtInToolService.defaultPermission(for: tool))
                }
                session.enabledBuiltInToolIDs = ids.isEmpty ? nil : ids
                save()
            }
        )
    }

    private func builtInToolPermissionPicker(for tool: BuiltInTool) -> some View {
        let globalDefault = builtInToolService.defaultPermission(for: tool)
        let effective = session.effectivePermission(for: tool.rawValue, serverDefault: globalDefault)

        return Picker("", selection: Binding(
            get: { effective },
            set: { newValue in
                session.setToolPermission(newValue, for: tool.rawValue, serverDefault: globalDefault)
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

    // MARK: - System Prompt Generation

    private var promptGeneratorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate System Prompt")
                .font(.headline)

            TextField(
                "A coding assistant that specializes in Swift.",
                text: $agentDescription,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                if isGeneratingPrompt {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Generate") {
                    generateSystemPrompt()
                }
                .disabled(
                    agentDescription.trimmingCharacters(in: .whitespaces).isEmpty
                        || isGeneratingPrompt
                )
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func generateSystemPrompt() {
        isGeneratingPrompt = true
        Task {
            let prompt = await TextGenerationService.generateSystemPrompt(
                from: agentDescription
            )
            session.systemPrompt = prompt
            save()
            isGeneratingPrompt = false
            showingPromptGenerator = false
            agentDescription = ""
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

// MARK: - Session Stats

private struct SessionStats: Equatable {
    let messageCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
    let estimatedCost: Double?

    var totalTokens: Int { inputTokens + outputTokens + reasoningTokens }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatInspectorView(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 700)
}
