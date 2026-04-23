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

/// An installed agent skill — a curated Markdown knowledge pack
/// that gets appended to the system prompt to give the LLM expert
/// domain knowledge.
///
/// Skills are sourced from Git repositories following the Agent
/// Skills open format (SKILL.md files). They are stored locally
/// in the app's Application Support directory.
@Model
public final class AgentSkill {
    public var id: UUID

    /// Human-readable skill name, extracted from SKILL.md front matter.
    /// e.g. "swiftui-pro"
    public var name: String

    /// The Git URL this skill was installed from.
    /// e.g. "https://github.com/twostraws/swiftui-agent-skill"
    public var source: String

    /// A short description of the skill, extracted from SKILL.md front matter.
    public var skillDescription: String?

    /// SHA-256 hash of the SKILL.md content, used for cache invalidation
    /// and update checking.
    public var contentHash: String?

    /// Whether this skill is globally enabled. Disabled skills are installed
    /// but not available for selection in assistants or sessions.
    public var isEnabled: Bool

    /// When the skill was first installed.
    public var installedAt: Date

    /// When the skill content was last updated.
    public var updatedAt: Date

    /// Relative path within the App Support skills directory.
    /// e.g. "skills/swiftui-pro"
    public var contentPath: String?

    public init(
        name: String = "",
        source: String = "",
        skillDescription: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.source = source
        self.skillDescription = skillDescription
        self.isEnabled = isEnabled
        self.installedAt = Date()
        self.updatedAt = Date()
    }
}
