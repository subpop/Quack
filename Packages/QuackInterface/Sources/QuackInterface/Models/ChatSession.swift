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
public final class ChatSession {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isArchived: Bool
    public var isPinned: Bool

    // Per-session overrides (nil = use global default)
    /// The UUID of the ProviderProfile to use for this session, stored as a string.
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

    // The assistant that created this session (stored as UUID string)
    public var assistantIDString: String?

    // MCP server IDs enabled for this session (stored as comma-separated UUIDs)
    public var enabledMCPServerIDsRaw: String?

    // Built-in tool IDs enabled for this session (stored as comma-separated IDs)
    public var enabledBuiltInToolIDsRaw: String?

    // Skill names that are always loaded into the system prompt (stored as comma-separated names)
    public var alwaysEnabledSkillNamesRaw: String?

    /// Per-tool permission overrides for this session.
    /// JSON-encoded `[String: String]` mapping tool name -> ToolPermission raw value.
    /// nil means "use the server-level default for all tools."
    public var toolPermissionOverridesJSON: String?

    /// The provider profile UUID for this session, if overridden.
    public var providerID: UUID? {
        get {
            guard let str = providerIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { providerIDString = newValue?.uuidString }
    }

    /// The assistant that created this session, if any.
    public var assistantID: UUID? {
        get {
            guard let str = assistantIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { assistantIDString = newValue?.uuidString }
    }

    public var enabledMCPServerIDs: [UUID]? {
        get {
            guard let raw = enabledMCPServerIDsRaw, !raw.isEmpty else { return nil }
            return raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        }
        set {
            enabledMCPServerIDsRaw = newValue?.map(\.uuidString).joined(separator: ",")
        }
    }

    /// Built-in tool IDs enabled for this session.
    /// Returns nil if no built-in tools are enabled.
    public var enabledBuiltInToolIDs: [String]? {
        get {
            guard let raw = enabledBuiltInToolIDsRaw, !raw.isEmpty else { return nil }
            return raw.split(separator: ",").map(String.init)
        }
        set {
            enabledBuiltInToolIDsRaw = newValue?.joined(separator: ",")
        }
    }

    /// Skill names that are always loaded into the system prompt for this session.
    public var alwaysEnabledSkillNames: [String]? {
        get {
            guard let raw = alwaysEnabledSkillNamesRaw, !raw.isEmpty else { return nil }
            return raw.split(separator: ",").map(String.init)
        }
        set {
            alwaysEnabledSkillNamesRaw = newValue?.joined(separator: ",")
        }
    }

    /// Per-tool permission overrides. Key is the tool name, value is the permission.
    /// Returns nil if no overrides are set (use server defaults for everything).
    public var toolPermissionOverrides: [String: ToolPermission]? {
        get {
            guard let json = toolPermissionOverridesJSON,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return nil }
            let mapped = dict.compactMapValues { ToolPermission(rawValue: $0) }
            return mapped.isEmpty ? nil : mapped
        }
        set {
            guard let newValue, !newValue.isEmpty else {
                toolPermissionOverridesJSON = nil
                return
            }
            let raw = newValue.mapValues(\.rawValue)
            guard let data = try? JSONEncoder().encode(raw),
                  let json = String(data: data, encoding: .utf8)
            else {
                toolPermissionOverridesJSON = nil
                return
            }
            toolPermissionOverridesJSON = json
        }
    }

    /// Get the effective permission for a specific tool in this session.
    /// Checks session override first, then falls back to the server default.
    public func effectivePermission(for toolName: String, serverDefault: ToolPermission) -> ToolPermission {
        toolPermissionOverrides?[toolName] ?? serverDefault
    }

    /// Set a per-tool permission override for this session.
    /// Pass nil to clear the override and use the server default.
    public func setToolPermission(_ permission: ToolPermission?, for toolName: String, serverDefault: ToolPermission) {
        var overrides = toolPermissionOverrides ?? [:]
        if let permission, permission != serverDefault {
            overrides[toolName] = permission
        } else {
            overrides.removeValue(forKey: toolName)
        }
        toolPermissionOverrides = overrides.isEmpty ? nil : overrides
    }

    public var sortedMessages: [ChatMessageRecord] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    /// Create a new chat session, optionally copying parameters from a provider profile.
    ///
    /// When a profile is provided, its user-configurable parameters (provider ID,
    /// model, maxTokens, reasoning effort) are *copied* into the session. From that
    /// point on, the session's values are independent and can be changed without
    /// affecting the originating profile.
    public init(
        title: String = "New Chat",
        profile: ProviderProfile? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.isPinned = false

        // Copy from profile at creation time
        if let profile {
            self.providerIDString = profile.id.uuidString
            self.modelIdentifier = profile.defaultModel
            self.maxTokens = profile.maxTokens
            self.reasoningEffort = profile.reasoningEffort
        }
    }

    /// Create a new chat session from an Assistant, copying all its defaults.
    ///
    /// The assistant's provider, model, system prompt, parameters, and MCP
    /// configuration are all copied into the session at creation time. From that
    /// point on, the session's values are independent and can be changed in the
    /// inspector without affecting the originating assistant.
    public init(
        title: String = "New Chat",
        assistant: Assistant
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.isPinned = false

        self.assistantIDString = assistant.id.uuidString
        self.providerIDString = assistant.providerIDString
        self.modelIdentifier = assistant.modelIdentifier
        self.systemPrompt = assistant.systemPrompt
        self.temperature = assistant.temperature
        self.maxTokens = assistant.maxTokens
        self.reasoningEffort = assistant.reasoningEffort
        self.compactionThreshold = assistant.compactionThreshold
        self.maxMessages = assistant.maxMessages
        self.maxToolRounds = assistant.maxToolRounds
        self.enabledMCPServerIDsRaw = assistant.enabledMCPServerIDsRaw
        self.enabledBuiltInToolIDsRaw = assistant.enabledBuiltInToolIDsRaw
        self.alwaysEnabledSkillNamesRaw = assistant.alwaysEnabledSkillNamesRaw
        self.toolPermissionOverridesJSON = assistant.toolPermissionDefaultsJSON
    }
}
