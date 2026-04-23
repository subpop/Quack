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
import AgentRunKit
import QuackInterface

/// Loads a skill's full instructions on demand.
///
/// This tool implements the Agent Skills progressive disclosure model:
/// the system prompt contains a lightweight catalog of available skills
/// (name + description), and when the model determines a skill is
/// relevant to the current task, it calls this tool to load the full
/// instructions.
///
/// The tool returns the SKILL.md body (with frontmatter stripped),
/// wrapped in identifying tags, along with a list of bundled resources
/// that the model can load individually via file-read tools.
public struct ActivateSkillTool: AnyTool, Sendable {
    public typealias Context = QuackToolContext

    public var name: String { "builtin-activate_skill" }

    public var description: String {
        "Load a skill's full instructions. Call this when a task matches an available skill's description."
    }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "name": .string(description: "The name of the skill to activate, as listed in available_skills."),
            ],
            required: ["name"]
        )
    }

    // Skills are read-only knowledge packs — no side effects.
    public var isReadOnly: Bool { true }

    public func execute(arguments: Data, context: QuackToolContext) async throws -> ToolResult {
        struct Args: Decodable {
            let name: String
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"name\": \"<skill-name>\" }")
        }

        let skillName = args.name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Access the SkillService singleton
        // TODO: Replace with custom ToolContext when feasible
        guard let service = await SkillService.shared else {
            return .error("Skill service is not available.")
        }

        // Read skill content
        guard let rawContent = await service.skillContent(forName: skillName) else {
            let available = await service.allDiscoveredSkills.map(\.name).joined(separator: ", ")
            return .error("Unknown skill: \"\(skillName)\". Available skills: \(available)")
        }

        // Strip YAML frontmatter
        let body = await service.stripFrontMatter(rawContent)

        // Get the base directory and enumerate resources
        let baseDir = await service.skillBaseDirectory(forName: skillName)
        let resources = await service.enumerateResources(forName: skillName)

        // Build structured response
        var result = "<skill_content name=\"\(skillName)\">\n"
        result += body

        if let dir = baseDir {
            result += "\n\nSkill directory: \(dir.path)"
            result += "\nRelative paths in this skill are relative to the skill directory."
        }

        if !resources.isEmpty {
            result += "\n\n<skill_resources>"
            for resource in resources {
                result += "\n<file>\(resource)</file>"
            }
            result += "\n</skill_resources>"
        }

        result += "\n</skill_content>"

        return .success(result)
    }
}
