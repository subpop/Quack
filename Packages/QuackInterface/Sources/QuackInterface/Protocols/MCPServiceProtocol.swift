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
import SwiftUI
import AgentRunKit

// MARK: - Promoted Types

/// Connection state for an MCP server.
public enum MCPServerState: Equatable, Sendable {
    case connecting
    case connected
    case error(String)
    case disconnected
}

/// Lightweight description of a discovered MCP tool.
public struct MCPToolSummary: Identifiable, Sendable {
    public let name: String
    public let description: String
    public var id: String { name }

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

// MARK: - Protocol

@MainActor
public protocol MCPServiceProtocol: AnyObject, Observable {
    /// Per-server connection status: server config ID -> state.
    var serverStates: [UUID: MCPServerState] { get }

    /// All tools across all connected servers.
    var availableTools: [any AnyTool<EmptyContext>] { get }

    /// Whether any server is currently connecting.
    var isConnecting: Bool { get }

    /// Whether at least one server is connected with tools.
    var isConnected: Bool { get }

    /// Synchronize running server connections to match the desired set of server IDs.
    func syncServers(desired: Set<UUID>, allConfigs: [MCPServerConfig])

    /// Start a single MCP server connection.
    func startServer(config: MCPServerConfig)

    /// Stop a single MCP server connection.
    func stopServer(id: UUID)

    /// Disconnect all MCP servers.
    func disconnectAll()

    /// Get tools for a specific chat session, filtered by the session's enabled MCP servers
    /// and wrapped with permission enforcement.
    func tools(
        for session: ChatSession,
        allConfigs: [MCPServerConfig],
        onApprovalNeeded: @escaping @Sendable (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>]

    /// The state of a specific server, or `.disconnected` if unknown.
    func state(for serverID: UUID) -> MCPServerState

    /// The number of tools discovered from a specific server.
    func toolCount(for serverID: UUID) -> Int

    /// Summary info for each tool from a specific server.
    func toolSummaries(for serverID: UUID) -> [MCPToolSummary]
}

// MARK: - Environment Key

private struct MCPServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any MCPServiceProtocol = PlaceholderMCPService()
}

public extension EnvironmentValues {
    var mcpService: any MCPServiceProtocol {
        get { self[MCPServiceKey.self] }
        set { self[MCPServiceKey.self] = newValue }
    }
}

// MARK: - Placeholder

@Observable
@MainActor
private final class PlaceholderMCPService: MCPServiceProtocol {
    var serverStates: [UUID: MCPServerState] = [:]
    var availableTools: [any AnyTool<EmptyContext>] = []
    var isConnecting: Bool = false
    var isConnected: Bool = false

    func syncServers(desired: Set<UUID>, allConfigs: [MCPServerConfig]) {}
    func startServer(config: MCPServerConfig) {}
    func stopServer(id: UUID) {}
    func disconnectAll() {}

    func tools(
        for session: ChatSession,
        allConfigs: [MCPServerConfig],
        onApprovalNeeded: @escaping @Sendable (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>] { [] }

    func state(for serverID: UUID) -> MCPServerState { .disconnected }
    func toolCount(for serverID: UUID) -> Int { 0 }
    func toolSummaries(for serverID: UUID) -> [MCPToolSummary] { [] }
}
