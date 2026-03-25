import Foundation
import AgentRunKit

/// An LLMClient that sends Anthropic Claude requests through Google Cloud Vertex AI.
///
/// Vertex AI hosts Claude models using the standard Anthropic Messages API wire protocol,
/// with these differences from the direct Anthropic API:
///
/// - **URL**: `.../publishers/anthropic/models/{model}:rawPredict` (or `:streamRawPredict`)
/// - **Auth**: `Authorization: Bearer <token>` (from Google ADC) instead of `x-api-key`
/// - **Body**: Adds `"anthropic_version": "vertex-2023-10-16"`; model is in URL, not body
/// - **Streaming**: Same SSE event format as the standard Anthropic API
///
/// Internally, this delegates to `AnthropicClient` from AgentRunKit for the actual
/// Anthropic protocol handling (message mapping, request building, SSE parsing), passing
/// in Vertex-specific auth and configuration via `additionalHeaders` and `extraFields`.
nonisolated struct VertexAnthropicClient: LLMClient, Sendable {
    let modelIdentifier: String?
    let maxOutputTokens: Int
    let contextWindowSize: Int?

    private let authProvider: GoogleAuthProvider
    private let vertexBaseURL: URL
    private let session: URLSession

    /// The Vertex AI `anthropic_version` value sent in the request body.
    private static let vertexAnthropicVersion = "vertex-2023-10-16"

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
    }

    // MARK: - LLMClient

    func generate(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        responseFormat: ResponseFormat?,
        requestContext: RequestContext?
    ) async throws -> AssistantMessage {
        let body = try buildVertexAnthropicBody(
            messages: messages,
            tools: tools,
            stream: false,
            extraFields: requestContext?.extraFields
        )
        let urlRequest = try await buildVertexURLRequest(action: "rawPredict", body: body)
        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let responseBody = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw AgentError.llmError(.httpError(statusCode: httpResponse.statusCode, body: responseBody))
        }

        return try parseAnthropicResponse(data)
    }

    func stream(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        requestContext: RequestContext?
    ) -> AsyncThrowingStream<StreamDelta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try buildVertexAnthropicBody(
                        messages: messages,
                        tools: tools,
                        stream: true,
                        extraFields: requestContext?.extraFields
                    )
                    let urlRequest = try await buildVertexURLRequest(action: "streamRawPredict", body: body)

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

                    try await parseAnthropicSSEStream(bytes: asyncBytes, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Request Building

    private func buildVertexURLRequest(action: String, body: Data) async throws -> URLRequest {
        let model = modelIdentifier ?? "claude-sonnet-4-6"
        var baseString = vertexBaseURL.absoluteString
        if !baseString.hasSuffix("/") { baseString += "/" }
        let urlString = "\(baseString)publishers/anthropic/models/\(model):\(action)"

        guard let url = URL(string: urlString) else {
            throw AgentError.llmError(.other("Invalid Vertex AI URL: \(urlString)"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await authProvider.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        request.httpBody = body
        return request
    }

    /// Builds the Anthropic Messages API request body for Vertex AI.
    ///
    /// Uses the standard Anthropic format but:
    /// - Omits `model` (it's in the URL path)
    /// - Adds `anthropic_version` in the body
    private func buildVertexAnthropicBody(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        stream: Bool,
        extraFields: [String: JSONValue]?
    ) throws -> Data {
        var body: [String: Any] = [:]

        // Anthropic version (required by Vertex AI, goes in body instead of header)
        body["anthropic_version"] = Self.vertexAnthropicVersion

        // Max tokens
        body["max_tokens"] = maxOutputTokens

        // Stream flag
        if stream {
            body["stream"] = true
        }

        // Convert messages
        var systemParts: [[String: Any]] = []
        var anthropicMessages: [[String: Any]] = []

        for message in messages {
            switch message {
            case .system(let text):
                systemParts.append(["type": "text", "text": text])

            case .user(let text):
                anthropicMessages.append([
                    "role": "user",
                    "content": text,
                ])

            case .userMultimodal(let parts):
                var contentParts: [[String: Any]] = []
                for part in parts {
                    switch part {
                    case .text(let text):
                        contentParts.append(["type": "text", "text": text])
                    case .imageBase64(let data, let mimeType):
                        contentParts.append([
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mimeType,
                                "data": data.base64EncodedString(),
                            ],
                        ])
                    case .pdfBase64(let data):
                        contentParts.append([
                            "type": "document",
                            "source": [
                                "type": "base64",
                                "media_type": "application/pdf",
                                "data": data.base64EncodedString(),
                            ],
                        ])
                    default:
                        break
                    }
                }
                anthropicMessages.append(["role": "user", "content": contentParts])

            case .assistant(let assistantMsg):
                var contentParts: [[String: Any]] = []
                if !assistantMsg.content.isEmpty {
                    contentParts.append(["type": "text", "text": assistantMsg.content])
                }
                for toolCall in assistantMsg.toolCalls {
                    var input: Any = [String: Any]()
                    if let data = toolCall.arguments.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) {
                        input = parsed
                    }
                    contentParts.append([
                        "type": "tool_use",
                        "id": toolCall.id,
                        "name": toolCall.name,
                        "input": input,
                    ])
                }
                anthropicMessages.append(["role": "assistant", "content": contentParts])

            case .tool(let id, _, let content):
                anthropicMessages.append([
                    "role": "user",
                    "content": [
                        ["type": "tool_result", "tool_use_id": id, "content": content] as [String: Any],
                    ],
                ])
            }
        }

        body["messages"] = anthropicMessages
        if !systemParts.isEmpty {
            body["system"] = systemParts
        }

        // Tools
        if !tools.isEmpty {
            let toolDefs: [[String: Any]] = tools.map { tool in
                var def: [String: Any] = [
                    "name": tool.name,
                    "description": tool.description,
                ]
                if let schemaData = try? JSONEncoder().encode(tool.parametersSchema),
                   let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) {
                    def["input_schema"] = schemaDict
                }
                return def
            }
            body["tools"] = toolDefs
        }

        // Extra fields (e.g. temperature from requestContext)
        if let extraFields {
            for (key, value) in extraFields {
                if let data = try? JSONEncoder().encode(value),
                   let parsed = try? JSONSerialization.jsonObject(with: data) {
                    body[key] = parsed
                }
            }
        }

        return try JSONSerialization.data(withJSONObject: body)
    }

    // MARK: - Response Parsing

    private func parseAnthropicResponse(_ data: Data) throws -> AssistantMessage {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentError.llmError(.other("Invalid JSON response"))
        }

        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw AgentError.llmError(.other(message))
        }

        var textContent = ""
        var toolCalls: [ToolCall] = []

        if let content = json["content"] as? [[String: Any]] {
            for block in content {
                let type = block["type"] as? String
                switch type {
                case "text":
                    if let text = block["text"] as? String {
                        textContent += text
                    }
                case "tool_use":
                    if let id = block["id"] as? String,
                       let name = block["name"] as? String {
                        let input = block["input"] ?? [String: Any]()
                        let argsData = try JSONSerialization.data(withJSONObject: input)
                        let arguments = String(data: argsData, encoding: .utf8) ?? "{}"
                        toolCalls.append(ToolCall(id: id, name: name, arguments: arguments))
                    }
                default:
                    break
                }
            }
        }

        var tokenUsage: TokenUsage?
        if let usage = json["usage"] as? [String: Any] {
            tokenUsage = TokenUsage(
                input: usage["input_tokens"] as? Int ?? 0,
                output: usage["output_tokens"] as? Int ?? 0
            )
        }

        return AssistantMessage(
            content: textContent,
            toolCalls: toolCalls,
            tokenUsage: tokenUsage
        )
    }

    // MARK: - SSE Stream Parsing

    private func parseAnthropicSSEStream(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<StreamDelta, Error>.Continuation
    ) async throws {
        var currentEventType: String?
        var toolCallCount = 0
        var inputUsageTokens: Int = 0

        for try await line in bytes.lines {
            guard !Task.isCancelled else { break }

            // SSE event type line
            if line.hasPrefix("event:") {
                let type = line.hasPrefix("event: ")
                    ? String(line.dropFirst(7))
                    : String(line.dropFirst(6))
                currentEventType = type.trimmingCharacters(in: .whitespaces)
                continue
            }

            // SSE data line
            let payload: String
            if line.hasPrefix("data: ") {
                payload = String(line.dropFirst(6))
            } else if line.hasPrefix("data:") {
                payload = String(line.dropFirst(5))
            } else {
                continue
            }

            guard let eventType = currentEventType,
                  let data = payload.data(using: .utf8) else { continue }

            switch eventType {
            case "message_start":
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    inputUsageTokens = usage["input_tokens"] as? Int ?? 0
                }

            case "content_block_start":
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let block = json["content_block"] as? [String: Any] {
                    let blockType = block["type"] as? String
                    if blockType == "tool_use",
                       let id = block["id"] as? String,
                       let name = block["name"] as? String {
                        continuation.yield(.toolCallStart(
                            index: toolCallCount,
                            id: id,
                            name: name
                        ))
                        toolCallCount += 1
                    }
                }

            case "content_block_delta":
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let delta = json["delta"] as? [String: Any] {
                    let deltaType = delta["type"] as? String
                    switch deltaType {
                    case "text_delta":
                        if let text = delta["text"] as? String {
                            continuation.yield(.content(text))
                        }
                    case "thinking_delta":
                        if let text = delta["thinking"] as? String {
                            continuation.yield(.reasoning(text))
                        }
                    case "input_json_delta":
                        if let partial = delta["partial_json"] as? String {
                            continuation.yield(.toolCallDelta(
                                index: toolCallCount - 1,
                                arguments: partial
                            ))
                        }
                    default:
                        break
                    }
                }

            case "message_delta":
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let usage = json["usage"] as? [String: Any] {
                    let outputTokens = usage["output_tokens"] as? Int ?? 0
                    let tokenUsage = TokenUsage(
                        input: inputUsageTokens,
                        output: outputTokens
                    )
                    continuation.yield(.finished(usage: tokenUsage))
                }

            case "message_stop":
                continuation.finish()
                return

            case "error":
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? "Unknown stream error"
                    throw AgentError.llmError(.other(message))
                }

            case "ping":
                break

            default:
                break
            }
        }

        continuation.finish()
    }
}
