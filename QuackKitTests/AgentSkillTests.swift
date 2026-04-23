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

import Testing
import Foundation
@testable import QuackInterface

@Suite("AgentSkill Model")
struct AgentSkillTests {

    @Test("Default initialization sets expected values")
    func defaultInit() {
        let skill = AgentSkill(
            name: "test-skill",
            source: "https://github.com/owner/repo",
            skillDescription: "A test skill",
            isEnabled: true
        )

        #expect(skill.name == "test-skill")
        #expect(skill.source == "https://github.com/owner/repo")
        #expect(skill.skillDescription == "A test skill")
        #expect(skill.isEnabled == true)
        #expect(skill.contentHash == nil)
        #expect(skill.contentPath == nil)
    }
}

@Suite("Always-Enabled Skills")
struct AlwaysEnabledSkillsTests {

    @Test("Assistant alwaysEnabledSkillNames returns nil when raw is nil")
    func assistantNil() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.alwaysEnabledSkillNames == nil)
    }

    @Test("Assistant alwaysEnabledSkillNames round-trips")
    func assistantRoundTrip() {
        let assistant = Assistant(name: "Test")
        assistant.alwaysEnabledSkillNames = ["swiftui-pro", "caveman"]
        #expect(assistant.alwaysEnabledSkillNames == ["swiftui-pro", "caveman"])
        #expect(assistant.alwaysEnabledSkillNamesRaw == "swiftui-pro,caveman")
    }

    @Test("ChatSession copies alwaysEnabledSkillNames from assistant")
    func sessionCopiesFromAssistant() {
        let assistant = Assistant(name: "Test")
        assistant.alwaysEnabledSkillNames = ["swiftui-pro"]

        let session = ChatSession(assistant: assistant)
        #expect(session.alwaysEnabledSkillNames == ["swiftui-pro"])
    }

    @Test("ChatSession alwaysEnabledSkillNames defaults to nil")
    func sessionDefaultNil() {
        let session = ChatSession()
        #expect(session.alwaysEnabledSkillNames == nil)
    }

    @Test("Setting to nil clears raw")
    func nilClearsRaw() {
        let assistant = Assistant(name: "Test")
        assistant.alwaysEnabledSkillNames = ["test"]
        assistant.alwaysEnabledSkillNames = nil
        #expect(assistant.alwaysEnabledSkillNamesRaw == nil)
    }
}
