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

/// Built-in tool that writes content to a file at a given path.
struct WriteFileTool: AnyTool, Sendable {
    typealias Context = EmptyContext

    var name: String { "builtin-write_file" }
    var description: String { "Write content to a file at a given path." }

    var parametersSchema: JSONSchema {
        .object(
            properties: [
                "path": .string(description: "The absolute path to the file to write."),
                "content": .string(description: "The content to write to the file."),
            ],
            required: ["path", "content"]
        )
    }

    func execute(arguments: Data, context: EmptyContext) async throws -> ToolResult {
        struct Args: Decodable {
            let path: String
            let content: String
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"path\": \"...\", \"content\": \"...\" }")
        }

        let expandedPath = NSString(string: args.path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Ensure the parent directory exists
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                return .error("Failed to create parent directory: \(error.localizedDescription)")
            }
        }

        do {
            try args.content.write(to: url, atomically: true, encoding: .utf8)
            return .success("Successfully wrote \(args.content.count) characters to \(args.path)")
        } catch {
            return .error("Failed to write file: \(error.localizedDescription)")
        }
    }
}
