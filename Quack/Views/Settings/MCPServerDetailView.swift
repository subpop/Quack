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
                let isConnected = mcpService.connectedServerNames.contains(server.name)
                Circle()
                    .fill(isConnected ? .green : .secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                if let error = mcpService.connectionErrors[server.name] {
                    Section {
                        Text(error)
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
}

// MARK: - Previews

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    MCPServerDetailSheet(server: data.mcpServer)
        .previewEnvironment(container: container)
}
