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

import Foundation
import SwiftData
import AgentRunKit
import QuackInterface

@Observable
@MainActor
public final class MCPService: MCPServiceProtocol {

    // MARK: - Observable State

    /// Per-server connection status: server config ID -> state.
    public private(set) var serverStates: [UUID: MCPServerState] = [:]

    /// Tools discovered from each connected server, keyed by server config ID.
    public private(set) var toolsByServer: [UUID: [any AnyTool<EmptyContext>]] = [:]

    // MARK: - Private State

    /// One long-lived task per server, keyed by config ID.
    private var serverTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Derived Properties

    /// All tools across all connected servers.
    public var availableTools: [any AnyTool<EmptyContext>] {
        toolsByServer.values.flatMap { $0 }
    }

    /// Whether any server is currently connecting.
    public var isConnecting: Bool {
        serverStates.values.contains(.connecting)
    }

    /// Whether at least one server is connected with tools.
    public var isConnected: Bool {
        serverStates.values.contains(.connected) && !toolsByServer.isEmpty
    }

    // MARK: - Server Lifecycle

    /// Synchronize running server connections to match the desired set of server IDs.
    ///
    /// Call this whenever the set of servers that should be running changes.
    /// It will start servers that aren't running and stop servers that should no longer run.
    public func syncServers(desired: Set<UUID>, allConfigs: [MCPServerConfig]) {
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
    public func startServer(config: MCPServerConfig) {
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
    public func stopServer(id: UUID) {
        serverTasks[id]?.cancel()
        serverTasks.removeValue(forKey: id)
        toolsByServer.removeValue(forKey: id)
        serverStates[id] = .disconnected
    }

    /// Disconnect all MCP servers.
    public func disconnectAll() {
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
    public func tools(
        for session: ChatSession,
        allConfigs: [MCPServerConfig],
        onApprovalNeeded: @escaping @Sendable @concurrent (String, String, String) async -> Bool
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
    public func tools(forServerIDs ids: Set<UUID>) -> [any AnyTool<EmptyContext>] {
        ids.flatMap { id in
            toolsByServer[id] ?? []
        }
    }

    // MARK: - Query Helpers

    /// The state of a specific server, or `.disconnected` if unknown.
    public func state(for serverID: UUID) -> MCPServerState {
        serverStates[serverID] ?? .disconnected
    }

    /// The number of tools discovered from a specific server.
    public func toolCount(for serverID: UUID) -> Int {
        toolsByServer[serverID]?.count ?? 0
    }

    /// Summary info for each tool from a specific server.
    public func toolSummaries(for serverID: UUID) -> [MCPToolSummary] {
        (toolsByServer[serverID] ?? []).map { tool in
            MCPToolSummary(name: tool.name, description: tool.description)
        }
    }
}
