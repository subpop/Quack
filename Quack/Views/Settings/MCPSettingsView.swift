import SwiftUI
import SwiftData

struct MCPSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MCPService.self) private var mcpService
    @Query private var servers: [MCPServerConfig]

    @State private var selectedServerID: UUID?

    private var selectedServer: MCPServerConfig? {
        servers.first { $0.id == selectedServerID }
    }

    var body: some View {
        HSplitView {
            serverList
                .frame(minWidth: 180, maxWidth: 220, maxHeight: .infinity)

            Group {
                if let server = selectedServer {
                    MCPServerDetailView(server: server)
                } else {
                    ContentUnavailableView(
                        "Select a Server",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Add or select an MCP server to configure it.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var serverList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedServerID) {
                ForEach(servers) { server in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(server.name.isEmpty ? "Unnamed Server" : server.name)
                                .font(.headline)
                            Text(server.command.isEmpty ? "No command" : server.command)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Circle()
                            .fill(mcpService.connectedServerNames.contains(server.name) ? .green : .secondary)
                            .frame(width: 8, height: 8)
                    }
                    .tag(server.id)
                }
            }

            Divider()

            HStack {
                Button {
                    addServer()
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    removeSelectedServer()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedServer == nil)

                Spacer()
            }
            .padding(8)
            .buttonStyle(.borderless)
        }
    }

    private func addServer() {
        let server = MCPServerConfig(name: "New Server")
        modelContext.insert(server)
        try? modelContext.save()
        selectedServerID = server.id
    }

    private func removeSelectedServer() {
        guard let server = selectedServer else { return }
        selectedServerID = nil
        modelContext.delete(server)
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    MCPSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 650, height: 450)
}
