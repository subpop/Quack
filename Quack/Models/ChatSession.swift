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
