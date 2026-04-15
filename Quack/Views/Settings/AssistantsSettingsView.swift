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
import QuackInterface

struct AssistantsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assistant.sortOrder) private var assistants: [Assistant]

    @State private var editingAssistant: Assistant?
    @State private var assistantToDelete: Assistant?

    var body: some View {
        Form {
            Section("Assistants") {
                ForEach(assistants) { assistant in
                    AssistantRow(assistant: assistant)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingAssistant = assistant
                        }
                        .contextMenu {
                            Button("Edit\u{2026}") {
                                editingAssistant = assistant
                            }

                            Divider()

                            if !assistant.isDefault {
                                Button("Set as Default") {
                                    setDefault(assistant)
                                }
                            }

                            Button("Duplicate") {
                                duplicate(assistant)
                            }

                            Divider()

                            Button("Delete\u{2026}", role: .destructive) {
                                assistantToDelete = assistant
                            }
                            .disabled(assistants.count <= 1)
                        }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Add an Assistant\u{2026}") {
                    addAssistant()
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(item: $editingAssistant) { assistant in
            AssistantDetailSheet(assistant: assistant)
        }
        .alert(
            "Delete Assistant",
            isPresented: Binding(
                get: { assistantToDelete != nil },
                set: { if !$0 { assistantToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                assistantToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let assistant = assistantToDelete {
                    delete(assistant)
                }
                assistantToDelete = nil
            }
        } message: {
            if let assistant = assistantToDelete {
                Text("Are you sure you want to delete \"\(assistant.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func addAssistant() {
        let assistant = Assistant(
            name: "New Assistant",
            sortOrder: assistants.count
        )
        modelContext.insert(assistant)
        try? modelContext.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            editingAssistant = assistant
        }
    }

    private func setDefault(_ assistant: Assistant) {
        for a in assistants {
            a.isDefault = (a.id == assistant.id)
        }
        try? modelContext.save()
    }

    private func duplicate(_ assistant: Assistant) {
        let copy = Assistant(
            name: "\(assistant.name) Copy",
            systemPrompt: assistant.systemPrompt,
            sortOrder: assistants.count
        )
        copy.providerIDString = assistant.providerIDString
        copy.modelIdentifier = assistant.modelIdentifier
        copy.temperature = assistant.temperature
        copy.maxTokens = assistant.maxTokens
        copy.reasoningEffort = assistant.reasoningEffort
        copy.compactionThreshold = assistant.compactionThreshold
        copy.maxMessages = assistant.maxMessages
        copy.maxToolRounds = assistant.maxToolRounds
        copy.enabledMCPServerIDsRaw = assistant.enabledMCPServerIDsRaw
        copy.enabledBuiltInToolIDsRaw = assistant.enabledBuiltInToolIDsRaw
        copy.toolPermissionDefaultsJSON = assistant.toolPermissionDefaultsJSON
        copy.iconName = assistant.iconName
        copy.colorRaw = assistant.colorRaw
        modelContext.insert(copy)
        try? modelContext.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            editingAssistant = copy
        }
    }

    private func delete(_ assistant: Assistant) {
        guard assistants.count > 1 else { return }
        let wasDefault = assistant.isDefault
        modelContext.delete(assistant)
        if wasDefault, let first = assistants.first(where: { $0.id != assistant.id }) {
            first.isDefault = true
        }
        try? modelContext.save()
    }
}

// MARK: - Assistant Row

private struct AssistantRow: View {
    let assistant: Assistant

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: assistant.resolvedIcon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(assistant.resolvedColor.gradient)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(assistant.name)
                    .fontWeight(.medium)
                if let prompt = assistant.systemPrompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No system prompt")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if assistant.isDefault {
                Text("Default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Assistant Detail Sheet

struct AssistantDetailSheet: View {
    @Bindable var assistant: Assistant

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mcpService) private var mcpService
    @Environment(\.builtInToolService) private var builtInToolService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    @State private var showingDeleteConfirmation = false
    @State private var showingPromptGenerator = false
    @State private var agentDescription = ""
    @State private var isGeneratingPrompt = false

    /// Server IDs that we started temporarily for tool discovery in this sheet.
    /// When the sheet closes, these will be stopped if no active session needs them.
    @State private var temporarilyStartedServers: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            sheetForm
            Divider()
            sheetFooter
        }
        .frame(width: 500, height: 720)
        .onAppear { startEnabledServers() }
        .onDisappear { stopTemporaryServers() }
        .alert(
            "Delete Assistant",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(assistant)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(assistant.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: assistant.resolvedIcon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(assistant.resolvedColor.gradient)
                )

            Text(assistant.name.isEmpty ? "Untitled" : assistant.name)
                .font(.headline)

            if assistant.isDefault {
                Text("Default Assistant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Form

    private var sheetForm: some View {
        Form {
            // Identity
            Section {
                TextField("Name", text: $assistant.name)
                    .onChange(of: assistant.name) { save() }

                iconPicker
                colorPicker
            }

            // Provider
            Section("Provider") {
                Picker("Provider", selection: providerBinding) {
                    Text("None").tag(nil as UUID?)
                    Divider()
                    ForEach(profiles.filter(\.isEnabled)) { profile in
                        Label {
                            Text(profile.name)
                        } icon: {
                            if profile.iconIsCustom {
                                profile.icon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                profile.icon
                            }
                        }
                        .tag(profile.id as UUID?)
                    }
                }

                if let profile = resolvedProfile {
                    ModelPicker(
                        selection: modelBinding,
                        profile: profile,
                        placeholder: "Default (\(profile.defaultModel))"
                    )
                }
            }

            // System Prompt
            Section {
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: systemPromptBinding)
                        .font(.body.monospaced())
                        .frame(minHeight: 60)
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

                if assistant.systemPrompt != nil {
                    Button("Clear") {
                        assistant.systemPrompt = nil
                        save()
                    }
                    .font(.caption)
                }
            } header: {
                Text("System Prompt")
            }

            // Parameters
            Section("Parameters") {
                LabeledContent(content: {
                    Slider(
                        value: temperatureBinding,
                        in: 0...2,
                        step: 0.1
                    )
                    if assistant.temperature != nil {
                        Button {
                            assistant.temperature = nil
                            save()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Clear default")
                    }
                }, label: {
                    Text("Temperature")
                    Text("Controls randomness of responses.")
                })

                LabeledContent(content: {
                    TextField(
                        "",
                        value: $assistant.maxTokens,
                        format: .number,
                        prompt: Text("Default")
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: assistant.maxTokens) { save() }
                }, label: {
                    Text("Maximum Tokens")
                    Text("Max output length per response.")
                })

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

                LabeledContent(content: {
                    TextField(
                        "",
                        value: $assistant.maxToolRounds,
                        format: .number,
                        prompt: Text("10")
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: assistant.maxToolRounds) { save() }
                }, label: {
                    Text("Max Tool Rounds")
                    Text("Tool-calling iterations per response.")
                })
            }

            // Context Management
            Section("Context Management") {
                LabeledContent(content: {
                    Slider(
                        value: compactionBinding,
                        in: 0.3...0.95,
                        step: 0.05
                    )
                    if assistant.compactionThreshold != nil {
                        Button {
                            assistant.compactionThreshold = nil
                            save()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Clear default")
                    }
                }, label: {
                    Text("Compaction Threshold")
                    Text("When to summarize context.")
                })

                LabeledContent(content: {
                    TextField(
                        "",
                        value: $assistant.maxMessages,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: assistant.maxMessages) { save() }
                }, label: {
                    Text("Maximum Messages")
                    Text("Limit messages sent to the model.")
                })
            }

            // Tools
            Section {
                // Built-in Tools
                ForEach(BuiltInTool.availableCases) { tool in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Toggle(
                                tool.displayName,
                                isOn: builtInToolToggleBinding(for: tool)
                            )

                            Spacer()

                            let isEnabledForAssistant = assistant.enabledBuiltInToolIDs?.contains(tool.rawValue) ?? false
                            if isEnabledForAssistant, builtInToolService.isEnabled(tool) {
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
                            let isEnabledForAssistant = assistant.enabledMCPServerIDs?.contains(server.id) ?? false
                            if isEnabledForAssistant, mcpService.state(for: server.id) == .connected {
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
            } header: {
                Text("Tools")
            } footer: {
                Text("Tools enabled here will be active by default in new chats. Set per-tool permissions to control how tools are executed.")
            }

            // Default
            Section {
                Toggle("Default Assistant", isOn: defaultBinding)
            } footer: {
                Text("New conversations use the default assistant.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Icon Picker

    private var iconPicker: some View {
        LabeledContent("Icon") {
            HStack(spacing: 0) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 10), spacing: 4) {
                    ForEach(Assistant.iconChoices, id: \.self) { name in
                        let isSelected = assistant.resolvedIcon == name
                        Button {
                            assistant.iconName = name
                            save()
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                                .foregroundStyle(isSelected ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(isSelected ? assistant.resolvedColor : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        LabeledContent("Color") {
            HStack(spacing: 4) {
                ForEach(Assistant.colorKeys, id: \.self) { key in
                    let color = Assistant.colorPalette[key]!
                    let isSelected = (assistant.colorRaw ?? "") == key
                    Button {
                        assistant.colorRaw = key
                        save()
                    } label: {
                        Circle()
                            .fill(color.gradient)
                            .frame(width: 18, height: 18)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

    // MARK: - Bindings

    private var resolvedProfile: ProviderProfile? {
        guard let id = assistant.providerID else { return nil }
        return profiles.first { $0.id == id }
    }

    private var defaultBinding: Binding<Bool> {
        Binding(
            get: { assistant.isDefault },
            set: { newValue in
                guard newValue else { return }
                let descriptor = FetchDescriptor<Assistant>()
                if let all = try? modelContext.fetch(descriptor) {
                    for a in all { a.isDefault = false }
                }
                assistant.isDefault = true
                save()
            }
        )
    }

    private var providerBinding: Binding<UUID?> {
        Binding(
            get: { assistant.providerID },
            set: { newValue in
                let oldValue = assistant.providerID
                assistant.providerID = newValue
                if newValue != oldValue {
                    assistant.modelIdentifier = nil
                }
                save()
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { assistant.modelIdentifier ?? "" },
            set: { newValue in
                assistant.modelIdentifier = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private var systemPromptBinding: Binding<String> {
        Binding(
            get: { assistant.systemPrompt ?? "" },
            set: { newValue in
                assistant.systemPrompt = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { assistant.temperature ?? 1.0 },
            set: { newValue in
                assistant.temperature = newValue
                save()
            }
        )
    }

    private var reasoningBinding: Binding<String?> {
        Binding(
            get: { assistant.reasoningEffort },
            set: { newValue in
                assistant.reasoningEffort = newValue
                save()
            }
        )
    }

    private var compactionBinding: Binding<Double> {
        Binding(
            get: { assistant.compactionThreshold ?? 0.7 },
            set: { newValue in
                assistant.compactionThreshold = newValue
                save()
            }
        )
    }

    private func builtInToolToggleBinding(for tool: BuiltInTool) -> Binding<Bool> {
        Binding(
            get: {
                assistant.enabledBuiltInToolIDs?.contains(tool.rawValue) ?? false
            },
            set: { isEnabled in
                var ids = assistant.enabledBuiltInToolIDs ?? []
                if isEnabled {
                    if !ids.contains(tool.rawValue) { ids.append(tool.rawValue) }
                } else {
                    ids.removeAll { $0 == tool.rawValue }
                    // Clear any per-tool permission default
                    assistant.setToolPermission(nil, for: tool.rawValue, serverDefault: builtInToolService.defaultPermission(for: tool))
                }
                assistant.enabledBuiltInToolIDs = ids.isEmpty ? nil : ids
                save()
            }
        )
    }

    private func builtInToolPermissionPicker(for tool: BuiltInTool) -> some View {
        let globalDefault = builtInToolService.defaultPermission(for: tool)
        let effective = assistant.effectivePermission(for: tool.rawValue, serverDefault: globalDefault)

        return Picker("", selection: Binding(
            get: { effective },
            set: { newValue in
                assistant.setToolPermission(newValue, for: tool.rawValue, serverDefault: globalDefault)
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
                assistant.enabledMCPServerIDs?.contains(server.id) ?? false
            },
            set: { isEnabled in
                var ids = assistant.enabledMCPServerIDs ?? []
                if isEnabled {
                    if !ids.contains(server.id) { ids.append(server.id) }
                    // Start the server so tools can be discovered
                    if mcpService.state(for: server.id) == .disconnected {
                        mcpService.startServer(config: server)
                        temporarilyStartedServers.insert(server.id)
                    }
                } else {
                    ids.removeAll { $0 == server.id }
                    // Clear any per-tool permission defaults for this server's tools
                    clearToolPermissions(for: server)
                    // Stop the server if we started it temporarily
                    if temporarilyStartedServers.contains(server.id) {
                        mcpService.stopServer(id: server.id)
                        temporarilyStartedServers.remove(server.id)
                    }
                }
                assistant.enabledMCPServerIDs = ids.isEmpty ? nil : ids
                save()
            }
        )
    }

    // MARK: - Tool Permission Helpers

    private func toolPermissionPicker(for toolName: String, serverDefault: ToolPermission) -> some View {
        let effective = assistant.effectivePermission(for: toolName, serverDefault: serverDefault)

        return Picker("", selection: Binding(
            get: { effective },
            set: { newValue in
                assistant.setToolPermission(newValue, for: toolName, serverDefault: serverDefault)
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

    @ViewBuilder
    private func mcpStatusIndicator(for server: MCPServerConfig) -> some View {
        let isEnabledForAssistant = assistant.enabledMCPServerIDs?.contains(server.id) ?? false

        if !isEnabledForAssistant {
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

    // MARK: - MCP Server Lifecycle

    /// Start servers that are enabled for this assistant so we can discover their tools.
    private func startEnabledServers() {
        guard let enabledIDs = assistant.enabledMCPServerIDs else { return }
        for id in enabledIDs {
            if mcpService.state(for: id) == .disconnected,
               let config = mcpServerConfigs.first(where: { $0.id == id && $0.isEnabled }) {
                mcpService.startServer(config: config)
                temporarilyStartedServers.insert(id)
            }
        }
    }

    /// Stop servers that we started temporarily for tool discovery.
    private func stopTemporaryServers() {
        for id in temporarilyStartedServers {
            mcpService.stopServer(id: id)
        }
        temporarilyStartedServers.removeAll()
    }

    /// Clear tool permission defaults for all tools belonging to a server.
    private func clearToolPermissions(for server: MCPServerConfig) {
        let tools = mcpService.toolSummaries(for: server.id)
        guard !tools.isEmpty, var defaults = assistant.toolPermissionDefaults else { return }
        for tool in tools {
            defaults.removeValue(forKey: tool.name)
        }
        assistant.toolPermissionDefaults = defaults.isEmpty ? nil : defaults
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
            assistant.systemPrompt = prompt
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

// MARK: - Previews

#Preview("Assistant List") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    AssistantsSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}

#Preview("Assistant Detail") {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    AssistantDetailSheet(assistant: data.assistants[0])
        .previewEnvironment(container: container)
}
