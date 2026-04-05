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

/// Built-in tool that fetches the content of a URL and returns the response body.
struct WebFetchTool: AnyTool, Sendable {
    typealias Context = EmptyContext

    var name: String { "builtin-web_fetch" }
    var description: String { "Fetch the content of a URL and return the response body." }

    var parametersSchema: JSONSchema {
        .object(
            properties: [
                "url": .string(description: "The URL to fetch."),
            ],
            required: ["url"]
        )
    }

    func execute(arguments: Data, context: EmptyContext) async throws -> ToolResult {
        struct Args: Decodable {
            let url: String
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"url\": \"...\" }")
        }

        guard let url = URL(string: args.url) else {
            return .error("Invalid URL: \(args.url)")
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return .error("Only HTTP and HTTPS URLs are supported.")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Unexpected response type.")
            }

            let statusCode = httpResponse.statusCode

            guard (200..<400).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "(non-text response)"
                return .error("HTTP \(statusCode): \(body)")
            }

            guard let body = String(data: data, encoding: .utf8) else {
                return .error("Response body is not valid UTF-8 text (\(data.count) bytes).")
            }

            // Truncate very large responses to avoid overwhelming the context
            let maxLength = 100_000
            if body.count > maxLength {
                let truncated = String(body.prefix(maxLength))
                return .success(truncated + "\n\n[Truncated: response was \(body.count) characters]")
            }

            return .success(body)
        } catch {
            return .error("Fetch failed: \(error.localizedDescription)")
        }
    }
}
