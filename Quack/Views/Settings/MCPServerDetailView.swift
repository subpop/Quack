import SwiftUI
import SwiftData

struct MCPServerDetailView: View {
    @Bindable var server: MCPServerConfig

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(MCPService.self) private var mcpService

    @State private var newEnvKey = ""
    @State private var newEnvValue = ""
    @State private var argumentsText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name.isEmpty ? "Unnamed Server" : server.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(mcpService.connectedServerNames.contains(server.name) ? .green : .secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(mcpService.connectedServerNames.contains(server.name) ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("Enabled", isOn: $server.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: server.isEnabled) { save() }
            }
            .padding()

            Divider()

            // Content
            Form {
                generalSection
                commandSection
                argumentsSection
                environmentSection
                timeoutsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Footer
            HStack {
                if let error = mcpService.connectionErrors[server.name] {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 560)
        .onAppear {
            argumentsText = server.arguments.joined(separator: "\n")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            TextField("Name", text: $server.name)
                .onChange(of: server.name) { save() }
        }
    }

    // MARK: - Command

    private var commandSection: some View {
        Section("Command") {
            HStack {
                TextField("Command path", text: $server.command, prompt: Text("/usr/local/bin/mcp-server"))
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
                TextField(
                    "Working Directory",
                    text: Binding(
                        get: { server.workingDirectory ?? "" },
                        set: { server.workingDirectory = $0.isEmpty ? nil : $0 }
                    ),
                    prompt: Text("Inherit from parent")
                )
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
        Section {
            TextEditor(text: $argumentsText)
                .font(.callout.monospaced())
                .frame(minHeight: 50, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .onChange(of: argumentsText) {
                    server.arguments = argumentsText
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map(String.init)
                        .filter { !$0.isEmpty }
                    save()
                }
        } header: {
            Text("Arguments")
        } footer: {
            Text("One argument per line.")
        }
    }

    // MARK: - Environment Variables

    private var environmentSection: some View {
        Section("Environment Variables") {
            let envVars = server.environmentVariables

            ForEach(Array(envVars.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.callout.monospaced())
                    Spacer()
                    Text(envVars[key] ?? "")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Button {
                        var vars = server.environmentVariables
                        vars.removeValue(forKey: key)
                        server.environmentVariables = vars
                        save()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack {
                TextField("KEY", text: $newEnvKey)
                    .font(.callout.monospaced())

                TextField("VALUE", text: $newEnvValue)
                    .font(.callout.monospaced())

                Button {
                    guard !newEnvKey.isEmpty else { return }
                    var vars = server.environmentVariables
                    vars[newEnvKey] = newEnvValue
                    server.environmentVariables = vars
                    newEnvKey = ""
                    newEnvValue = ""
                    save()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)
                .disabled(newEnvKey.isEmpty)
            }
        }
    }

    // MARK: - Timeouts

    private var timeoutsSection: some View {
        Section("Timeouts") {
            LabeledContent("Initialization") {
                HStack(spacing: 4) {
                    TextField("30", value: $server.initializationTimeout, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: server.initializationTimeout) { save() }
                    Text("s")
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Tool Call") {
                HStack(spacing: 4) {
                    TextField("60", value: $server.toolCallTimeout, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: server.toolCallTimeout) { save() }
                    Text("s")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    MCPServerDetailView(server: data.mcpServer)
        .previewEnvironment(container: container)
}
