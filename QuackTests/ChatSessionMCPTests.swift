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

import Testing
import Foundation
@testable import Quack

/// Tests for ChatSession's per-session MCP server ID management.
/// Servers are globally available via Settings, but enabled on a per-session basis.
@Suite("ChatSession MCP Integration")
struct ChatSessionMCPTests {

    // MARK: - enabledMCPServerIDs defaults

    @Test("New session has nil enabledMCPServerIDs (no servers enabled)")
    @MainActor
    func newSessionDefaultsToNoServers() {
        let session = ChatSession(title: "Test Chat")

        #expect(session.enabledMCPServerIDs == nil)
        #expect(session.enabledMCPServerIDsRaw == nil)
    }

    // MARK: - Setting and getting IDs

    @Test("Setting enabledMCPServerIDs persists as comma-separated string")
    @MainActor
    func setEnabledIDs() {
        let session = ChatSession(title: "Test Chat")
        let id1 = UUID()
        let id2 = UUID()

        session.enabledMCPServerIDs = [id1, id2]

        #expect(session.enabledMCPServerIDsRaw != nil)
        let raw = session.enabledMCPServerIDsRaw!
        #expect(raw.contains(id1.uuidString))
        #expect(raw.contains(id2.uuidString))
    }

    @Test("Getting enabledMCPServerIDs roundtrips correctly")
    @MainActor
    func roundtripEnabledIDs() {
        let session = ChatSession(title: "Test Chat")
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        session.enabledMCPServerIDs = [id1, id2, id3]
        let result = session.enabledMCPServerIDs!

        #expect(result.count == 3)
        #expect(result.contains(id1))
        #expect(result.contains(id2))
        #expect(result.contains(id3))
    }

    @Test("Setting enabledMCPServerIDs to nil clears all servers")
    @MainActor
    func clearEnabledIDs() {
        let session = ChatSession(title: "Test Chat")
        session.enabledMCPServerIDs = [UUID()]

        session.enabledMCPServerIDs = nil
        #expect(session.enabledMCPServerIDs == nil)
    }

    @Test("Setting enabledMCPServerIDs to empty array returns nil on get")
    @MainActor
    func emptyArrayReturnsNil() {
        let session = ChatSession(title: "Test Chat")
        session.enabledMCPServerIDs = []

        // Empty string should be treated as nil
        #expect(session.enabledMCPServerIDs == nil)
    }

    // MARK: - Adding / removing individual servers

    @Test("Adding a server ID to an existing list")
    @MainActor
    func addServerID() {
        let session = ChatSession(title: "Test Chat")
        let serverID = UUID()
        let otherID = UUID()

        session.enabledMCPServerIDs = [otherID]

        var ids = session.enabledMCPServerIDs ?? []
        ids.append(serverID)
        session.enabledMCPServerIDs = ids

        #expect(session.enabledMCPServerIDs!.contains(serverID))
        #expect(session.enabledMCPServerIDs!.contains(otherID))
    }

    @Test("Removing a server ID from the list")
    @MainActor
    func removeServerID() {
        let session = ChatSession(title: "Test Chat")
        let serverID = UUID()
        let otherID = UUID()

        session.enabledMCPServerIDs = [serverID, otherID]

        var ids = session.enabledMCPServerIDs ?? []
        ids.removeAll { $0 == serverID }
        session.enabledMCPServerIDs = ids

        #expect(!session.enabledMCPServerIDs!.contains(serverID))
        #expect(session.enabledMCPServerIDs!.contains(otherID))
    }

    // MARK: - MCPService.tools(for:) per-session filtering

    @Test("tools(for:) returns empty when session has nil enabledMCPServerIDs")
    @MainActor
    func toolsReturnsEmptyWhenNilIDs() {
        let service = MCPService()
        let session = ChatSession(title: "Test Chat")
        // session.enabledMCPServerIDs is nil — means no servers enabled

        let tools = service.tools(
            for: session,
            allConfigs: [],
            onApprovalNeeded: { _, _, _ in true }
        )
        #expect(tools.isEmpty)
    }

    @Test("tools(for:) returns empty when session has IDs but no servers connected")
    @MainActor
    func toolsReturnsEmptyWhenNoConnections() {
        let service = MCPService()
        let session = ChatSession(title: "Test Chat")
        session.enabledMCPServerIDs = [UUID()]

        // No servers connected, so toolsByServer is empty
        let tools = service.tools(
            for: session,
            allConfigs: [],
            onApprovalNeeded: { _, _, _ in true }
        )
        #expect(tools.isEmpty)
    }

    @Test("tools(forServerIDs:) returns empty for unknown IDs")
    @MainActor
    func toolsForUnknownIDs() {
        let service = MCPService()
        let tools = service.tools(forServerIDs: [UUID(), UUID()])
        #expect(tools.isEmpty)
    }

    // MARK: - Assistant tool permission defaults

    @Test("Assistant toolPermissionDefaults roundtrips correctly")
    @MainActor
    func assistantToolPermissionDefaultsRoundtrip() {
        let assistant = Assistant(name: "Test")

        #expect(assistant.toolPermissionDefaults == nil)
        #expect(assistant.toolPermissionDefaultsJSON == nil)

        assistant.toolPermissionDefaults = [
            "read_file": .always,
            "write_file": .deny,
            "search": .ask,
        ]

        let result = assistant.toolPermissionDefaults!
        #expect(result.count == 3)
        #expect(result["read_file"] == .always)
        #expect(result["write_file"] == .deny)
        #expect(result["search"] == .ask)
    }

    @Test("Assistant toolPermissionDefaults clears when set to empty")
    @MainActor
    func assistantToolPermissionDefaultsClear() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = ["read_file": .always]
        #expect(assistant.toolPermissionDefaults != nil)

        assistant.toolPermissionDefaults = [:]
        #expect(assistant.toolPermissionDefaults == nil)
        #expect(assistant.toolPermissionDefaultsJSON == nil)
    }

    @Test("Assistant effectivePermission checks defaults then falls back to server default")
    @MainActor
    func assistantEffectivePermission() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = ["read_file": .always]

        // Tool with an assistant-level override
        #expect(assistant.effectivePermission(for: "read_file", serverDefault: .ask) == .always)

        // Tool without an override falls back to server default
        #expect(assistant.effectivePermission(for: "write_file", serverDefault: .deny) == .deny)
    }

    @Test("Assistant setToolPermission removes override when matching server default")
    @MainActor
    func assistantSetToolPermissionCleansUp() {
        let assistant = Assistant(name: "Test")
        assistant.setToolPermission(.always, for: "read_file", serverDefault: .ask)
        #expect(assistant.toolPermissionDefaults?["read_file"] == .always)

        // Setting to the server default should remove the override
        assistant.setToolPermission(.ask, for: "read_file", serverDefault: .ask)
        #expect(assistant.toolPermissionDefaults == nil)
    }

    // MARK: - Session inherits assistant tool permission defaults

    @Test("ChatSession.init(assistant:) copies toolPermissionDefaultsJSON")
    @MainActor
    func sessionInheritsToolPermissionDefaults() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = [
            "read_file": .always,
            "write_file": .deny,
        ]

        let session = ChatSession(assistant: assistant)

        #expect(session.toolPermissionOverridesJSON == assistant.toolPermissionDefaultsJSON)
        let overrides = session.toolPermissionOverrides!
        #expect(overrides["read_file"] == .always)
        #expect(overrides["write_file"] == .deny)
    }

    @Test("ChatSession.init(assistant:) with nil defaults results in nil overrides")
    @MainActor
    func sessionInheritsNilToolPermissionDefaults() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.toolPermissionDefaultsJSON == nil)

        let session = ChatSession(assistant: assistant)
        #expect(session.toolPermissionOverridesJSON == nil)
        #expect(session.toolPermissionOverrides == nil)
    }

    @Test("Session can override inherited assistant defaults independently")
    @MainActor
    func sessionOverridesInheritedDefaults() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = [
            "read_file": .always,
            "write_file": .deny,
        ]

        let session = ChatSession(assistant: assistant)

        // Override one tool in the session
        session.setToolPermission(.ask, for: "read_file", serverDefault: .ask)

        // read_file is now .ask (session override), write_file is still .deny (inherited)
        #expect(session.effectivePermission(for: "read_file", serverDefault: .ask) == .ask)
        #expect(session.effectivePermission(for: "write_file", serverDefault: .ask) == .deny)

        // Assistant is unchanged
        #expect(assistant.effectivePermission(for: "read_file", serverDefault: .ask) == .always)
    }
}
