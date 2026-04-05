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

/// Built-in tool that reads the contents of a file at a given path.
struct ReadFileTool: AnyTool, Sendable {
    typealias Context = EmptyContext

    var name: String { "builtin-read_file" }
    var description: String { "Read the contents of a file at a given path." }

    var parametersSchema: JSONSchema {
        .object(
            properties: [
                "path": .string(description: "The absolute path to the file to read."),
            ],
            required: ["path"]
        )
    }

    func execute(arguments: Data, context: EmptyContext) async throws -> ToolResult {
        struct Args: Decodable {
            let path: String
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"path\": \"...\" }")
        }

        let expandedPath = NSString(string: args.path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .error("File not found: \(args.path)")
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .error("Permission denied: cannot read \(args.path)")
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return .success(content)
        } catch {
            return .error("Failed to read file: \(error.localizedDescription)")
        }
    }
}
