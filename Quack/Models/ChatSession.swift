import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var isPinned: Bool

    // Per-session overrides (nil = use global default)
    /// The UUID of the ProviderProfile to use for this session, stored as a string.
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

    // The assistant that created this session (stored as UUID string)
    var assistantIDString: String?

    // MCP server IDs enabled for this session (stored as comma-separated UUIDs)
    var enabledMCPServerIDsRaw: String?

    /// Per-tool permission overrides for this session.
    /// JSON-encoded `[String: String]` mapping tool name -> ToolPermission raw value.
    /// nil means "use the server-level default for all tools."
    var toolPermissionOverridesJSON: String?

    /// The provider profile UUID for this session, if overridden.
    var providerID: UUID? {
        get {
            guard let str = providerIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { providerIDString = newValue?.uuidString }
    }

    /// The assistant that created this session, if any.
    var assistantID: UUID? {
        get {
            guard let str = assistantIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { assistantIDString = newValue?.uuidString }
    }

    var enabledMCPServerIDs: [UUID]? {
        get {
            guard let raw = enabledMCPServerIDsRaw, !raw.isEmpty else { return nil }
            return raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        }
        set {
            enabledMCPServerIDsRaw = newValue?.map(\.uuidString).joined(separator: ",")
        }
    }

    /// Per-tool permission overrides. Key is the tool name, value is the permission.
    /// Returns nil if no overrides are set (use server defaults for everything).
    var toolPermissionOverrides: [String: ToolPermission]? {
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
    func effectivePermission(for toolName: String, serverDefault: ToolPermission) -> ToolPermission {
        toolPermissionOverrides?[toolName] ?? serverDefault
    }

    /// Set a per-tool permission override for this session.
    /// Pass nil to clear the override and use the server default.
    func setToolPermission(_ permission: ToolPermission?, for toolName: String, serverDefault: ToolPermission) {
        var overrides = toolPermissionOverrides ?? [:]
        if let permission, permission != serverDefault {
            overrides[toolName] = permission
        } else {
            overrides.removeValue(forKey: toolName)
        }
        toolPermissionOverrides = overrides.isEmpty ? nil : overrides
    }

    var sortedMessages: [ChatMessageRecord] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    /// Create a new chat session, optionally copying parameters from a provider profile.
    ///
    /// When a profile is provided, its user-configurable parameters (provider ID,
    /// model, maxTokens, reasoning effort) are *copied* into the session. From that
    /// point on, the session's values are independent and can be changed without
    /// affecting the originating profile.
    init(
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
    init(
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
        self.enabledMCPServerIDsRaw = assistant.enabledMCPServerIDsRaw
    }
}
