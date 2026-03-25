import Foundation
import AgentRunKit

// MARK: - Streaming

extension GeminiClient {

    /// Performs a streaming request to Gemini's `streamGenerateContent` endpoint.
    ///
    /// Uses `?alt=sse` to get standard SSE format, then parses the `data:` lines
    /// as `GeminiResponse` JSON chunks.
    func performStreamRequest(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        continuation: AsyncThrowingStream<StreamDelta, Error>.Continuation
    ) async throws {
        let geminiRequest = buildGeminiRequest(messages: messages, tools: tools)
        let urlRequest = try buildURLRequest(for: "streamGenerateContent", body: geminiRequest)

        let (asyncBytes, httpResponse) = try await session.bytes(for: urlRequest)

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw AgentError.llmError(.invalidResponse)
        }

        // Handle HTTP errors
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

        let state = GeminiStreamState()

        // Parse SSE lines from the byte stream
        for try await line in asyncBytes.lines {
            guard !Task.isCancelled else { break }
            let done = try await handleSSELine(line, state: state, continuation: continuation)
            if done { break }
        }

        // Emit final finished event with accumulated usage
        let usage = await state.accumulatedUsage
        continuation.yield(.finished(usage: usage))
        continuation.finish()
    }

    /// Handles a single SSE line from the Gemini stream.
    ///
    /// Returns `true` if the stream should be considered complete.
    private func handleSSELine(
        _ line: String,
        state: GeminiStreamState,
        continuation: AsyncThrowingStream<StreamDelta, Error>.Continuation
    ) async throws -> Bool {
        // Extract SSE data payload: lines must start with "data:" or "data: "
        let payload: String
        if line.hasPrefix("data: ") {
            payload = String(line.dropFirst(6))
        } else if line.hasPrefix("data:") {
            payload = String(line.dropFirst(5))
        } else {
            return false  // Not a data line (comment, empty, event type, etc.)
        }

        // Gemini doesn't use a [DONE] sentinel -- the SSE stream simply ends.
        // But check defensively in case the API ever adds one.
        let trimmed = payload.trimmingCharacters(in: .whitespaces)
        if trimmed == "[DONE]" || trimmed.isEmpty {
            return trimmed == "[DONE]"
        }

        guard let data = payload.data(using: .utf8) else { return false }

        let response: GeminiResponse
        do {
            response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            // Skip malformed chunks rather than failing the stream
            return false
        }

        // Check for API errors
        if let error = response.error {
            throw AgentError.llmError(.other(
                "\(error.status ?? "ERROR"): \(error.message ?? "Unknown error")"
            ))
        }

        // Process candidates
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
                        index: toolCallIndex,
                        id: id,
                        name: call.name
                    ))

                    // Gemini delivers function call args in a single chunk
                    // (not streamed incrementally like OpenAI), so emit the
                    // full arguments immediately.
                    let arguments: String
                    if let args = call.args {
                        let encoded = try? JSONEncoder().encode(args)
                        arguments = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    } else {
                        arguments = "{}"
                    }
                    continuation.yield(.toolCallDelta(
                        index: toolCallIndex,
                        arguments: arguments
                    ))

                case .functionResponse, .inlineData:
                    break  // Not expected in model responses
                }
            }
        }

        // Accumulate usage metadata (typically in the final chunk)
        if let usage = response.usageMetadata {
            await state.updateUsage(usage)
        }

        return false
    }
}

// GeminiStreamState is defined in VertexGeminiClient.swift and shared by both clients.
