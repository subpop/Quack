import Foundation
import SwiftData

@Model
final class MCPServerConfig {
    var id: UUID
    var name: String
    var command: String
    var argumentsRaw: String
    var environmentJSON: String?
    var workingDirectory: String?
    var isEnabled: Bool
    var initializationTimeout: Double
    var toolCallTimeout: Double

    var arguments: [String] {
        get {
            guard !argumentsRaw.isEmpty else { return [] }
            return argumentsRaw.components(separatedBy: "\n")
        }
        set {
            argumentsRaw = newValue.joined(separator: "\n")
        }
    }

    var environmentVariables: [String: String] {
        get {
            guard let json = environmentJSON,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else {
                environmentJSON = nil
                return
            }
            environmentJSON = json
        }
    }

    /// Tool call permission level for this server.
    var toolPermissionRaw: String?

    var toolPermission: ToolPermission {
        get { ToolPermission(rawValue: toolPermissionRaw ?? "") ?? .ask }
        set { toolPermissionRaw = newValue.rawValue }
    }

    /// A snapshot of the configuration fields that affect MCP server connections.
    /// Used by `onChange` to detect when a reconnection is needed.
    var configSnapshot: ConfigSnapshot {
        ConfigSnapshot(
            id: id,
            name: name,
            command: command,
            argumentsRaw: argumentsRaw,
            environmentJSON: environmentJSON,
            workingDirectory: workingDirectory,
            isEnabled: isEnabled,
            initializationTimeout: initializationTimeout,
            toolCallTimeout: toolCallTimeout
        )
    }

    struct ConfigSnapshot: Equatable {
        let id: UUID
        let name: String
        let command: String
        let argumentsRaw: String
        let environmentJSON: String?
        let workingDirectory: String?
        let isEnabled: Bool
        let initializationTimeout: Double
        let toolCallTimeout: Double
    }

    init(
        name: String = "",
        command: String = "",
        arguments: [String] = [],
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.command = command
        self.argumentsRaw = arguments.joined(separator: "\n")
        self.isEnabled = isEnabled
        self.initializationTimeout = 30.0
        self.toolCallTimeout = 60.0
    }
}
