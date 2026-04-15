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

/// Built-in tool that searches the web using the Tavily Search API and returns
/// relevant results optimized for LLM consumption.
public struct WebSearchTool: AnyTool, Sendable {
    public typealias Context = EmptyContext

    public var name: String { "builtin-web_search" }
    public var description: String {
        "Search the web for information using a query. Returns relevant results with titles, URLs, and content snippets."
    }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "query": .string(description: "The search query to execute."),
                "max_results": .integer(description: "Maximum number of results to return (1-20). Defaults to 5.").optional(),
                "topic": .string(
                    description: "The category of the search: \"general\" or \"news\". Defaults to \"general\".",
                    enumValues: ["general", "news"]
                ).optional(),
                "search_depth": .string(
                    description: "Controls the depth of the search: \"basic\" for faster results or \"advanced\" for more detailed results. Defaults to \"basic\".",
                    enumValues: ["basic", "advanced"]
                ).optional(),
                "include_domains": .array(
                    items: .string(),
                    description: "A list of domains to specifically include in the search results."
                ).optional(),
                "exclude_domains": .array(
                    items: .string(),
                    description: "A list of domains to specifically exclude from the search results."
                ).optional(),
            ],
            required: ["query"]
        )
    }

    public func execute(arguments: Data, context: EmptyContext) async throws -> ToolResult {
        struct Args: Decodable {
            let query: String
            let max_results: Int?
            let topic: String?
            let search_depth: String?
            let include_domains: [String]?
            let exclude_domains: [String]?
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"query\": \"...\" }")
        }

        guard !args.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .error("Search query must not be empty.")
        }

        // Read the Tavily API key, obfuscated at build time from the
        // TAVILY_API_KEY setting in Secrets.xcconfig.
        guard let apiKey = SecretsProvider.tavilyAPIKey, !apiKey.isEmpty else {
            return .error(
                "No Tavily API key configured. Set TAVILY_API_KEY in Secrets.xcconfig and rebuild."
            )
        }

        // Build the request body
        var body: [String: Any] = [
            "query": args.query,
            "include_answer": true,
            "max_results": min(max(args.max_results ?? 5, 1), 20),
        ]

        if let topic = args.topic {
            body["topic"] = topic
        }
        if let searchDepth = args.search_depth {
            body["search_depth"] = searchDepth
        }
        if let includeDomains = args.include_domains, !includeDomains.isEmpty {
            body["include_domains"] = includeDomains
        }
        if let excludeDomains = args.exclude_domains, !excludeDomains.isEmpty {
            body["exclude_domains"] = excludeDomains
        }

        guard let url = URL(string: "https://api.tavily.com/search") else {
            return .error("Internal error: invalid Tavily API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .error("Failed to encode request: \(error.localizedDescription)")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Unexpected response type.")
            }

            switch httpResponse.statusCode {
            case 200..<300:
                break
            case 401:
                return .error(
                    "Tavily API key is invalid or missing. Please check your key in Settings > Tools."
                )
            case 429:
                return .error("Tavily rate limit exceeded. Please try again later.")
            case 432:
                return .error("Tavily API credit limit exceeded. Please check your Tavily account.")
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "(no response body)"
                return .error("Tavily API error (HTTP \(httpResponse.statusCode)): \(errorBody)")
            }

            return try formatResults(data: data)
        } catch {
            return .error("Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Response Formatting

    private func formatResults(data: Data) throws -> ToolResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .error("Failed to parse Tavily response.")
        }

        var output = ""

        // Include the AI-generated answer if present
        if let answer = json["answer"] as? String, !answer.isEmpty {
            output += "## Answer\n\n\(answer)\n\n"
        }

        // Format individual results
        if let results = json["results"] as? [[String: Any]], !results.isEmpty {
            output += "## Search Results\n\n"

            for (index, result) in results.enumerated() {
                let title = result["title"] as? String ?? "Untitled"
                let url = result["url"] as? String ?? ""
                let content = result["content"] as? String ?? ""

                output += "### \(index + 1). \(title)\n"
                if !url.isEmpty {
                    output += "URL: \(url)\n"
                }
                if !content.isEmpty {
                    output += "\(content)\n"
                }
                output += "\n"
            }
        } else {
            output += "No results found.\n"
        }

        // Truncate if excessively large
        let maxLength = 100_000
        if output.count > maxLength {
            let truncated = String(output.prefix(maxLength))
            return .success(truncated + "\n\n[Truncated: response was \(output.count) characters]")
        }

        return .success(output)
    }
}
