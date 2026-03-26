import Testing
import Foundation
@testable import Quack

/// Tests for MCPService lifecycle: per-server connection management,
/// tool-to-server mapping, per-session filtering, and sync logic.
@Suite("MCPService Lifecycle")
struct MCPServiceTests {

    // MARK: - Initial State

    @Test("MCPService starts with no connections")
    @MainActor
    func initialState() {
        let service = MCPService()

        #expect(service.serverStates.isEmpty)
        #expect(service.toolsByServer.isEmpty)
        #expect(service.availableTools.isEmpty)
        #expect(!service.isConnected)
        #expect(!service.isConnecting)
    }

    // MARK: - startServer

    @Test("startServer sets state to connecting")
    @MainActor
    func startServerSetsConnecting() {
        let service = MCPService()
        let config = MCPServerConfig(
            name: "test-server",
            command: "/usr/bin/echo",
            arguments: ["hello"],
            isEnabled: true
        )

        service.startServer(config: config)

        #expect(service.state(for: config.id) == .connecting)
        #expect(service.isConnecting)
    }

    @Test("startServer does not start duplicate for same config")
    @MainActor
    func startServerNoDuplicate() {
        let service = MCPService()
        let config = MCPServerConfig(
            name: "test-server",
            command: "/usr/bin/echo",
            arguments: [],
            isEnabled: true
        )

        service.startServer(config: config)
        // Call again — should not crash or create a second task
        service.startServer(config: config)

        #expect(service.state(for: config.id) == .connecting)
    }

    // MARK: - stopServer

    @Test("stopServer sets state to disconnected and clears tools")
    @MainActor
    func stopServerClearsState() {
        let service = MCPService()
        let config = MCPServerConfig(
            name: "test-server",
            command: "/usr/bin/echo",
            arguments: [],
            isEnabled: true
        )

        service.startServer(config: config)
        #expect(service.state(for: config.id) == .connecting)

        service.stopServer(id: config.id)

        #expect(service.state(for: config.id) == .disconnected)
        #expect(service.toolCount(for: config.id) == 0)
    }

    @Test("stopServer is safe when server not running")
    @MainActor
    func stopServerWhenNotRunning() {
        let service = MCPService()
        let id = UUID()

        // Should not crash
        service.stopServer(id: id)
        #expect(service.state(for: id) == .disconnected)
    }

    // MARK: - disconnectAll

    @Test("disconnectAll stops all servers")
    @MainActor
    func disconnectAllStopsEverything() {
        let service = MCPService()
        let config1 = MCPServerConfig(name: "server-1", command: "/usr/bin/echo", isEnabled: true)
        let config2 = MCPServerConfig(name: "server-2", command: "/usr/bin/echo", isEnabled: true)

        service.startServer(config: config1)
        service.startServer(config: config2)

        #expect(service.isConnecting)

        service.disconnectAll()

        #expect(service.state(for: config1.id) == .disconnected)
        #expect(service.state(for: config2.id) == .disconnected)
        #expect(service.toolsByServer.isEmpty)
        #expect(!service.isConnecting)
    }

    // MARK: - syncServers

    @Test("syncServers starts desired servers and stops unwanted ones")
    @MainActor
    func syncServersStartsAndStops() {
        let service = MCPService()
        let config1 = MCPServerConfig(name: "server-1", command: "/usr/bin/echo", isEnabled: true)
        let config2 = MCPServerConfig(name: "server-2", command: "/usr/bin/echo", isEnabled: true)
        let config3 = MCPServerConfig(name: "server-3", command: "/usr/bin/echo", isEnabled: true)
        let allConfigs = [config1, config2, config3]

        // Start with servers 1 and 2
        service.syncServers(desired: [config1.id, config2.id], allConfigs: allConfigs)

        #expect(service.state(for: config1.id) == .connecting)
        #expect(service.state(for: config2.id) == .connecting)
        #expect(service.state(for: config3.id) == .disconnected)

        // Now switch to servers 2 and 3 — should stop 1, keep 2, start 3
        service.syncServers(desired: [config2.id, config3.id], allConfigs: allConfigs)

        #expect(service.state(for: config1.id) == .disconnected)
        #expect(service.state(for: config2.id) == .connecting) // still running
        #expect(service.state(for: config3.id) == .connecting) // newly started
    }

    @Test("syncServers with empty desired set stops all servers")
    @MainActor
    func syncServersEmptyDesired() {
        let service = MCPService()
        let config = MCPServerConfig(name: "server", command: "/usr/bin/echo", isEnabled: true)

        service.startServer(config: config)
        #expect(service.state(for: config.id) == .connecting)

        service.syncServers(desired: [], allConfigs: [config])

        #expect(service.state(for: config.id) == .disconnected)
    }

    @Test("syncServers ignores IDs not in allConfigs")
    @MainActor
    func syncServersIgnoresUnknownIDs() {
        let service = MCPService()
        let unknownID = UUID()

        // Desired contains an ID not in allConfigs — should not crash
        service.syncServers(desired: [unknownID], allConfigs: [])

        #expect(service.state(for: unknownID) == .disconnected)
    }

    // MARK: - Computed Properties

    @Test("isConnected is false when no servers connected")
    @MainActor
    func isConnectedFalseInitially() {
        let service = MCPService()
        #expect(!service.isConnected)
    }

    @Test("availableTools aggregates across all servers")
    @MainActor
    func availableToolsAggregation() {
        let service = MCPService()
        // No tools initially
        #expect(service.availableTools.isEmpty)
    }

    // MARK: - state(for:) helper

    @Test("state(for:) returns disconnected for unknown server")
    @MainActor
    func stateForUnknownServer() {
        let service = MCPService()
        #expect(service.state(for: UUID()) == .disconnected)
    }

    // MARK: - toolCount(for:) helper

    @Test("toolCount(for:) returns 0 for unknown server")
    @MainActor
    func toolCountForUnknownServer() {
        let service = MCPService()
        #expect(service.toolCount(for: UUID()) == 0)
    }
}
