import SwiftUI
import SwiftData

struct MCPSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MCPService.self) private var mcpService
    @Query private var servers: [MCPServerConfig]

    @State private var editingServer: MCPServerConfig?

    var body: some View {
        Form {
            Section {
                if servers.isEmpty {
                    ContentUnavailableView(
                        "No MCP Servers",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Add an MCP server to enable tool calling.")
                    )
                } else {
                    ForEach(servers) { server in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(mcpService.connectedServerNames.contains(server.name) ? .green : .secondary.opacity(0.4))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name.isEmpty ? "Unnamed Server" : server.name)

                                Text(server.command.isEmpty ? "No command configured" : server.command)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if !server.isEnabled {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingServer = server
                        }
                    }
                    .onDelete(perform: deleteServers)
                }
            } header: {
                Text("Servers")
            } footer: {
                Text("Click a server to configure it. Swipe to delete.")
            }

            Section {
                Button {
                    addServer()
                } label: {
                    Label("Add Server...", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .sheet(item: $editingServer) { server in
            MCPServerDetailView(server: server)
        }
    }

    // MARK: - Actions

    private func addServer() {
        let server = MCPServerConfig(name: "New Server")
        modelContext.insert(server)
        try? modelContext.save()
        editingServer = server
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(servers[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    MCPSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}
