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
import Observation
import SwiftData
import QuackInterface

/// A minimal no-op ``SkillServiceProtocol`` implementation for SwiftUI previews.
@Observable
@MainActor
final class PreviewSkillService: SkillServiceProtocol {
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
