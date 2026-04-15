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

@Model
public final class MCPServerConfig {
    public var id: UUID
    public var name: String
    public var command: String
    public var argumentsRaw: String
    public var environmentJSON: String?
    public var workingDirectory: String?
    public var isEnabled: Bool
    public var initializationTimeout: Double
    public var toolCallTimeout: Double

    public var arguments: [String] {
        get {
            guard !argumentsRaw.isEmpty else { return [] }
            return argumentsRaw.components(separatedBy: "\n")
        }
        set {
            argumentsRaw = newValue.joined(separator: "\n")
        }
    }

    public var environmentVariables: [String: String] {
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
    public var toolPermissionRaw: String?

    public var toolPermission: ToolPermission {
        get { ToolPermission(rawValue: toolPermissionRaw ?? "") ?? .ask }
        set { toolPermissionRaw = newValue.rawValue }
    }

    /// A snapshot of the configuration fields that affect MCP server connections.
    /// Used by `onChange` to detect when a reconnection is needed.
    public var configSnapshot: ConfigSnapshot {
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

    public struct ConfigSnapshot: Equatable {
        public let id: UUID
        public let name: String
        public let command: String
        public let argumentsRaw: String
        public let environmentJSON: String?
        public let workingDirectory: String?
        public let isEnabled: Bool
        public let initializationTimeout: Double
        public let toolCallTimeout: Double

        public init(
            id: UUID,
            name: String,
            command: String,
            argumentsRaw: String,
            environmentJSON: String?,
            workingDirectory: String?,
            isEnabled: Bool,
            initializationTimeout: Double,
            toolCallTimeout: Double
        ) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.environmentJSON = environmentJSON
            self.workingDirectory = workingDirectory
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    public init(
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
