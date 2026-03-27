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
