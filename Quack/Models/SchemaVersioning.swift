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
enum QuackSchemaV1: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
        ]
    }

    @Model
    final class ChatSession {
        var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var isArchived: Bool
        var isPinned: Bool

        var providerIDString: String?
        var modelIdentifier: String?
        var systemPrompt: String?
        var temperature: Double?
        var maxTokens: Int?
        var reasoningEffort: String?
        var compactionThreshold: Double?
        var maxMessages: Int?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
        var messages: [ChatMessageRecord] = []

        var enabledMCPServerIDsRaw: String?
        var toolPermissionOverridesJSON: String?

        var assistantIDString: String?

        init(id: UUID = UUID(), title: String = "", createdAt: Date = .init(), updatedAt: Date = .init(), isArchived: Bool = false, isPinned: Bool = false) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isArchived = isArchived
            self.isPinned = isPinned
        }
    }

    @Model
    final class ChatMessageRecord {
        var id: UUID
        var roleRaw: String
        var content: String
        var timestamp: Date

        var inputTokens: Int?
        var outputTokens: Int?
        var reasoningTokens: Int?

        var reasoning: String?

        var toolCallsJSON: String?

        var toolCallId: String?
        var toolName: String?

        var session: ChatSession?

        init(id: UUID = UUID(), roleRaw: String = "", content: String = "", timestamp: Date = .init()) {
            self.id = id
            self.roleRaw = roleRaw
            self.content = content
            self.timestamp = timestamp
        }
    }

    @Model
    final class ProviderProfile {
        var id: UUID
        var name: String
        var kindRaw: String
        var isEnabled: Bool
        var sortOrder: Int

        var iconName: String
        var iconIsCustom: Bool
        var iconColorName: String

        var baseURL: String?
        var requiresAPIKey: Bool

        var projectID: String?
        var location: String?

        var defaultModel: String

        var maxTokens: Int
        var contextWindowSize: Int?
        var reasoningEffort: String?

        var cachingEnabled: Bool

        var retryMaxAttempts: Int
        var retryBaseDelay: Double
        var retryMaxDelay: Double

        init(id: UUID = UUID(), name: String = "", kindRaw: String = "", isEnabled: Bool = true, sortOrder: Int = 0, iconName: String = "", iconIsCustom: Bool = false, iconColorName: String = "", requiresAPIKey: Bool = true, defaultModel: String = "", maxTokens: Int = 4096, cachingEnabled: Bool = false, retryMaxAttempts: Int = 3, retryBaseDelay: Double = 1.0, retryMaxDelay: Double = 30.0) {
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

        var toolPermissionRaw: String?

        init(id: UUID = UUID(), name: String = "", command: String = "", argumentsRaw: String = "", isEnabled: Bool = true, initializationTimeout: Double = 30.0, toolCallTimeout: Double = 60.0) {
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
    final class Assistant {
        var id: UUID
        var name: String
        var systemPrompt: String?
        var providerIDString: String?
        var modelIdentifier: String?
        var isDefault: Bool
        var sortOrder: Int
        var iconName: String?
        var colorRaw: String?

        var temperature: Double?
        var maxTokens: Int?
        var reasoningEffort: String?
        var compactionThreshold: Double?
        var maxMessages: Int?

        var enabledMCPServerIDsRaw: String?

        init(id: UUID = UUID(), name: String = "", isDefault: Bool = false, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.isDefault = isDefault
            self.sortOrder = sortOrder
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
enum QuackMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [QuackSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
