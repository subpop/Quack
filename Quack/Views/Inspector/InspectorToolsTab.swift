// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData
import QuackInterface

/// Displays built-in tool toggles and MCP server connections with per-tool permission pickers.
struct InspectorToolsTab: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.mcpService) private var mcpService
    @Environment(\.builtInToolService) private var builtInToolService
    @Query private var mcpServerConfigs: [MCPServerConfig]

    var body: some View {
        Form {
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
        .formStyle(.grouped)
    }

    // MARK: - MCP Status Indicator

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

    // MARK: - Bindings

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

    // MARK: - Permission Pickers

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

    // MARK: - Permission Helpers

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

    InspectorToolsTab(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 500)
}
