import Foundation
import AgentRunKit

/// An LLMClient that sends Gemini requests through Google Cloud Vertex AI.
///
/// This wraps the Gemini `generateContent` / `streamGenerateContent` wire protocol
/// with Vertex AI's URL structure and OAuth2 (ADC) authentication.
///
/// - **URL**: `{baseURL}/publishers/google/models/{model}:generateContent`
///   (or `:streamGenerateContent?alt=sse` for streaming)
/// - **Auth**: `Authorization: Bearer <token>` from Application Default Credentials
///
/// The request/response format is identical to Google AI (AI Studio). This client
/// reuses `GeminiClient`'s request building, response parsing, and SSE parsing logic.
nonisolated struct VertexGeminiClient: LLMClient, Sendable {
    let modelIdentifier: String?
    let maxOutputTokens: Int
    let contextWindowSize: Int?

    private let authProvider: GoogleAuthProvider
    private let vertexBaseURL: URL
    private let session: URLSession
    private let retryPolicy: RetryPolicy

    /// An inner GeminiClient used solely for request building, response parsing,
    /// and SSE stream parsing. Its HTTP methods are NOT called directly.
    private let inner: GeminiClient

    init(
        authProvider: GoogleAuthProvider,
        model: String? = nil,
        maxOutputTokens: Int = 8192,
        contextWindowSize: Int? = nil,
        baseURL: URL,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.modelIdentifier = model
        self.maxOutputTokens = maxOutputTokens
        self.contextWindowSize = contextWindowSize
        self.authProvider = authProvider
        self.vertexBaseURL = baseURL
        self.session = session
        self.retryPolicy = retryPolicy

        // The inner client is used for buildGeminiRequest(), parseResponse(),
        // and extractAssistantMessage(). Its apiKey and baseURL are unused.
        self.inner = GeminiClient(
            apiKey: "unused-vertex-uses-oauth",
            model: model,
            maxOutputTokens: maxOutputTokens,
            contextWindowSize: contextWindowSize,
            baseURL: baseURL,
            session: session,
            retryPolicy: retryPolicy
        )
    }

    // MARK: - LLMClient

    func generate(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        responseFormat: ResponseFormat?,
        requestContext: RequestContext?
    ) async throws -> AssistantMessage {
        let geminiRequest = inner.buildGeminiRequest(messages: messages, tools: tools)
        let urlRequest = try await buildVertexURLRequest(
            action: "generateContent",
            body: geminiRequest
        )

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw AgentError.llmError(.httpError(statusCode: httpResponse.statusCode, body: body))
        }

        return try inner.parseResponse(data)
    }

    func stream(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        requestContext: RequestContext?
    ) -> AsyncThrowingStream<StreamDelta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performVertexStreamRequest(
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

    // MARK: - Vertex AI URL & Auth

    /// Builds a URLRequest for the Vertex AI Gemini endpoint.
    ///
    /// URL pattern: `{baseURL}/publishers/google/models/{model}:{action}`
    private func buildVertexURLRequest(
        action: String,
        body: some Encodable
    ) async throws -> URLRequest {
        let model = modelIdentifier ?? "gemini-2.0-flash"
        var baseString = vertexBaseURL.absoluteString
        if !baseString.hasSuffix("/") { baseString += "/" }
        var urlString = "\(baseString)publishers/google/models/\(model):\(action)"

        // For streaming, append ?alt=sse to get SSE format
        if action.contains("stream") {
            urlString += "?alt=sse"
        }

        guard let url = URL(string: urlString) else {
            throw AgentError.llmError(.other("Invalid Vertex AI URL: \(urlString)"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await authProvider.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AgentError.llmError(.encodingFailed(error))
        }

        return request
    }

    // MARK: - Streaming

    private func performVertexStreamRequest(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        continuation: AsyncThrowingStream<StreamDelta, Error>.Continuation
    ) async throws {
        let geminiRequest = inner.buildGeminiRequest(messages: messages, tools: tools)
        let urlRequest = try await buildVertexURLRequest(
            action: "streamGenerateContent",
            body: geminiRequest
        )

        let (asyncBytes, httpResponse) = try await session.bytes(for: urlRequest)

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw AgentError.llmError(.invalidResponse)
        }

        if httpResponse.statusCode >= 400 {
            var errorBody = ""
            for try await line in asyncBytes.lines {
                errorBody += line + "\n"
                if errorBody.count > 4096 { break }
            }
            throw AgentError.llmError(.httpError(
                statusCode: httpResponse.statusCode,
                body: errorBody.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        // Reuse Gemini SSE parsing -- the wire format is identical
        let state = GeminiStreamState()

        for try await line in asyncBytes.lines {
            guard !Task.isCancelled else { break }
            let done = try await handleGeminiSSELine(
                line, state: state, continuation: continuation
            )
            if done { break }
        }

        let usage = await state.accumulatedUsage
        continuation.yield(.finished(usage: usage))
        continuation.finish()
    }

    /// Parses a Gemini SSE line -- identical format to Google AI.
    private func handleGeminiSSELine(
        _ line: String,
        state: GeminiStreamState,
        continuation: AsyncThrowingStream<StreamDelta, Error>.Continuation
    ) async throws -> Bool {
        let payload: String
        if line.hasPrefix("data: ") {
            payload = String(line.dropFirst(6))
        } else if line.hasPrefix("data:") {
            payload = String(line.dropFirst(5))
        } else {
            return false
        }

        let trimmed = payload.trimmingCharacters(in: .whitespaces)
        if trimmed == "[DONE]" || trimmed.isEmpty {
            return trimmed == "[DONE]"
        }

        guard let data = payload.data(using: .utf8) else { return false }

        let response: GeminiResponse
        do {
            response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            return false
        }

        if let error = response.error {
            throw AgentError.llmError(.other(
                "\(error.status ?? "ERROR"): \(error.message ?? "Unknown error")"
            ))
        }

        if let candidate = response.candidates?.first,
           let content = candidate.content {
            for part in content.parts {
                switch part {
                case let .text(text, thought):
                    if thought == true {
                        continuation.yield(.reasoning(text))
                    } else {
                        continuation.yield(.content(text))
                    }

                case let .functionCall(call):
                    let id = call.id ?? UUID().uuidString
                    let toolCallIndex = await state.nextToolCallIndex()

                    continuation.yield(.toolCallStart(
                        index: toolCallIndex, id: id, name: call.name
                    ))

                    let arguments: String
                    if let args = call.args {
                        let encoded = try? JSONEncoder().encode(args)
                        arguments = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    } else {
                        arguments = "{}"
                    }
                    continuation.yield(.toolCallDelta(
                        index: toolCallIndex, arguments: arguments
                    ))

                case .functionResponse, .inlineData:
                    break
                }
            }
        }

        if let usage = response.usageMetadata {
            await state.updateUsage(usage)
        }

        return false
    }
}

// MARK: - Stream State (shared with GeminiClient)

/// Tracks mutable state across SSE events during a Gemini streaming response.
/// Used by both `GeminiClient` and `VertexGeminiClient`.
actor GeminiStreamState {
    private var toolCallCount: Int = 0
    private var usage: GeminiUsageMetadata?

    func nextToolCallIndex() -> Int {
        let index = toolCallCount
        toolCallCount += 1
        return index
    }

    func updateUsage(_ metadata: GeminiUsageMetadata) {
        usage = metadata
    }

    var accumulatedUsage: TokenUsage? {
        guard let usage else { return nil }
        return TokenUsage(
            input: usage.promptTokenCount ?? 0,
            output: usage.candidatesTokenCount ?? 0,
            reasoning: usage.thoughtsTokenCount ?? 0
        )
    }
}
