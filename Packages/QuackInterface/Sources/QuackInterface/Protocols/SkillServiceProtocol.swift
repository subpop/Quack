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

// MARK: - Protocol

@MainActor
public protocol SkillServiceProtocol: AnyObject, Observable {
    /// All installed skills (both enabled and disabled) from SwiftData.
    var installedSkills: [AgentSkill] { get }

    /// All discovered skills from filesystem scanning + Library store.
    /// These are the skills available for catalog disclosure.
    var discoveredSkills: [DiscoveredSkillInfo] { get }

    /// Error message from the last failed operation, if any.
    var lastError: String? { get }

    /// Whether an install or update operation is in progress.
    var isProcessing: Bool { get }

    /// Scan all skill directories and rebuild the discovered skills list.
    func scanForSkills()

    /// Download a repository and discover all skills it contains, without installing them.
    ///
    /// Returns a list of skill previews that can be presented to the user for selection.
    /// For single-skill repos this returns one entry.
    func discoverSkills(from source: String) async throws -> [DiscoverableSkill]

    /// Install previously discovered skills by name.
    ///
    /// - Parameter skills: The skill previews to install (from `discoverSkills`).
    /// - Parameter source: The normalized "owner/repo" source string.
    /// - Parameter modelContext: The SwiftData model context for persistence.
    func installDiscoveredSkills(
        _ skills: [DiscoverableSkill],
        from source: String,
        modelContext: ModelContext
    ) throws

    /// Install all skills from a GitHub repository (convenience method).
    /// - Parameter source: GitHub repo in "owner/repo" format.
    /// - Parameter modelContext: The SwiftData model context for persistence.
    func installSkill(from source: String, modelContext: ModelContext) async throws

    /// Uninstall a skill, removing its cached content and SwiftData record.
    func uninstallSkill(_ skill: AgentSkill, modelContext: ModelContext)

    /// Check for and apply updates for a specific skill.
    func updateSkill(_ skill: AgentSkill, modelContext: ModelContext) async throws

    /// Enable or disable a skill globally.
    func setEnabled(_ enabled: Bool, for skill: AgentSkill, modelContext: ModelContext)

    /// Read the SKILL.md content for a discovered skill by name.
    func skillContent(forName name: String) -> String?

    /// Read the SKILL.md content for a specific installed skill by ID.
    func skillContent(for skillID: UUID) -> String?

    /// Read the SKILL.md content for a specific installed skill.
    func skillContent(for skill: AgentSkill) -> String?

    /// Get the file size of the SKILL.md for a specific skill.
    func skillFileSize(for skill: AgentSkill) -> Int?

    /// Compose a system prompt with always-enabled skills injected directly
    /// and remaining skills listed in a lightweight catalog.
    ///
    /// - Parameter basePrompt: The user's system prompt (may be nil).
    /// - Parameter alwaysEnabledSkillNames: Skill names whose full content
    ///   should be injected directly into the prompt.
    /// - Returns: The composed system prompt, or nil if there are no skills
    ///   and no base prompt.
    func composedSystemPrompt(
        basePrompt: String?,
        alwaysEnabledSkillNames: [String]
    ) -> String?

    /// Reload installed skills from the model context.
    func reloadSkills(modelContext: ModelContext)
}

// MARK: - Discovered Skill Info (Protocol-level type)

/// Lightweight description of a discovered skill for protocol consumers.
public struct DiscoveredSkillInfo: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let locationPath: String

    public init(name: String, description: String, locationPath: String) {
        self.name = name
        self.description = description
        self.locationPath = locationPath
    }
}

// MARK: - Discoverable Skill (Install Preview)

/// A skill found during repository download, before installation.
/// Used by the skill picker UI to let the user choose which skills to install.
public struct DiscoverableSkill: Identifiable, Sendable, Hashable {
    public var id: String { name }
    public let name: String
    public let description: String?

    public init(name: String, description: String?) {
        self.name = name
        self.description = description
    }
}

// MARK: - Environment Key

private struct SkillServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any SkillServiceProtocol = PlaceholderSkillService()
}

public extension EnvironmentValues {
    var skillService: any SkillServiceProtocol {
        get { self[SkillServiceKey.self] }
        set { self[SkillServiceKey.self] = newValue }
    }
}

// MARK: - Placeholder

@Observable
@MainActor
private final class PlaceholderSkillService: SkillServiceProtocol {
    var installedSkills: [AgentSkill] = []
    var discoveredSkills: [DiscoveredSkillInfo] = []
    var lastError: String? = nil
    var isProcessing: Bool = false

    func scanForSkills() {}
    func discoverSkills(from source: String) async throws -> [DiscoverableSkill] { [] }
    func installDiscoveredSkills(_ skills: [DiscoverableSkill], from source: String, modelContext: ModelContext) throws {}
    func installSkill(from source: String, modelContext: ModelContext) async throws {}
    func uninstallSkill(_ skill: AgentSkill, modelContext: ModelContext) {}
    func updateSkill(_ skill: AgentSkill, modelContext: ModelContext) async throws {}
    func setEnabled(_ enabled: Bool, for skill: AgentSkill, modelContext: ModelContext) {}
    func skillContent(forName name: String) -> String? { nil }
    func skillContent(for skillID: UUID) -> String? { nil }
    func skillContent(for skill: AgentSkill) -> String? { nil }
    func skillFileSize(for skill: AgentSkill) -> Int? { nil }
    func composedSystemPrompt(basePrompt: String?, alwaysEnabledSkillNames: [String]) -> String? { basePrompt }
    func reloadSkills(modelContext: ModelContext) {}
}
