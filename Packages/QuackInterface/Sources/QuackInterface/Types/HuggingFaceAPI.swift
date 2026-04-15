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
import os

/// Lightweight client for the HuggingFace Hub REST API.
///
/// Used to search for MLX-compatible models from the `mlx-community`
/// organization. No authentication is required for public model listing.
public enum HuggingFaceAPI {
    private static let baseURL = URL(string: "https://huggingface.co/api/models")!
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.subpop.Quack",
        category: "HuggingFaceAPI"
    )

    /// A model entry from the HuggingFace API.
    public struct Model: Decodable, Identifiable, Sendable {
        public let id: String
        public let downloads: Int
        public let likes: Int
        public let tags: [String]

        enum CodingKeys: String, CodingKey {
            case id
            case downloads
            case likes
            case tags
        }

        /// Short display name without the org prefix.
        public var shortName: String {
            if let slashIndex = id.firstIndex(of: "/") {
                return String(id[id.index(after: slashIndex)...])
            }
            return id
        }

        /// Quantization tag extracted from the tags array, if any.
        public var quantization: String? {
            tags.first { tag in
                tag.hasSuffix("-bit") || tag == "bf16" || tag == "fp16" || tag == "fp32"
            }
        }

        /// Formatted download count (e.g. "1.2M", "456K", "89").
        public var formattedDownloads: String {
            if downloads >= 1_000_000 {
                return String(format: "%.1fM", Double(downloads) / 1_000_000)
            } else if downloads >= 1_000 {
                return String(format: "%.0fK", Double(downloads) / 1_000)
            }
            return "\(downloads)"
        }
    }

    /// Search for MLX text-generation models on HuggingFace.
    ///
    /// - Parameters:
    ///   - query: Optional search term to filter results.
    ///   - limit: Maximum number of results (default 50).
    /// - Returns: An array of model entries sorted by downloads (descending).
    public static func searchMLXModels(
        query: String? = nil,
        limit: Int = 50
    ) async throws -> [Model] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "author", value: "mlx-community"),
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "library", value: "mlx"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]

        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: query))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("HuggingFace API returned \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }

        let models = try JSONDecoder().decode([Model].self, from: data)
        logger.info("Fetched \(models.count) MLX models from HuggingFace")
        return models
    }
}
