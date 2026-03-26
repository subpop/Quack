import Foundation
import SwiftData
import AgentRunKit

@Observable
@MainActor
final class MCPService {

    // MARK: - Observable State

    /// Per-server connection status: server config ID -> state.
    private(set) var serverStates: [UUID: ServerState] = [:]

    /// Tools discovered from each connected server, keyed by server config ID.
    private(set) var toolsByServer: [UUID: [any AnyTool<EmptyContext>]] = [:]

    // MARK: - Types

    enum ServerState: Equatable {
        case connecting
        case connected
        case error(String)
        case disconnected
    }

    // MARK: - Private State

    /// One long-lived task per server, keyed by config ID.
    private var serverTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Derived Properties

    /// All tools across all connected servers.
    var availableTools: [any AnyTool<EmptyContext>] {
        toolsByServer.values.flatMap { $0 }
    }

    /// Whether any server is currently connecting.
    var isConnecting: Bool {
        serverStates.values.contains(.connecting)
    }

    /// Whether at least one server is connected with tools.
    var isConnected: Bool {
        serverStates.values.contains(.connected) && !toolsByServer.isEmpty
    }

    // MARK: - Server Lifecycle

    /// Synchronize running server connections to match the desired set of server IDs.
    ///
    /// Call this whenever the set of servers that should be running changes.
    /// It will start servers that aren't running and stop servers that should no longer run.
    func syncServers(desired: Set<UUID>, allConfigs: [MCPServerConfig]) {
        let running = Set(serverTasks.keys)

        // Stop servers that are no longer desired
        for id in running.subtracting(desired) {
            stopServer(id: id)
        }

        // Start servers that are desired but not running
        for id in desired.subtracting(running) {
            if let config = allConfigs.first(where: { $0.id == id }) {
                startServer(config: config)
            }
        }
    }

    /// Start a single MCP server connection.
    func startServer(config: MCPServerConfig) {
        // Don't start if already running
        guard serverTasks[config.id] == nil else { return }

        serverStates[config.id] = .connecting

        let serverID = config.id
        let mcpConfig = MCPServerConfiguration(
            name: config.name,
            command: config.command,
            arguments: config.arguments,
            environment: config.environmentVariables.isEmpty ? nil : config.environmentVariables,
            workingDirectory: config.workingDirectory,
            initializationTimeout: .seconds(Int64(config.initializationTimeout)),
            toolCallTimeout: .seconds(Int64(config.toolCallTimeout))
        )

        let session = MCPSession(configurations: [mcpConfig])

        serverTasks[serverID] = Task { [weak self] in
            do {
                try await session.withTools { (tools: [any AnyTool<EmptyContext>]) in
                    await MainActor.run {
                        self?.toolsByServer[serverID] = tools
                        self?.serverStates[serverID] = .connected
                    }

                    // Keep the session alive until cancelled
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(1))
                    }
                }
            } catch is CancellationError {
                // Normal shutdown, don't report as error
            } catch {
                await MainActor.run {
                    self?.serverStates[serverID] = .error(error.localizedDescription)
                }
            }

            // Clean up on exit
            await MainActor.run {
                self?.toolsByServer.removeValue(forKey: serverID)
                if self?.serverStates[serverID] == .connected || self?.serverStates[serverID] == .connecting {
                    self?.serverStates[serverID] = .disconnected
                }
            }
        }
    }

    /// Stop a single MCP server connection.
    func stopServer(id: UUID) {
        serverTasks[id]?.cancel()
        serverTasks.removeValue(forKey: id)
        toolsByServer.removeValue(forKey: id)
        serverStates[id] = .disconnected
    }

    /// Disconnect all MCP servers.
    func disconnectAll() {
        for (id, task) in serverTasks {
            task.cancel()
            serverStates[id] = .disconnected
        }
        serverTasks.removeAll()
        toolsByServer.removeAll()
    }

    // MARK: - Per-Session Tool Filtering

    /// Get tools for a specific chat session, filtered by the session's enabled MCP servers
    /// and wrapped with permission enforcement.
    ///
    /// Each tool's effective permission is resolved by checking for a per-session per-tool
    /// override first, then falling back to the server-level default.
    ///
    /// - Parameter session: The chat session, used to check enabled servers and per-tool overrides.
    /// - Parameter allConfigs: All MCP server configs, used to look up server-level permission defaults.
    /// - Parameter onApprovalNeeded: Called when a tool with `.ask` permission needs user approval.
    ///   Receives (toolName, arguments, description) and returns true if approved.
    func tools(
        for session: ChatSession,
        allConfigs: [MCPServerConfig],
        onApprovalNeeded: @escaping @Sendable (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>] {
        guard let enabledIDs = session.enabledMCPServerIDs else {
            return []
        }

        return enabledIDs.flatMap { serverID -> [any AnyTool<EmptyContext>] in
            let tools = toolsByServer[serverID] ?? []
            let serverDefault = allConfigs.first(where: { $0.id == serverID })?.toolPermission ?? .ask

            return tools.map { tool in
                let effectivePermission = session.effectivePermission(
                    for: tool.name,
                    serverDefault: serverDefault
                )
                return PermissionToolWrapper(
                    wrapped: tool,
                    permission: effectivePermission,
                    onApprovalNeeded: onApprovalNeeded
                ) as any AnyTool<EmptyContext>
            }
        }
    }

    /// Returns tools for a set of server IDs (without permission wrapping, for internal use).
    func tools(forServerIDs ids: Set<UUID>) -> [any AnyTool<EmptyContext>] {
        ids.flatMap { id in
            toolsByServer[id] ?? []
        }
    }

    // MARK: - Query Helpers

    /// The state of a specific server, or `.disconnected` if unknown.
    func state(for serverID: UUID) -> ServerState {
        serverStates[serverID] ?? .disconnected
    }

    /// The number of tools discovered from a specific server.
    func toolCount(for serverID: UUID) -> Int {
        toolsByServer[serverID]?.count ?? 0
    }

    /// Summary info for each tool from a specific server.
    func toolSummaries(for serverID: UUID) -> [ToolSummary] {
        (toolsByServer[serverID] ?? []).map { tool in
            ToolSummary(name: tool.name, description: tool.description)
        }
    }

    /// Lightweight description of a discovered tool.
    struct ToolSummary: Identifiable {
        let name: String
        let description: String
        var id: String { name }
    }
}
