import Foundation
import AgentRunKit

/// An LLMClient implementation for Google's Gemini API (AI Studio).
///
/// This client targets the Google AI (AI Studio) endpoint using an API key.
/// For Vertex AI, use `VertexGeminiClient` instead.
///
/// Base URL: `https://generativelanguage.googleapis.com/v1beta/models`
///
/// URL construction:
///   `{baseURL}/{model}:generateContent`
///   `{baseURL}/{model}:streamGenerateContent?alt=sse`
nonisolated struct GeminiClient: LLMClient, Sendable {
    let modelIdentifier: String?
    let maxOutputTokens: Int
    let contextWindowSize: Int?
    let baseURL: URL
    let apiKey: String
    let session: URLSession
    let retryPolicy: RetryPolicy

    init(
        apiKey: String,
        model: String? = nil,
        maxOutputTokens: Int = 8192,
        contextWindowSize: Int? = nil,
        baseURL: URL,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.apiKey = apiKey
        self.modelIdentifier = model
        self.maxOutputTokens = maxOutputTokens
        self.contextWindowSize = contextWindowSize
        self.baseURL = baseURL
        self.session = session
        self.retryPolicy = retryPolicy
    }

    // MARK: - LLMClient

    func generate(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        responseFormat: ResponseFormat?,
        requestContext: RequestContext?
    ) async throws -> AssistantMessage {
        let geminiRequest = buildGeminiRequest(messages: messages, tools: tools)
        let urlRequest = try buildURLRequest(for: "generateContent", body: geminiRequest)

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw AgentError.llmError(.httpError(statusCode: httpResponse.statusCode, body: body))
        }

        return try parseResponse(data)
    }

    func stream(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        requestContext: RequestContext?
    ) -> AsyncThrowingStream<StreamDelta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performStreamRequest(
                        messages: messages,
                        tools: tools,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Request Building

    func buildGeminiRequest(
        messages: [ChatMessage],
        tools: [ToolDefinition]
    ) -> GeminiRequest {
        let mapped = GeminiMessageMapper.mapMessages(messages)
        let geminiTools = GeminiMessageMapper.mapTools(tools)
        let toolConfig: GeminiToolConfig? = geminiTools != nil
            ? GeminiToolConfig(functionCallingConfig: GeminiFunctionCallingConfig(mode: "AUTO"))
            : nil

        return GeminiRequest(
            contents: mapped.contents,
            systemInstruction: mapped.systemInstruction,
            tools: geminiTools,
            toolConfig: toolConfig,
            generationConfig: GeminiGenerationConfig(
                maxOutputTokens: maxOutputTokens,
                temperature: nil,
                topP: nil,
                thinkingConfig: nil
            )
        )
    }

    /// Builds a URLRequest for the Gemini API with API key auth.
    func buildURLRequest(for action: String, body: some Encodable) throws -> URLRequest {
        let model = modelIdentifier ?? "gemini-2.0-flash"

        // Build the URL by string concatenation to avoid percent-encoding the colon
        // in "{model}:{action}" (URL.appendingPathComponent encodes ":" to "%3A").
        var baseString = baseURL.absoluteString
        if !baseString.hasSuffix("/") { baseString += "/" }
        var urlString = "\(baseString)\(model):\(action)"

        // For streaming, append ?alt=sse to get SSE format
        if action.contains("stream") {
            urlString += "?alt=sse"
        }

        guard let url = URL(string: urlString) else {
            throw AgentError.llmError(.other("Invalid URL: \(urlString)"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AgentError.llmError(.encodingFailed(error))
        }

        return request
    }

    // MARK: - Response Parsing

    func parseResponse(_ data: Data) throws -> AssistantMessage {
        let response: GeminiResponse
        do {
            response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            // Try to decode as an error response
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                throw AgentError.llmError(.other(
                    "\(errorResponse.error.status ?? "ERROR"): \(errorResponse.error.message ?? "Unknown error")"
                ))
            }
            throw AgentError.llmError(.decodingFailed(error))
        }

        // Check for API errors in the response
        if let error = response.error {
            throw AgentError.llmError(.other(
                "\(error.status ?? "ERROR"): \(error.message ?? "Unknown error")"
            ))
        }

        guard let candidate = response.candidates?.first,
              let content = candidate.content else {
            throw AgentError.llmError(.noChoices)
        }

        return extractAssistantMessage(from: content.parts, usageMetadata: response.usageMetadata)
    }

    /// Extract an `AssistantMessage` from a complete set of Gemini parts.
    func extractAssistantMessage(
        from parts: [GeminiPart],
        usageMetadata: GeminiUsageMetadata?
    ) -> AssistantMessage {
        var textContent = ""
        var reasoningContent = ""
        var toolCalls: [ToolCall] = []

        for part in parts {
            switch part {
            case let .text(text, thought):
                if thought == true {
                    if !reasoningContent.isEmpty { reasoningContent += "\n" }
                    reasoningContent += text
                } else {
                    textContent += text
                }

            case let .functionCall(call):
                let arguments: String
                if let args = call.args {
                    let encoded = try? JSONEncoder().encode(args)
                    arguments = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                } else {
                    arguments = "{}"
                }
                toolCalls.append(ToolCall(
                    id: call.id ?? UUID().uuidString,
                    name: call.name,
                    arguments: arguments
                ))

            case .functionResponse, .inlineData:
                break  // Not expected in model responses
            }
        }

        let tokenUsage = usageMetadata.map { meta in
            TokenUsage(
                input: meta.promptTokenCount ?? 0,
                output: meta.candidatesTokenCount ?? 0,
                reasoning: meta.thoughtsTokenCount ?? 0
            )
        }

        let reasoning = reasoningContent.isEmpty
            ? nil
            : ReasoningContent(content: reasoningContent)

        return AssistantMessage(
            content: textContent,
            toolCalls: toolCalls,
            tokenUsage: tokenUsage,
            reasoning: reasoning
        )
    }
}
