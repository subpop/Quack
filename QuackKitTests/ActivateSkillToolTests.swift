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
import AgentRunKit
@testable import QuackKit
@testable import QuackInterface

@Suite("ActivateSkillTool")
struct ActivateSkillToolTests {

    @Test("Tool name matches BuiltInTool raw value")
    func toolName() {
        let tool = ActivateSkillTool()
        #expect(tool.name == "builtin-activate_skill")
        #expect(tool.name == BuiltInTool.activateSkill.rawValue)
    }

    @Test("Tool is read-only")
    func isReadOnly() {
        let tool = ActivateSkillTool()
        #expect(tool.isReadOnly == true)
    }

    @Test("Tool has a description")
    func hasDescription() {
        let tool = ActivateSkillTool()
        #expect(!tool.description.isEmpty)
    }

    @Test("Returns error for invalid arguments")
    func invalidArguments() async throws {
        let tool = ActivateSkillTool()
        let badArgs = Data("{}".utf8)
        let result = try await tool.execute(arguments: badArgs, context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("Invalid arguments"))
    }

    @Test("Returns error when service is not available")
    @MainActor
    func noService() async throws {
        // Ensure no singleton is set
        let previousService = SkillService.shared
        SkillService.shared = nil
        defer { SkillService.shared = previousService }

        let tool = ActivateSkillTool()
        let args = try JSONEncoder().encode(["name": "test-skill"])
        let result = try await tool.execute(arguments: args, context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("not available"))
    }

    @Test("Returns error for unknown skill name")
    @MainActor
    func unknownSkill() async throws {
        let service = SkillService()
        let previousService = SkillService.shared
        SkillService.shared = service
        defer { SkillService.shared = previousService }

        let tool = ActivateSkillTool()
        let args = try JSONEncoder().encode(["name": "nonexistent-skill"])
        let result = try await tool.execute(arguments: args, context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("Unknown skill"))
    }
}
