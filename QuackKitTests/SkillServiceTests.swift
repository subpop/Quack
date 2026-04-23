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
@testable import QuackKit
@testable import QuackInterface

@Suite("SkillService")
@MainActor
struct SkillServiceTests {

    @Test("composedSystemPrompt returns nil when no skills and no base prompt")
    func noSkillsNoBase() {
        let service = SkillService()
        let result = service.composedSystemPrompt(basePrompt: nil, alwaysEnabledSkillNames: [])
        #expect(result == nil)
    }

    @Test("composedSystemPrompt returns base prompt when no skills discovered")
    func basePromptOnly() {
        let service = SkillService()
        let result = service.composedSystemPrompt(
            basePrompt: "You are a helpful assistant.",
            alwaysEnabledSkillNames: []
        )
        #expect(result == "You are a helpful assistant.")
    }

    @Test("Service initializes with empty state")
    func initialState() {
        let service = SkillService()
        #expect(service.installedSkills.isEmpty)
        #expect(service.allDiscoveredSkills.isEmpty)
        #expect(service.isProcessing == false)
        #expect(service.lastError == nil)
    }

    @Test("stripFrontMatter removes YAML frontmatter")
    func stripFrontMatter() {
        let service = SkillService()
        let content = """
        ---
        name: test-skill
        description: A test skill.
        ---
        This is the body content.
        
        More content here.
        """
        let result = service.stripFrontMatter(content)
        #expect(result.hasPrefix("This is the body content."))
        #expect(!result.contains("---"))
        #expect(!result.contains("name:"))
    }

    @Test("stripFrontMatter returns content as-is when no frontmatter")
    func stripFrontMatterNoFrontMatter() {
        let service = SkillService()
        let content = "Just some content."
        let result = service.stripFrontMatter(content)
        #expect(result == "Just some content.")
    }

    @Test("parseFrontMatter extracts key-value pairs")
    func parseFrontMatter() {
        let service = SkillService()
        let content = """
        ---
        name: test-skill
        description: A test skill.
        license: MIT
        ---
        Body content
        """
        let result = service.parseFrontMatter(content)
        #expect(result["name"] == "test-skill")
        #expect(result["description"] == "A test skill.")
        #expect(result["license"] == "MIT")
    }

    @Test("parseFrontMatter strips surrounding quotes")
    func parseFrontMatterQuoted() {
        let service = SkillService()
        let content = """
        ---
        name: "quoted-name"
        version: "1.0"
        ---
        """
        let result = service.parseFrontMatter(content)
        #expect(result["name"] == "quoted-name")
        #expect(result["version"] == "1.0")
    }

    @Test("parseFrontMatter returns empty for content without frontmatter")
    func parseFrontMatterNone() {
        let service = SkillService()
        let result = service.parseFrontMatter("No frontmatter here.")
        #expect(result.isEmpty)
    }
}

@Suite("SkillError")
struct SkillErrorTests {

    @Test("SkillError provides descriptive error messages")
    func errorDescriptions() {
        let errors: [SkillError] = [
            .invalidSource("bad"),
            .alreadyInstalled("https://github.com/owner/repo"),
            .cloneFailed("https://github.com/owner/repo", "fatal: repository not found"),
            .gitNotFound,
            .noSkillMDFound("https://github.com/owner/repo"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("invalidSource includes the source in the message")
    func invalidSourceMessage() {
        let error = SkillError.invalidSource("bad-input")
        #expect(error.errorDescription!.contains("bad-input"))
    }

    @Test("cloneFailed includes the source in the message")
    func cloneFailedMessage() {
        let error = SkillError.cloneFailed("https://gitlab.com/owner/repo", "fatal: repository not found")
        #expect(error.errorDescription!.contains("https://gitlab.com/owner/repo"))
        #expect(error.errorDescription!.contains("fatal: repository not found"))
    }

    @Test("gitNotFound provides actionable message")
    func gitNotFoundMessage() {
        let error = SkillError.gitNotFound
        #expect(error.errorDescription!.contains("xcode-select"))
    }
}

@Suite("DiscoveredSkill")
@MainActor
struct DiscoveredSkillTests {

    @Test("DiscoveredSkill id is derived from name")
    func idFromName() {
        let skill = DiscoveredSkill(
            name: "test-skill",
            description: "A test skill",
            location: URL(fileURLWithPath: "/tmp/test/SKILL.md"),
            baseDirectory: URL(fileURLWithPath: "/tmp/test"),
            source: .userAgents
        )
        #expect(skill.id == "test-skill")
    }

    @Test("DiscoveredSkillInfo id is derived from name")
    func infoIdFromName() {
        let info = DiscoveredSkillInfo(
            name: "test-skill",
            description: "A test skill",
            locationPath: "/tmp/test/SKILL.md"
        )
        #expect(info.id == "test-skill")
    }
}
