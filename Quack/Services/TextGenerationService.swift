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
import FoundationModels

/// Generates text using the on-device Foundation Model for various purposes
/// such as chat titles and system prompts.
///
/// Falls back to simple heuristics when the model is unavailable.
enum TextGenerationService {

    // MARK: - Chat Titles

    /// Generate a short title for a chat session based on the user's first message.
    ///
    /// Uses the on-device Foundation Model to summarize the message into a concise
    /// title (a few words). Falls back to truncating the message if the model is
    /// unavailable or generation fails.
    @MainActor
    static func generateTitle(for message: String) async -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return truncatedTitle(from: message)
        }

        do {
            let session = LanguageModelSession(instructions: """
                Generate a short, descriptive title (3 to 7 words) that summarizes \
                the topic of the user's message. Respond with only the title text, \
                no quotes, no punctuation at the end, no extra explanation.
                """)
            let response = try await session.respond(to: message)
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? truncatedTitle(from: message) : title
        } catch {
            return truncatedTitle(from: message)
        }
    }

    /// Simple fallback: first 50 characters of the message with ellipsis if truncated.
    private static func truncatedTitle(from text: String) -> String {
        var title = String(text.prefix(50))
        if text.count > 50 { title += "..." }
        return title
    }

    // MARK: - System Prompts

    /// Generate a system prompt from a natural language description of an assistant.
    ///
    /// Uses the on-device Foundation Model to produce a detailed system prompt
    /// defining the assistant's role, behavior, and guidelines. Falls back to a
    /// simple template if the model is unavailable or generation fails.
    @MainActor
    static func generateSystemPrompt(from description: String) async -> String {
        let fallback = "You are \(description)."

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return fallback
        }

        do {
            let session = LanguageModelSession(instructions: """
                You are a system prompt writer. Given a description of an AI assistant, \
                generate a clear, detailed system prompt that defines the assistant's \
                role, behavior, and guidelines. Write in second person \
                (e.g. "You are..."). Be concise but thorough. Respond with only the \
                system prompt text, no extra explanation or formatting.
                """)
            let response = try await session.respond(to: description)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? fallback : result
        } catch {
            return fallback
        }
    }
}
