import Foundation
import SwiftData
import AgentRunKit

@Observable
@MainActor
final class MCPService {
    var connectedServerNames: Set<String> = []
    var connectionErrors: [String: String] = [:]
    var availableTools: [any AnyTool<EmptyContext>] = []

    private var activeSession: MCPSession?
    private var connectionTask: Task<Void, Never>?

    /// Connect to all enabled MCP servers and discover their tools.
    func connect(configs: [MCPServerConfig]) {
        disconnect()

        let enabledConfigs = configs.filter(\.isEnabled)
        guard !enabledConfigs.isEmpty else { return }

        let mcpConfigs = enabledConfigs.map { config in
            MCPServerConfiguration(
                name: config.name,
                command: config.command,
                arguments: config.arguments,
                environment: config.environmentVariables.isEmpty ? nil : config.environmentVariables,
                workingDirectory: config.workingDirectory,
                initializationTimeout: .seconds(Int64(config.initializationTimeout)),
                toolCallTimeout: .seconds(Int64(config.toolCallTimeout))
            )
        }

        let session = MCPSession(configurations: mcpConfigs)
        activeSession = session

        let serverNames = Set(enabledConfigs.map(\.name))

        connectionTask = Task { [weak self] in
            do {
                // withTools is scoped — we need to keep the session alive
                // For a long-running app, we'll use a long-lived task
                try await session.withTools { (tools: [any AnyTool<EmptyContext>]) in
                    await MainActor.run {
                        self?.availableTools = tools
                        self?.connectedServerNames = serverNames
                        self?.connectionErrors = [:]
                    }

                    // Keep the session alive until cancelled
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(1))
                    }
                }
            } catch {
                await MainActor.run {
                    self?.connectionErrors["general"] = error.localizedDescription
                }
            }
        }
    }

    /// Disconnect all MCP servers.
    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        activeSession = nil
        connectedServerNames = []
        connectionErrors = [:]
        availableTools = []
    }

    /// Get tools filtered by the session's enabled MCP server IDs.
    func tools(for session: ChatSession, allConfigs: [MCPServerConfig]) -> [any AnyTool<EmptyContext>] {
        guard session.enabledMCPServerIDs != nil else {
            // If nil, use all available tools
            return availableTools
        }

        // MCP tools don't expose their server origin at the AnyTool level,
        // so we return all available tools regardless of per-session filtering.
        return availableTools
    }
}
