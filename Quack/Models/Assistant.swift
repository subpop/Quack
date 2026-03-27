import Foundation
import SwiftData

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

    // Parameters
    var temperature: Double?
    var maxTokens: Int?
    var reasoningEffort: String?
    var compactionThreshold: Double?
    var maxMessages: Int?

    // MCP server IDs enabled by default (stored as comma-separated UUIDs)
    var enabledMCPServerIDsRaw: String?

    /// The provider profile UUID for this assistant, if set.
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

    init(
        name: String = "",
        systemPrompt: String? = nil,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }

    /// Create the built-in default assistant seeded on first launch.
    static func defaultAssistant() -> Assistant {
        Assistant(
            name: "General",
            systemPrompt: "You are a helpful assistant.",
            isDefault: true,
            sortOrder: 0
        )
    }
}
