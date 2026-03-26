import Testing
import Foundation
@testable import Quack

/// Tests for MCPServerConfig model and its configSnapshot mechanism
/// used to detect when MCP reconnection is needed.
@Suite("MCPServerConfig")
struct MCPServerConfigTests {

    // MARK: - Initialization

    @Test("Default initialization sets expected values")
    @MainActor
    func defaultInit() {
        let config = MCPServerConfig()

        #expect(config.name == "")
        #expect(config.command == "")
        #expect(config.arguments.isEmpty)
        #expect(config.isEnabled == true)
        #expect(config.initializationTimeout == 30.0)
        #expect(config.toolCallTimeout == 60.0)
        #expect(config.workingDirectory == nil)
        #expect(config.environmentVariables.isEmpty)
    }

    @Test("Custom initialization preserves values")
    @MainActor
    func customInit() {
        let config = MCPServerConfig(
            name: "my-server",
            command: "/usr/local/bin/mcp-server",
            arguments: ["--stdio", "--verbose"],
            isEnabled: false
        )

        #expect(config.name == "my-server")
        #expect(config.command == "/usr/local/bin/mcp-server")
        #expect(config.arguments == ["--stdio", "--verbose"])
        #expect(config.isEnabled == false)
    }

    // MARK: - Arguments encoding

    @Test("Arguments are stored as newline-separated raw string")
    @MainActor
    func argumentsEncoding() {
        let config = MCPServerConfig(
            name: "test",
            command: "echo",
            arguments: ["arg1", "arg2", "arg3"]
        )

        #expect(config.argumentsRaw == "arg1\narg2\narg3")
        #expect(config.arguments == ["arg1", "arg2", "arg3"])
    }

    @Test("Empty arguments produce empty raw string")
    @MainActor
    func emptyArguments() {
        let config = MCPServerConfig(name: "test", command: "echo")

        #expect(config.argumentsRaw == "")
        #expect(config.arguments.isEmpty)
    }

    // MARK: - Environment variables encoding

    @Test("Environment variables roundtrip through JSON")
    @MainActor
    func environmentVariablesRoundtrip() {
        let config = MCPServerConfig(name: "test", command: "echo")
        config.environmentVariables = ["API_KEY": "secret123", "DEBUG": "true"]

        let result = config.environmentVariables
        #expect(result["API_KEY"] == "secret123")
        #expect(result["DEBUG"] == "true")
    }

    @Test("Empty environment variables returns empty dict")
    @MainActor
    func emptyEnvironmentVariables() {
        let config = MCPServerConfig(name: "test", command: "echo")
        #expect(config.environmentVariables.isEmpty)
        #expect(config.environmentJSON == nil)
    }

    // MARK: - ConfigSnapshot

    @Test("ConfigSnapshot equality matches identical configs")
    @MainActor
    func snapshotEquality() {
        let config = MCPServerConfig(
            name: "server",
            command: "/usr/bin/echo",
            arguments: ["--stdio"],
            isEnabled: true
        )

        let snapshot1 = config.configSnapshot
        let snapshot2 = config.configSnapshot

        #expect(snapshot1 == snapshot2)
    }

    @Test("ConfigSnapshot detects isEnabled change")
    @MainActor
    func snapshotDetectsEnabledChange() {
        let config = MCPServerConfig(
            name: "server",
            command: "/usr/bin/echo",
            arguments: ["--stdio"],
            isEnabled: true
        )

        let before = config.configSnapshot
        config.isEnabled = false
        let after = config.configSnapshot

        #expect(before != after)
    }

    @Test("ConfigSnapshot detects command change")
    @MainActor
    func snapshotDetectsCommandChange() {
        let config = MCPServerConfig(
            name: "server",
            command: "/usr/bin/echo"
        )

        let before = config.configSnapshot
        config.command = "/usr/local/bin/mcp-server"
        let after = config.configSnapshot

        #expect(before != after)
    }

    @Test("ConfigSnapshot detects arguments change")
    @MainActor
    func snapshotDetectsArgumentsChange() {
        let config = MCPServerConfig(
            name: "server",
            command: "/usr/bin/echo",
            arguments: ["--stdio"]
        )

        let before = config.configSnapshot
        config.arguments = ["--stdio", "--verbose"]
        let after = config.configSnapshot

        #expect(before != after)
    }

    @Test("ConfigSnapshot detects name change")
    @MainActor
    func snapshotDetectsNameChange() {
        let config = MCPServerConfig(
            name: "server-v1",
            command: "/usr/bin/echo"
        )

        let before = config.configSnapshot
        config.name = "server-v2"
        let after = config.configSnapshot

        #expect(before != after)
    }

    @Test("ConfigSnapshot detects environment change")
    @MainActor
    func snapshotDetectsEnvironmentChange() {
        let config = MCPServerConfig(
            name: "server",
            command: "/usr/bin/echo"
        )

        let before = config.configSnapshot
        config.environmentVariables = ["KEY": "value"]
        let after = config.configSnapshot

        #expect(before != after)
    }

    @Test("ConfigSnapshot detects timeout change")
    @MainActor
    func snapshotDetectsTimeoutChange() {
        let config = MCPServerConfig(
            name: "server",
            command: "/usr/bin/echo"
        )

        let before = config.configSnapshot
        config.initializationTimeout = 60.0
        let after = config.configSnapshot

        #expect(before != after)
    }
}
