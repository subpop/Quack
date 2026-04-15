import Testing
import Foundation
@testable import QuackKit

struct MCPServerConfigTests {
    @Test func initDefaults() {
        let config = MCPServerConfig()
        #expect(config.name == "")
        #expect(config.command == "")
        #expect(config.arguments.isEmpty)
        #expect(config.isEnabled == true)
        #expect(config.initializationTimeout == 30.0)
        #expect(config.toolCallTimeout == 60.0)
    }

    @Test func initWithValues() {
        let config = MCPServerConfig(
            name: "Test Server",
            command: "/usr/bin/node",
            arguments: ["server.js", "--port", "3000"],
            isEnabled: false
        )
        #expect(config.name == "Test Server")
        #expect(config.command == "/usr/bin/node")
        #expect(config.arguments == ["server.js", "--port", "3000"])
        #expect(config.isEnabled == false)
    }

    @Test func argumentsRoundTrip() {
        let config = MCPServerConfig()
        config.arguments = ["arg1", "arg2", "arg3"]
        #expect(config.arguments == ["arg1", "arg2", "arg3"])
        #expect(config.argumentsRaw == "arg1\narg2\narg3")
    }

    @Test func argumentsEmptyRaw() {
        let config = MCPServerConfig()
        config.argumentsRaw = ""
        #expect(config.arguments.isEmpty)
    }

    @Test func environmentVariablesRoundTrip() {
        let config = MCPServerConfig()
        config.environmentVariables = ["PATH": "/usr/bin", "NODE_ENV": "production"]
        let vars = config.environmentVariables
        #expect(vars["PATH"] == "/usr/bin")
        #expect(vars["NODE_ENV"] == "production")
    }

    @Test func environmentVariablesEmpty() {
        let config = MCPServerConfig()
        #expect(config.environmentVariables.isEmpty)
    }

    @Test func environmentVariablesSetEmpty() {
        let config = MCPServerConfig()
        config.environmentVariables = ["KEY": "VALUE"]
        config.environmentVariables = [:]
        // Setting empty dict encodes as "{}" or nil depending on implementation
        let vars = config.environmentVariables
        #expect(vars.isEmpty)
    }

    @Test func toolPermissionDefault() {
        let config = MCPServerConfig()
        #expect(config.toolPermission == .ask)
    }

    @Test func toolPermissionRoundTrip() {
        let config = MCPServerConfig()
        config.toolPermission = .always
        #expect(config.toolPermission == .always)
        #expect(config.toolPermissionRaw == "always")

        config.toolPermission = .deny
        #expect(config.toolPermission == .deny)
    }

    @Test func configSnapshot() {
        let config = MCPServerConfig(
            name: "Test",
            command: "/usr/bin/node",
            arguments: ["index.js"],
            isEnabled: true
        )
        let snapshot = config.configSnapshot
        #expect(snapshot.name == "Test")
        #expect(snapshot.command == "/usr/bin/node")
        #expect(snapshot.argumentsRaw == "index.js")
        #expect(snapshot.isEnabled == true)
        #expect(snapshot.initializationTimeout == 30.0)
        #expect(snapshot.toolCallTimeout == 60.0)
    }

    @Test func configSnapshotEquality() {
        let config = MCPServerConfig(name: "A", command: "cmd")
        let snap1 = config.configSnapshot
        let snap2 = config.configSnapshot
        #expect(snap1 == snap2)

        config.name = "B"
        let snap3 = config.configSnapshot
        #expect(snap1 != snap3)
    }
}
