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
    /// The UUID of the Provider to use for this session, stored as a string.
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

    // MCP server IDs enabled for this session (stored as comma-separated UUIDs)
    var enabledMCPServerIDsRaw: String?

    /// Per-tool permission overrides for this session.
    /// JSON-encoded `[String: String]` mapping tool name -> ToolPermission raw value.
    /// nil means "use the server-level default for all tools."
    var toolPermissionOverridesJSON: String?

    /// The provider UUID for this session, if overridden.
    var providerID: UUID? {
        get {
            guard let str = providerIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { providerIDString = newValue?.uuidString }
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

    init(
        title: String = "New Chat",
        providerID: UUID? = nil,
        modelIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.isPinned = false
        self.providerIDString = providerID?.uuidString
        self.modelIdentifier = modelIdentifier
    }
}
