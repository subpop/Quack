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

// MARK: - Schema V1 (Baseline)

/// Captures the current schema as the V1 baseline.
///
/// Each nested `@Model` class is a snapshot of the persisted stored properties
/// at this version. When the schema evolves, add a new `QuackSchemaV2` with
/// updated model definitions and a corresponding migration stage.
public enum QuackSchemaV1: VersionedSchema {
    public nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
        ]
    }

    @Model
    public final class ChatSession {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var isArchived: Bool
        public var isPinned: Bool

        public var providerIDString: String?
        public var modelIdentifier: String?
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        public var messages: [ChatMessageRecord] = []

        public var enabledMCPServerIDsRaw: String?
        public var toolPermissionOverridesJSON: String?

        public var assistantIDString: String?

        public init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    public final class ChatMessageRecord {
        public var id: UUID
        public var roleRaw: String
        public var content: String
        public var timestamp: Date

        public var inputTokens: Int?
        public var outputTokens: Int?
        public var reasoningTokens: Int?

        public var reasoning: String?

        public var toolCallsJSON: String?

        public var toolCallId: String?
        public var toolName: String?

        public var session: ChatSession?

        public init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    public final class ProviderProfile {
        public var id: UUID
        public var name: String
        public var kindRaw: String
        public var isEnabled: Bool
        public var sortOrder: Int

        public var iconName: String
        public var iconIsCustom: Bool
        public var iconColorName: String

        public var baseURL: String?
        public var requiresAPIKey: Bool

        public var projectID: String?
        public var location: String?

        public var defaultModel: String

        public var maxTokens: Int
        public var contextWindowSize: Int?
        public var reasoningEffort: String?

        public var cachingEnabled: Bool

        public var retryMaxAttempts: Int
        public var retryBaseDelay: Double
        public var retryMaxDelay: Double

        public init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.isEnabled = isEnabled
            self.sortOrder = sortOrder
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
            self.requiresAPIKey = requiresAPIKey
            self.defaultModel = defaultModel
            self.maxTokens = maxTokens
            self.cachingEnabled = cachingEnabled
            self.retryMaxAttempts = retryMaxAttempts
            self.retryBaseDelay = retryBaseDelay
            self.retryMaxDelay = retryMaxDelay
        }
    }

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

        public var toolPermissionRaw: String?

        public init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    @Model
    public final class Assistant {
        public var id: UUID
        public var name: String
        public var systemPrompt: String?
        public var providerIDString: String?
        public var modelIdentifier: String?
        public var isDefault: Bool
        public var sortOrder: Int
        public var iconName: String?
        public var colorRaw: String?

        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?

        public var enabledMCPServerIDsRaw: String?

        public init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
        }
    }
}

// MARK: - Schema V2 (Content Segments + Max Tool Rounds)

/// Adds `contentSegmentsJSON` to `ChatMessageRecord` for interleaved
/// tool call / text rendering, `maxToolRounds` to `ChatSession` and
/// `Assistant` for configurable tool-calling iteration limits, and
/// `toolPermissionDefaultsJSON` to `Assistant` for per-tool permission defaults.
public enum QuackSchemaV2: VersionedSchema {
    public nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
        ]
    }

    @Model
    public final class ChatSession {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var isArchived: Bool
        public var isPinned: Bool

        public var providerIDString: String?
        public var modelIdentifier: String?
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        public var messages: [ChatMessageRecord] = []

        public var enabledMCPServerIDsRaw: String?
        public var toolPermissionOverridesJSON: String?

        public var assistantIDString: String?

        public init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    public final class ChatMessageRecord {
        public var id: UUID
        public var roleRaw: String
        public var content: String
        public var timestamp: Date

        public var inputTokens: Int?
        public var outputTokens: Int?
        public var reasoningTokens: Int?

        public var reasoning: String?

        public var toolCallsJSON: String?
        public var contentSegmentsJSON: String?

        public var toolCallId: String?
        public var toolName: String?

        public var session: ChatSession?

        public init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    public final class ProviderProfile {
        public var id: UUID
        public var name: String
        public var kindRaw: String
        public var isEnabled: Bool
        public var sortOrder: Int

        public var iconName: String
        public var iconIsCustom: Bool
        public var iconColorName: String

        public var baseURL: String?
        public var requiresAPIKey: Bool

        public var projectID: String?
        public var location: String?

        public var defaultModel: String

        public var maxTokens: Int
        public var contextWindowSize: Int?
        public var reasoningEffort: String?

        public var cachingEnabled: Bool

        public var retryMaxAttempts: Int
        public var retryBaseDelay: Double
        public var retryMaxDelay: Double

        public init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.isEnabled = isEnabled
            self.sortOrder = sortOrder
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
            self.requiresAPIKey = requiresAPIKey
            self.defaultModel = defaultModel
            self.maxTokens = maxTokens
            self.cachingEnabled = cachingEnabled
            self.retryMaxAttempts = retryMaxAttempts
            self.retryBaseDelay = retryBaseDelay
            self.retryMaxDelay = retryMaxDelay
        }
    }

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

        public var toolPermissionRaw: String?

        public init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    @Model
    public final class Assistant {
        public var id: UUID
        public var name: String
        public var systemPrompt: String?
        public var providerIDString: String?
        public var modelIdentifier: String?
        public var isDefault: Bool
        public var sortOrder: Int
        public var iconName: String?
        public var colorRaw: String?

        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        public var enabledMCPServerIDsRaw: String?
        public var toolPermissionDefaultsJSON: String?

        public init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
        }
    }
}

// MARK: - Schema V3 (Built-in Tools)

/// Adds `enabledBuiltInToolIDsRaw` to `ChatSession` and `Assistant` for
/// per-session and per-assistant built-in tool enable/disable configuration.
public enum QuackSchemaV3: VersionedSchema {
    public nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
        ]
    }

    @Model
    public final class ChatSession {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var isArchived: Bool
        public var isPinned: Bool

        public var providerIDString: String?
        public var modelIdentifier: String?
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        public var messages: [ChatMessageRecord] = []

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var toolPermissionOverridesJSON: String?

        public var assistantIDString: String?

        public init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    public final class ChatMessageRecord {
        public var id: UUID
        public var roleRaw: String
        public var content: String
        public var timestamp: Date

        public var inputTokens: Int?
        public var outputTokens: Int?
        public var reasoningTokens: Int?

        public var reasoning: String?

        public var toolCallsJSON: String?
        public var contentSegmentsJSON: String?

        public var toolCallId: String?
        public var toolName: String?

        public var session: ChatSession?

        public init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    public final class ProviderProfile {
        public var id: UUID
        public var name: String
        public var kindRaw: String
        public var isEnabled: Bool
        public var sortOrder: Int

        public var iconName: String
        public var iconIsCustom: Bool
        public var iconColorName: String

        public var baseURL: String?
        public var requiresAPIKey: Bool

        public var projectID: String?
        public var location: String?

        public var defaultModel: String

        public var maxTokens: Int
        public var contextWindowSize: Int?
        public var reasoningEffort: String?

        public var cachingEnabled: Bool

        public var retryMaxAttempts: Int
        public var retryBaseDelay: Double
        public var retryMaxDelay: Double

        public init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.isEnabled = isEnabled
            self.sortOrder = sortOrder
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
            self.requiresAPIKey = requiresAPIKey
            self.defaultModel = defaultModel
            self.maxTokens = maxTokens
            self.cachingEnabled = cachingEnabled
            self.retryMaxAttempts = retryMaxAttempts
            self.retryBaseDelay = retryBaseDelay
            self.retryMaxDelay = retryMaxDelay
        }
    }

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

        public var toolPermissionRaw: String?

        public init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    @Model
    public final class Assistant {
        public var id: UUID
        public var name: String
        public var systemPrompt: String?
        public var providerIDString: String?
        public var modelIdentifier: String?
        public var isDefault: Bool
        public var sortOrder: Int
        public var iconName: String?
        public var colorRaw: String?

        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var toolPermissionDefaultsJSON: String?

        public init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
        }
    }
}

// MARK: - Schema V4

/// V4 adds `modelsDevProviderID` to `ProviderProfile` for per-provider pricing lookups.
public enum QuackSchemaV4: VersionedSchema {
    public nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
        ]
    }

    @Model
    public final class ChatSession {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var isArchived: Bool
        public var isPinned: Bool

        public var providerIDString: String?
        public var modelIdentifier: String?
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        public var messages: [ChatMessageRecord] = []

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var toolPermissionOverridesJSON: String?

        public var assistantIDString: String?

        public init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    public final class ChatMessageRecord {
        public var id: UUID
        public var roleRaw: String
        public var content: String
        public var timestamp: Date

        public var inputTokens: Int?
        public var outputTokens: Int?
        public var reasoningTokens: Int?

        public var reasoning: String?

        public var toolCallsJSON: String?
        public var contentSegmentsJSON: String?

        public var toolCallId: String?
        public var toolName: String?

        public var session: ChatSession?

        public init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    public final class ProviderProfile {
        public var id: UUID
        public var name: String
        public var kindRaw: String
        public var isEnabled: Bool
        public var sortOrder: Int

        public var iconName: String
        public var iconIsCustom: Bool
        public var iconColorName: String

        public var baseURL: String?
        public var requiresAPIKey: Bool

        public var projectID: String?
        public var location: String?

        public var defaultModel: String

        public var maxTokens: Int
        public var contextWindowSize: Int?
        public var reasoningEffort: String?

        public var cachingEnabled: Bool

        public var retryMaxAttempts: Int
        public var retryBaseDelay: Double
        public var retryMaxDelay: Double

        public var modelsDevProviderID: String?

        public init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.isEnabled = isEnabled
            self.sortOrder = sortOrder
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
            self.requiresAPIKey = requiresAPIKey
            self.defaultModel = defaultModel
            self.maxTokens = maxTokens
            self.cachingEnabled = cachingEnabled
            self.retryMaxAttempts = retryMaxAttempts
            self.retryBaseDelay = retryBaseDelay
            self.retryMaxDelay = retryMaxDelay
        }
    }

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

        public var toolPermissionRaw: String?

        public init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    @Model
    public final class Assistant {
        public var id: UUID
        public var name: String
        public var systemPrompt: String?
        public var providerIDString: String?
        public var modelIdentifier: String?
        public var isDefault: Bool
        public var sortOrder: Int
        public var iconName: String?
        public var colorRaw: String?

        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var toolPermissionDefaultsJSON: String?

        public init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
        }
    }
}

// MARK: - Schema V5 (Agent Skills)

/// V5 introduces the `AgentSkill` model for installed skills and adds
/// `alwaysEnabledSkillNamesRaw` to `ChatSession` and `Assistant`.
public enum QuackSchemaV5: VersionedSchema {
    public nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(5, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
            AgentSkill.self,
        ]
    }

    @Model
    public final class ChatSession {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var isArchived: Bool
        public var isPinned: Bool

        public var providerIDString: String?
        public var modelIdentifier: String?
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        public var messages: [ChatMessageRecord] = []

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var alwaysEnabledSkillNamesRaw: String?
        public var toolPermissionOverridesJSON: String?

        public var assistantIDString: String?

        public init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    public final class ChatMessageRecord {
        public var id: UUID
        public var roleRaw: String
        public var content: String
        public var timestamp: Date

        public var inputTokens: Int?
        public var outputTokens: Int?
        public var reasoningTokens: Int?

        public var reasoning: String?

        public var toolCallsJSON: String?
        public var contentSegmentsJSON: String?

        public var toolCallId: String?
        public var toolName: String?

        public var session: ChatSession?

        public init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    public final class ProviderProfile {
        public var id: UUID
        public var name: String
        public var kindRaw: String
        public var isEnabled: Bool
        public var sortOrder: Int

        public var iconName: String
        public var iconIsCustom: Bool
        public var iconColorName: String

        public var baseURL: String?
        public var requiresAPIKey: Bool

        public var projectID: String?
        public var location: String?

        public var defaultModel: String

        public var maxTokens: Int
        public var contextWindowSize: Int?
        public var reasoningEffort: String?

        public var cachingEnabled: Bool

        public var retryMaxAttempts: Int
        public var retryBaseDelay: Double
        public var retryMaxDelay: Double

        public var modelsDevProviderID: String?

        public init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.isEnabled = isEnabled
            self.sortOrder = sortOrder
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
            self.requiresAPIKey = requiresAPIKey
            self.defaultModel = defaultModel
            self.maxTokens = maxTokens
            self.cachingEnabled = cachingEnabled
            self.retryMaxAttempts = retryMaxAttempts
            self.retryBaseDelay = retryBaseDelay
            self.retryMaxDelay = retryMaxDelay
        }
    }

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

        public var toolPermissionRaw: String?

        public init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    @Model
    public final class Assistant {
        public var id: UUID
        public var name: String
        public var systemPrompt: String?
        public var providerIDString: String?
        public var modelIdentifier: String?
        public var isDefault: Bool
        public var sortOrder: Int
        public var iconName: String?
        public var colorRaw: String?

        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var alwaysEnabledSkillNamesRaw: String?
        public var toolPermissionDefaultsJSON: String?

        public init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
        }
    }

    @Model
    public final class AgentSkill {
        public var id: UUID
        public var name: String
        public var source: String
        public var skillDescription: String?
        public var contentHash: String?
        public var isEnabled: Bool
        public var installedAt: Date
        public var updatedAt: Date
        public var contentPath: String?

        public init(id: UUID = UUID(), name: String = "", source: String = "", isEnabled: Bool = true, installedAt: Date = .init(), updatedAt: Date = .init()) {
            self.id = id
            self.name = name
            self.source = source
            self.isEnabled = isEnabled
            self.installedAt = installedAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - V6

public enum QuackSchemaV6: VersionedSchema {
    public nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(6, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
            AgentSkill.self,
        ]
    }

    @Model
    public final class ChatSession {
        public var id: UUID
        public var title: String
        public var createdAt: Date
        public var updatedAt: Date
        public var isArchived: Bool
        public var isPinned: Bool

        public var providerIDString: String?
        public var modelIdentifier: String?
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        public var messages: [ChatMessageRecord] = []

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var alwaysEnabledSkillNamesRaw: String?
        public var toolPermissionOverridesJSON: String?

        public var assistantIDString: String?

        public var workingDirectory: String?

        public init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    public final class ChatMessageRecord {
        public var id: UUID
        public var roleRaw: String
        public var content: String
        public var timestamp: Date

        public var inputTokens: Int?
        public var outputTokens: Int?
        public var reasoningTokens: Int?

        public var reasoning: String?

        public var toolCallsJSON: String?
        public var contentSegmentsJSON: String?

        public var toolCallId: String?
        public var toolName: String?

        public var session: ChatSession?

        public init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    public final class ProviderProfile {
        public var id: UUID
        public var name: String
        public var kindRaw: String
        public var isEnabled: Bool
        public var sortOrder: Int

        public var iconName: String
        public var iconIsCustom: Bool
        public var iconColorName: String

        public var baseURL: String?
        public var requiresAPIKey: Bool

        public var projectID: String?
        public var location: String?

        public var defaultModel: String

        public var maxTokens: Int
        public var contextWindowSize: Int?
        public var reasoningEffort: String?

        public var cachingEnabled: Bool

        public var retryMaxAttempts: Int
        public var retryBaseDelay: Double
        public var retryMaxDelay: Double

        public var modelsDevProviderID: String?

        public init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
            self.id = id
            self.name = name
            self.kindRaw = kindRaw
            self.isEnabled = isEnabled
            self.sortOrder = sortOrder
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
            self.requiresAPIKey = requiresAPIKey
            self.defaultModel = defaultModel
            self.maxTokens = maxTokens
            self.cachingEnabled = cachingEnabled
            self.retryMaxAttempts = retryMaxAttempts
            self.retryBaseDelay = retryBaseDelay
            self.retryMaxDelay = retryMaxDelay
        }
    }

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

        public var toolPermissionRaw: String?

        public init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
            self.id = id
            self.name = name
            self.command = command
            self.argumentsRaw = argumentsRaw
            self.isEnabled = isEnabled
            self.initializationTimeout = initializationTimeout
            self.toolCallTimeout = toolCallTimeout
        }
    }

    @Model
    public final class Assistant {
        public var id: UUID
        public var name: String
        public var systemPrompt: String?
        public var providerIDString: String?
        public var modelIdentifier: String?
        public var isDefault: Bool
        public var sortOrder: Int
        public var iconName: String?
        public var colorRaw: String?

        public var temperature: Double?
        public var maxTokens: Int?
        public var reasoningEffort: String?
        public var compactionThreshold: Double?
        public var maxMessages: Int?
        public var maxToolRounds: Int?

        public var enabledMCPServerIDsRaw: String?
        public var enabledBuiltInToolIDsRaw: String?
        public var alwaysEnabledSkillNamesRaw: String?
        public var toolPermissionDefaultsJSON: String?

        public init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
        }
    }

    @Model
    public final class AgentSkill {
        public var id: UUID
        public var name: String
        public var source: String
        public var sourceType: String
        public var skillDescription: String?
        public var contentHash: String?
        public var isEnabled: Bool
        public var installedAt: Date
        public var updatedAt: Date
        public var contentPath: String?

        public init(id: UUID = UUID(), name: String = "", source: String = "", sourceType: String = "github", isEnabled: Bool = true, installedAt: Date = .init(), updatedAt: Date = .init()) {
            self.id = id
            self.name = name
            self.source = source
            self.sourceType = sourceType
            self.isEnabled = isEnabled
            self.installedAt = installedAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Migration Plan

/// Describes the evolution of Quack's schema and how to migrate between versions.
///
/// When adding a new schema version:
/// 1. Define `QuackSchemaV2` (or V3, etc.) with updated nested model classes.
/// 2. Update the live `@Model` classes to match the latest version.
/// 3. Append the new schema to the `schemas` array.
/// 4. Add a migration stage (`.lightweight` or `.custom`) to `stages`.
public enum QuackMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [QuackSchemaV1.self, QuackSchemaV2.self, QuackSchemaV3.self, QuackSchemaV4.self, QuackSchemaV5.self, QuackSchemaV6.self]
    }

    public static var stages: [MigrationStage] {
        [
            // V1 → V2: adds optional columns to ChatMessageRecord, ChatSession, and Assistant.
            .lightweight(fromVersion: QuackSchemaV1.self, toVersion: QuackSchemaV2.self),
            // V2 → V3: adds enabledBuiltInToolIDsRaw to ChatSession and Assistant.
            .lightweight(fromVersion: QuackSchemaV2.self, toVersion: QuackSchemaV3.self),
            // V3 → V4: adds modelsDevProviderID to ProviderProfile.
            .lightweight(fromVersion: QuackSchemaV3.self, toVersion: QuackSchemaV4.self),
            // V4 → V5: adds AgentSkill model.
            .lightweight(fromVersion: QuackSchemaV4.self, toVersion: QuackSchemaV5.self),
            // V5 → V6: adds workingDirectory to ChatSession.
            .lightweight(fromVersion: QuackSchemaV5.self, toVersion: QuackSchemaV6.self),
        ]
    }
}
