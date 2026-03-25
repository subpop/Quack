import SwiftUI
import SwiftData

struct MCPServerDetailView: View {
    @Bindable var server: MCPServerConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(MCPService.self) private var mcpService

    @State private var newEnvKey = ""
    @State private var newEnvValue = ""
    @State private var argumentsText: String = ""

    var body: some View {
        Form {
            generalSection
            commandSection
            argumentsSection
            environmentSection
            timeoutsSection
            actionsSection
        }
        .formStyle(.grouped)
        .onAppear {
            argumentsText = server.arguments.joined(separator: "\n")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            TextField("Name", text: $server.name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: server.name) { save() }

            Toggle("Enabled", isOn: $server.isEnabled)
                .onChange(of: server.isEnabled) { save() }
        }
    }

    // MARK: - Command

    private var commandSection: some View {
        Section("Command") {
            HStack {
                TextField("Command path (e.g., /usr/local/bin/mcp-server)", text: $server.command)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .onChange(of: server.command) { save() }

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        server.command = url.path
                        save()
                    }
                }
            }

            HStack {
                Text("Working Directory")
                Spacer()
                TextField(
                    "Inherit from parent",
                    text: Binding(
                        get: { server.workingDirectory ?? "" },
                        set: { server.workingDirectory = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onChange(of: server.workingDirectory) { save() }

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        server.workingDirectory = url.path
                        save()
                    }
                }
            }
        }
    }

    // MARK: - Arguments

    private var argumentsSection: some View {
        Section("Arguments") {
            TextEditor(text: $argumentsText)
                .font(.body.monospaced())
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .onChange(of: argumentsText) {
                    server.arguments = argumentsText
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map(String.init)
                        .filter { !$0.isEmpty }
                    save()
                }

            Text("One argument per line")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Environment Variables

    private var environmentSection: some View {
        Section("Environment Variables") {
            let envVars = server.environmentVariables

            if !envVars.isEmpty {
                ForEach(Array(envVars.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.body.monospaced())
                        Spacer()
                        Text(envVars[key] ?? "")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Button {
                            var vars = server.environmentVariables
                            vars.removeValue(forKey: key)
                            server.environmentVariables = vars
                            save()
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                TextField("KEY", text: $newEnvKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                TextField("VALUE", text: $newEnvValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                Button {
                    guard !newEnvKey.isEmpty else { return }
                    var vars = server.environmentVariables
                    vars[newEnvKey] = newEnvValue
                    server.environmentVariables = vars
                    newEnvKey = ""
                    newEnvValue = ""
                    save()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(newEnvKey.isEmpty)
            }
        }
    }

    // MARK: - Timeouts

    private var timeoutsSection: some View {
        Section("Timeouts") {
            HStack {
                Text("Initialization (seconds)")
                Spacer()
                TextField("30", value: $server.initializationTimeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: server.initializationTimeout) { save() }
            }

            HStack {
                Text("Tool Call (seconds)")
                Spacer()
                TextField("60", value: $server.toolCallTimeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: server.toolCallTimeout) { save() }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            HStack {
                let isConnected = mcpService.connectedServerNames.contains(server.name)
                Circle()
                    .fill(isConnected ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let error = mcpService.connectionErrors[server.name] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    MCPServerDetailView(server: data.mcpServer)
        .previewEnvironment(container: container)
        .frame(width: 500, height: 600)
}
