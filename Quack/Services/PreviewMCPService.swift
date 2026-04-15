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
import Observation
import QuackInterface
import AgentRunKit

/// A minimal no-op ``MCPServiceProtocol`` implementation for SwiftUI previews.
@Observable
@MainActor
final class PreviewMCPService: MCPServiceProtocol {
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
        onApprovalNeeded: @escaping @Sendable @concurrent (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>] { [] }

    func state(for serverID: UUID) -> MCPServerState { .disconnected }
    func toolCount(for serverID: UUID) -> Int { 0 }
    func toolSummaries(for serverID: UUID) -> [MCPToolSummary] { [] }
}
