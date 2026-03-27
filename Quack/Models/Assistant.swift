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
import SwiftUI

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

    /// Background color stored as a raw string key (e.g. "blue", "orange").
    /// nil defaults to the accent color.
    var colorRaw: String?

    // Parameters
    var temperature: Double?
    var maxTokens: Int?
    var reasoningEffort: String?
    var compactionThreshold: Double?
    var maxMessages: Int?
    var maxToolRounds: Int?

    // MCP server IDs enabled by default (stored as comma-separated UUIDs)
    var enabledMCPServerIDsRaw: String?

    /// Per-tool permission defaults for this assistant.
    /// JSON-encoded `[String: String]` mapping tool name -> ToolPermission raw value.
    /// When a new ChatSession is created from this assistant, these defaults are
    /// copied into the session's `toolPermissionOverridesJSON`. The session can then
    /// override them independently via the inspector.
    var toolPermissionDefaultsJSON: String?

    /// The provider profile UUID for this assistant, if set.
    var providerID: UUID? {
        get {
            guard let str = providerIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { providerIDString = newValue?.uuidString }
    }

    /// Per-tool permission defaults. Key is the tool name, value is the permission.
    /// Returns nil if no defaults are set (use server-level defaults for everything).
    var toolPermissionDefaults: [String: ToolPermission]? {
        get {
            guard let json = toolPermissionDefaultsJSON,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return nil }
            let mapped = dict.compactMapValues { ToolPermission(rawValue: $0) }
            return mapped.isEmpty ? nil : mapped
        }
        set {
            guard let newValue, !newValue.isEmpty else {
                toolPermissionDefaultsJSON = nil
                return
            }
            let raw = newValue.mapValues(\.rawValue)
            guard let data = try? JSONEncoder().encode(raw),
                  let json = String(data: data, encoding: .utf8)
            else {
                toolPermissionDefaultsJSON = nil
                return
            }
            toolPermissionDefaultsJSON = json
        }
    }

    /// Get the effective default permission for a specific tool in this assistant.
    /// Checks assistant-level per-tool override first, then falls back to the server default.
    func effectivePermission(for toolName: String, serverDefault: ToolPermission) -> ToolPermission {
        toolPermissionDefaults?[toolName] ?? serverDefault
    }

    /// Set a per-tool permission default for this assistant.
    /// If the new value matches the server default, the override is removed (keeping storage clean).
    func setToolPermission(_ permission: ToolPermission?, for toolName: String, serverDefault: ToolPermission) {
        var defaults = toolPermissionDefaults ?? [:]
        if let permission, permission != serverDefault {
            defaults[toolName] = permission
        } else {
            defaults.removeValue(forKey: toolName)
        }
        toolPermissionDefaults = defaults.isEmpty ? nil : defaults
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

    /// The resolved icon SF Symbol name, falling back to a default.
    var resolvedIcon: String {
        iconName ?? "person.crop.circle.fill"
    }

    /// The resolved background color for the assistant badge.
    var resolvedColor: Color {
        guard let key = colorRaw else { return .accentColor }
        return Self.colorPalette[key] ?? .accentColor
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
        let a = Assistant(
            name: "General",
            systemPrompt: "You are a helpful assistant.",
            isDefault: true,
            sortOrder: 0
        )
        a.iconName = "bubble.left.and.bubble.right.fill"
        a.colorRaw = "blue"
        return a
    }

    // MARK: - Color Palette

    /// The available background colors for assistant badges.
    static let colorPalette: [String: Color] = [
        "gray": .gray,
        "blue": .blue,
        "purple": .purple,
        "pink": .pink,
        "red": .red,
        "orange": .orange,
        "yellow": .yellow,
        "green": .green,
        "mint": .mint,
        "teal": .teal,
        "cyan": .cyan,
        "indigo": .indigo,
        "brown": .brown,
    ]

    /// Ordered keys for display in the color picker.
    static let colorKeys: [String] = [
        "gray", "brown", "red", "orange", "yellow",
        "green", "mint", "teal", "cyan", "blue",
        "indigo", "purple", "pink",
    ]

    // MARK: - Icon Choices

    /// A curated set of SF Symbol names suitable for assistant icons.
    static let iconChoices: [String] = [
        "person.crop.circle.fill",
        "bubble.left.and.bubble.right.fill",
        "brain.head.profile.fill",
        "sparkles",
        "lightbulb.fill",
        "book.fill",
        "hammer.fill",
        "wrench.and.screwdriver.fill",
        "terminal.fill",
        "chevron.left.forwardslash.chevron.right",
        "doc.text.fill",
        "pencil.and.outline",
        "magnifyingglass",
        "globe",
        "graduationcap.fill",
        "text.bubble.fill",
        "star.fill",
        "bolt.fill",
        "cpu.fill",
        "shield.fill",
    ]
}
