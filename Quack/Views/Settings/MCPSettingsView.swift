import SwiftUI
import SwiftData

struct MCPSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MCPService.self) private var mcpService
    @Query private var servers: [MCPServerConfig]

    @State private var editingServer: MCPServerConfig?
    @State private var serverToDelete: MCPServerConfig?
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section("Servers") {
                ForEach(servers) { server in
                    MCPServerRow(
                        server: server,
                        serverState: mcpService.state(for: server.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingServer = server
                    }
                    .contextMenu {
                        Button("Edit\u{2026}") {
                            editingServer = server
                        }

                        Divider()

                        Toggle("Enabled", isOn: Binding(
                            get: { server.isEnabled },
                            set: { newValue in
                                server.isEnabled = newValue
                                try? modelContext.save()
                            }
                        ))

                        Divider()

                        Button("Delete\u{2026}", role: .destructive) {
                            serverToDelete = server
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Add a Server\u{2026}") {
                    showingAddSheet = true
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(item: $editingServer) { server in
            MCPServerDetailSheet(server: server)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMCPServerSheet { server in
                editingServer = server
            }
        }
        .alert(
            "Delete Server",
            isPresented: Binding(
                get: { serverToDelete != nil },
                set: { if !$0 { serverToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                serverToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let server = serverToDelete {
                    modelContext.delete(server)
                    try? modelContext.save()
                }
                serverToDelete = nil
            }
        } message: {
            if let server = serverToDelete {
                Text("Are you sure you want to delete \"\(server.name.isEmpty ? "Unnamed Server" : server.name)\"? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Server Row

private struct MCPServerRow: View {
    let server: MCPServerConfig
    let serverState: MCPService.ServerState

    var body: some View {
        HStack(spacing: 12) {
            // Rounded-square icon
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.indigo.gradient)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name.isEmpty ? "Unnamed Server" : server.name)
                    .fontWeight(.medium)
                Text(server.command.isEmpty ? "No command configured" : server.command)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !server.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                switch serverState {
                case .connected:
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                case .connecting:
                    ProgressView()
                        .controlSize(.mini)
                case .error:
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                case .disconnected:
                    Circle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Server Sheet

private struct AddMCPServerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onAdd: (MCPServerConfig) -> Void

    @State private var name: String = ""
    @State private var command: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.indigo.gradient)
                    )

                Text("Add a Server")
                    .font(.headline)
                Text("Enter the information for the MCP server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Form
            Form {
                TextField("Name", text: $name, prompt: Text("My MCP Server"))

                TextField("Command", text: $command, prompt: Text("npx, python, node, etc."))
                    .font(.system(.body, design: .monospaced))
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addServer()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty && command.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 300)
    }

    private func addServer() {
        let server = MCPServerConfig(
            name: name.isEmpty ? "New Server" : name,
            command: command
        )
        modelContext.insert(server)
        try? modelContext.save()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onAdd(server)
        }
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    MCPSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}
