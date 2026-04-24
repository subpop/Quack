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
public final class Assistant {
    public var id: UUID
    public var name: String
    public var systemPrompt: String?
    public var providerIDString: String?
    public var modelIdentifier: String?
    public var isDefault: Bool
    public var sortOrder: Int
    public var iconName: String?

    /// Background color stored as a raw string key (e.g. "blue", "orange").
    /// nil defaults to the accent color.
    public var colorRaw: String?

    // Parameters
    public var temperature: Double?
    public var maxTokens: Int?
    public var reasoningEffort: String?
    public var compactionThreshold: Double?
    public var maxMessages: Int?
    public var maxToolRounds: Int?

    // MCP server IDs enabled by default (stored as comma-separated UUIDs)
    public var enabledMCPServerIDsRaw: String?

    // Built-in tool IDs enabled by default (stored as comma-separated IDs)
    public var enabledBuiltInToolIDsRaw: String?

    // Skill names that are always loaded into the system prompt (stored as comma-separated names)
    public var alwaysEnabledSkillNamesRaw: String?

    /// Per-tool permission defaults for this assistant.
    /// JSON-encoded `[String: String]` mapping tool name -> ToolPermission raw value.
    /// When a new ChatSession is created from this assistant, these defaults are
    /// copied into the session's `toolPermissionOverridesJSON`. The session can then
    /// override them independently via the inspector.
    public var toolPermissionDefaultsJSON: String?

    /// The provider profile UUID for this assistant, if set.
    public var providerID: UUID? {
        get {
            guard let str = providerIDString else { return nil }
            return UUID(uuidString: str)
        }
        set { providerIDString = newValue?.uuidString }
    }

    /// Per-tool permission defaults. Key is the tool name, value is the permission.
    /// Returns nil if no defaults are set (use server-level defaults for everything).
    public var toolPermissionDefaults: [String: ToolPermission]? {
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
    public func effectivePermission(for toolName: String, serverDefault: ToolPermission) -> ToolPermission {
        toolPermissionDefaults?[toolName] ?? serverDefault
    }

    /// Set a per-tool permission default for this assistant.
    /// If the new value matches the server default, the override is removed (keeping storage clean).
    public func setToolPermission(_ permission: ToolPermission?, for toolName: String, serverDefault: ToolPermission) {
        var defaults = toolPermissionDefaults ?? [:]
        if let permission, permission != serverDefault {
            defaults[toolName] = permission
        } else {
            defaults.removeValue(forKey: toolName)
        }
        toolPermissionDefaults = defaults.isEmpty ? nil : defaults
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

    /// Built-in tool IDs enabled by default for new sessions created from this assistant.
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

    /// Skill names that are always loaded into the system prompt for sessions
    /// created from this assistant. These skills have their full SKILL.md content
    /// injected directly, rather than appearing only in the catalog for on-demand
    /// activation.
    public var alwaysEnabledSkillNames: [String]? {
        get {
            guard let raw = alwaysEnabledSkillNamesRaw, !raw.isEmpty else { return nil }
            return raw.split(separator: ",").map(String.init)
        }
        set {
            alwaysEnabledSkillNamesRaw = newValue?.joined(separator: ",")
        }
    }

    /// The resolved icon SF Symbol name, falling back to a default.
    public var resolvedIcon: String {
        iconName ?? "person.crop.circle.fill"
    }

    /// The resolved background color for the assistant badge.
    public var resolvedColor: Color {
        guard let key = colorRaw else { return .accentColor }
        return Self.colorPalette[key] ?? .accentColor
    }

    public init(
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
    public static func defaultAssistant() -> Assistant {
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

    /// Create the built-in coding assistant seeded on first launch.
    public static func codingAssistant() -> Assistant {
        let a = Assistant(
            name: "Coding",
            systemPrompt: """
            You are an expert software engineering assistant. Help the user with coding tasks including writing, debugging, refactoring, and explaining code.

            When working on code:
            - Follow existing project conventions, patterns, and naming schemes.
            - Never assume a library or dependency is available without verifying.
            - Match the code style already established in the project (indentation, naming, structure).
            - Prefer editing existing files over creating new ones unless a new file is clearly needed.
            - Add comments sparingly. When you do, explain *why*, not *what*.

            When referencing specific code, include the file path and line number (e.g. `src/main.swift:42`) so the user can navigate to it easily.

            After making changes, verify correctness by running tests, linters, or type-checkers when applicable.

            Never run destructive or irreversible git commands unless the user explicitly asks. Never commit changes unless explicitly asked.
            """,
            sortOrder: 1
        )
        a.iconName = "chevron.left.forwardslash.chevron.right"
        a.colorRaw = "purple"
        return a
    }

    // MARK: - Color Palette

    /// The available background colors for assistant badges.
    public static let colorPalette: [String: Color] = [
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
    public static let colorKeys: [String] = [
        "gray", "brown", "red", "orange", "yellow",
        "green", "mint", "teal", "cyan", "blue",
        "indigo", "purple", "pink",
    ]

    // MARK: - Icon Choices

    /// A curated set of SF Symbol names suitable for assistant icons.
    public static let iconChoices: [String] = [
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
