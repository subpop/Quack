import Foundation
import AgentRunKit
import FoundationModels

/// A wrapper around Apple's FoundationModels framework that conforms to AgentRunKit's LLMClient.
struct FoundationModelsLLMClient: LLMClient, Sendable {
    let contextWindowSize: Int? = 4096

    func generate(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        responseFormat: ResponseFormat?,
        requestContext: RequestContext?
    ) async throws -> AssistantMessage {
        let session = LanguageModelSession()
        let prompt = buildPrompt(from: messages)
        let response = try await session.respond(to: prompt)
        return AssistantMessage(
            content: response.content,
            toolCalls: [],
            tokenUsage: nil,
            reasoning: nil
        )
    }

    func stream(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        requestContext: RequestContext?
    ) -> AsyncThrowingStream<StreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession()
                    let prompt = buildPrompt(from: messages)
                    var accumulated = ""
                    for try await chunk in session.streamResponse(to: prompt) {
                        let newContent = chunk.content
                        if newContent.count > accumulated.count {
                            let delta = String(newContent.dropFirst(accumulated.count))
                            accumulated = newContent
                            continuation.yield(.content(delta))
                        }
                    }
                    continuation.yield(.finished(usage: TokenUsage()))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildPrompt(from messages: [ChatMessage]) -> String {
        var parts: [String] = []
        for message in messages {
            switch message {
            case .system(let content):
                parts.append("[System] \(content)")
            case .user(let content):
                parts.append(content)
            case .assistant(let assistantMsg):
                parts.append(assistantMsg.content)
            case .tool(_, _, let content):
                parts.append("[Tool Result] \(content)")
            case .userMultimodal(let contentParts):
                let textParts = contentParts.compactMap { part -> String? in
                    switch part {
                    case .text(let text): return text
                    default: return nil
                    }
                }
                parts.append(textParts.joined(separator: "\n"))
            }
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - LLMProvider

extension FoundationModelsLLMClient: LLMProvider {
    static let kind: ProviderKind = .foundationModels

    static let requiresAPIKey: Bool = false
    static let requiresBaseURL: Bool = false

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)? {
        FoundationModelsLLMClient()
    }
}
