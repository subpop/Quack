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

        let tools = service.tools(for: session)
        #expect(tools.isEmpty)
    }

    @Test("tools(for:) returns empty when session has IDs but no servers connected")
    @MainActor
    func toolsReturnsEmptyWhenNoConnections() {
        let service = MCPService()
        let session = ChatSession(title: "Test Chat")
        session.enabledMCPServerIDs = [UUID()]

        // No servers connected, so toolsByServer is empty
        let tools = service.tools(for: session)
        #expect(tools.isEmpty)
    }

    @Test("tools(forServerIDs:) returns empty for unknown IDs")
    @MainActor
    func toolsForUnknownIDs() {
        let service = MCPService()
        let tools = service.tools(forServerIDs: [UUID(), UUID()])
        #expect(tools.isEmpty)
    }
}
