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

/// A helper type for inline-editable environment variable rows.
private struct EnvVariable: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

// MARK: - MCP Server Detail Sheet

struct MCPServerDetailSheet: View {
    @Bindable var server: MCPServerConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MCPService.self) private var mcpService

    @State private var argumentsText: String = ""
    @State private var envVariables: [EnvVariable] = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            sheetForm
            Divider()
            sheetFooter
        }
        .frame(width: 500, height: 560)
        .onAppear {
            argumentsText = server.arguments.joined(separator: " ")
            envVariables = server.environmentVariables
                .sorted(by: { $0.key < $1.key })
                .map { EnvVariable(key: $0.key, value: $0.value) }
        }
        .alert(
            "Delete Server",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteServer()
            }
        } message: {
            Text("Are you sure you want to delete \"\(server.name.isEmpty ? "Unnamed Server" : server.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.indigo.gradient)
                )

            Text(server.name.isEmpty ? "Unnamed Server" : server.name)
                .font(.headline)

            HStack(spacing: 6) {
                switch mcpService.state(for: server.id) {
                case .connected:
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("Connected").font(.subheadline).foregroundStyle(.secondary)
                case .connecting:
                    ProgressView().controlSize(.mini)
                    Text("Connecting...").font(.subheadline).foregroundStyle(.secondary)
                case .error:
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Text("Error").font(.subheadline).foregroundStyle(.red)
                case .disconnected:
                    Circle().fill(.secondary.opacity(0.4)).frame(width: 7, height: 7)
                    Text("Not in use").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Form

    private var sheetForm: some View {
        Form {
            // MARK: - General
            Section {
                TextField("Name", text: $server.name, prompt: Text("My MCP Server"))
                    .onChange(of: server.name) { save() }

                Toggle("Enabled", isOn: $server.isEnabled)
                    .onChange(of: server.isEnabled) { save() }

                Picker("Default Tool Permission", selection: Binding(
                    get: { server.toolPermission },
                    set: { newValue in
                        server.toolPermission = newValue
                        save()
                    }
                )) {
                    ForEach(ToolPermission.allCases, id: \.self) { permission in
                        Text(permission.label).tag(permission)
                    }
                }
                .help(server.toolPermission.description)
            }

            // MARK: - Command
            Section {
                LabeledContent("Command") {
                    TextField("", text: $server.command, prompt: Text("npx, python, node, etc."))
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: server.command) { save() }
                }

                LabeledContent("Arguments") {
                    TextField("", text: $argumentsText, prompt: Text("-y @modelcontextprotocol/server"))
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: argumentsText) {
                            server.arguments = parseArguments(argumentsText)
                            save()
                        }
                }


                LabeledContent("Working Directory") {
                    TextField("",text: Binding(
                            get: { server.workingDirectory ?? "" },
                            set: { server.workingDirectory = $0.isEmpty ? nil : $0 }
                        ),
                        prompt: Text("Inherit from parent")
                    )
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: server.workingDirectory) { save() }
                }
            }

            // MARK: - Environment Variables
            Section("Environment Variables") {
                ForEach($envVariables) { $envVar in
                    HStack {
                        TextField("", text: $envVar.key, prompt: Text("NAME"))
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: envVar.key) { syncEnvToServer() }
                        Text("=")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                        TextField("", text: $envVar.value, prompt: Text("VALUE"))
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: envVar.value) { syncEnvToServer() }

                        Button { removeEnvVariable(envVar) } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button { addEnvVariable() } label: {
                    Label("Add Variable", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            // MARK: - Advanced
            Section("Advanced"){
                LabeledContent("Initialization timeout (seconds)") {
                    TextField("", value: $server.initializationTimeout, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: server.initializationTimeout) { save() }
                }

                LabeledContent("Tool Call timeout(seconds)") {
                    TextField("", value: $server.toolCallTimeout, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: server.toolCallTimeout) { save() }
                }

                // Connection error
                if case .error(let message) = mcpService.state(for: server.id) {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
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

    // MARK: - Environment Variable Helpers

    private func addEnvVariable() {
        envVariables.append(EnvVariable(key: "", value: ""))
    }

    private func removeEnvVariable(_ variable: EnvVariable) {
        envVariables.removeAll { $0.id == variable.id }
        syncEnvToServer()
    }

    private func syncEnvToServer() {
        server.environmentVariables = Dictionary(
            uniqueKeysWithValues: envVariables
                .filter { !$0.key.isEmpty }
                .map { ($0.key, $0.value) }
        )
        save()
    }

    // MARK: - Argument Parsing

    /// Parse arguments string, respecting quoted strings.
    private func parseArguments(_ text: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in text {
            if char == "\"" || char == "'" {
                if inQuotes && char == quoteChar {
                    inQuotes = false
                } else if !inQuotes {
                    inQuotes = true
                    quoteChar = char
                } else {
                    current.append(char)
                }
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    arguments.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            arguments.append(current)
        }

        return arguments
    }

    private func save() {
        try? modelContext.save()
    }

    private func deleteServer() {
        modelContext.delete(server)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Previews

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    MCPServerDetailSheet(server: data.mcpServer)
        .previewEnvironment(container: container)
}
