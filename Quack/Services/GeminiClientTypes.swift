import Foundation
import AgentRunKit

// MARK: - Request Types

nonisolated struct GeminiRequest: Encodable, Sendable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let tools: [GeminiTool]?
    let toolConfig: GeminiToolConfig?
    let generationConfig: GeminiGenerationConfig?

    enum CodingKeys: String, CodingKey {
        case contents, systemInstruction, tools, toolConfig, generationConfig
    }
}

nonisolated struct GeminiContent: Codable, Sendable {
    let role: String?
    let parts: [GeminiPart]
}

/// A union type representing different part kinds in Gemini's Content.
///
/// Each part is exactly one of: text, functionCall, functionResponse, or inlineData.
/// Gemini 2.5 thinking models emit text parts with `thought: true` for reasoning.
nonisolated enum GeminiPart: Codable, Sendable {
    case text(String, thought: Bool?)
    case functionCall(GeminiFunctionCall)
    case functionResponse(GeminiFunctionResponse)
    case inlineData(GeminiInlineData)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case text, thought, functionCall, functionResponse, inlineData
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            let thought = try container.decodeIfPresent(Bool.self, forKey: .thought)
            self = .text(text, thought: thought)
            return
        }
        if let call = try container.decodeIfPresent(GeminiFunctionCall.self, forKey: .functionCall) {
            self = .functionCall(call)
            return
        }
        if let response = try container.decodeIfPresent(GeminiFunctionResponse.self, forKey: .functionResponse) {
            self = .functionResponse(response)
            return
        }
        if let data = try container.decodeIfPresent(GeminiInlineData.self, forKey: .inlineData) {
            self = .inlineData(data)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown GeminiPart type")
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text, thought):
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(thought, forKey: .thought)
        case let .functionCall(call):
            try container.encode(call, forKey: .functionCall)
        case let .functionResponse(response):
            try container.encode(response, forKey: .functionResponse)
        case let .inlineData(data):
            try container.encode(data, forKey: .inlineData)
        }
    }
}

nonisolated struct GeminiFunctionCall: Codable, Sendable {
    let name: String
    let args: [String: JSONValue]?
    let id: String?
}

nonisolated struct GeminiFunctionResponse: Codable, Sendable {
    let name: String
    let response: [String: JSONValue]
    let id: String?
}

nonisolated struct GeminiInlineData: Codable, Sendable {
    let mimeType: String
    let data: String  // base64-encoded
}

// MARK: - Tool Definitions

nonisolated struct GeminiTool: Encodable, Sendable {
    let functionDeclarations: [GeminiFunctionDeclaration]?
}

nonisolated struct GeminiFunctionDeclaration: Encodable, Sendable {
    let name: String
    let description: String
    let parameters: GeminiSchema?
}

/// A Gemini-compatible wrapper around `JSONSchema` that strips fields not supported
/// by the Gemini API (e.g. `additionalProperties`).
nonisolated struct GeminiSchema: Encodable, Sendable {
    let wrapped: JSONSchema

    init(_ schema: JSONSchema) {
        self.wrapped = schema
    }

    private enum CodingKeys: String, CodingKey {
        case type, description, items, properties, required, anyOf
        case `enum`
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch wrapped {
        case let .string(description, enumValues):
            try container.encode("string", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(enumValues, forKey: .enum)

        case let .integer(description):
            try container.encode("integer", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case let .number(description):
            try container.encode("number", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case let .boolean(description):
            try container.encode("boolean", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)

        case let .array(items, description):
            try container.encode("array", forKey: .type)
            try container.encode(GeminiSchema(items), forKey: .items)
            try container.encodeIfPresent(description, forKey: .description)

        case let .object(properties, required, description):
            try container.encode("object", forKey: .type)
            try container.encode(
                properties.mapValues { GeminiSchema($0) },
                forKey: .properties
            )
            if !required.isEmpty {
                try container.encode(required, forKey: .required)
            }
            try container.encodeIfPresent(description, forKey: .description)
            // NOTE: intentionally omits `additionalProperties` — unsupported by Gemini API

        case .null:
            try container.encode("null", forKey: .type)

        case let .anyOf(schemas):
            try container.encode(schemas.map { GeminiSchema($0) }, forKey: .anyOf)
        }
    }
}

nonisolated struct GeminiToolConfig: Encodable, Sendable {
    let functionCallingConfig: GeminiFunctionCallingConfig
}

nonisolated struct GeminiFunctionCallingConfig: Encodable, Sendable {
    let mode: String  // AUTO, ANY, NONE
}

// MARK: - Generation Config

nonisolated struct GeminiGenerationConfig: Encodable, Sendable {
    let maxOutputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let thinkingConfig: GeminiThinkingConfig?
}

nonisolated struct GeminiThinkingConfig: Encodable, Sendable {
    let thinkingBudget: Int?
}

// MARK: - Response Types

nonisolated struct GeminiResponse: Decodable, Sendable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?
    let modelVersion: String?
    let error: GeminiErrorDetail?
}

nonisolated struct GeminiCandidate: Decodable, Sendable {
    let content: GeminiContent?
    let finishReason: String?
}

nonisolated struct GeminiUsageMetadata: Decodable, Sendable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
    let thoughtsTokenCount: Int?
}

nonisolated struct GeminiErrorDetail: Decodable, Sendable {
    let code: Int?
    let message: String?
    let status: String?
}

nonisolated struct GeminiErrorResponse: Decodable, Sendable {
    let error: GeminiErrorDetail
}

// MARK: - Message Mapper

/// Converts AgentRunKit's `[ChatMessage]` to Gemini's request format.
///
/// Key mappings:
/// - `.system` messages are extracted into a separate `systemInstruction` content
/// - `.user` messages become `role: "user"` contents
/// - `.assistant` messages become `role: "model"` contents
/// - `.tool` messages become `role: "user"` contents with `functionResponse` parts
/// - Consecutive tool results are merged into a single "user" content (Gemini requires
///   strict user/model alternation)
nonisolated enum GeminiMessageMapper {

    struct MappedMessages: Sendable {
        let systemInstruction: GeminiContent?
        let contents: [GeminiContent]
    }

    static func mapMessages(_ messages: [ChatMessage]) -> MappedMessages {
        var systemParts: [GeminiPart] = []
        var contents: [GeminiContent] = []

        for message in messages {
            switch message {
            case .system(let text):
                systemParts.append(.text(text, thought: nil))

            case .user(let text):
                contents.append(GeminiContent(role: "user", parts: [.text(text, thought: nil)]))

            case .userMultimodal(let contentParts):
                let geminiParts = contentParts.compactMap { part -> GeminiPart? in
                    switch part {
                    case .text(let text):
                        return .text(text, thought: nil)
                    case .imageBase64(let data, let mimeType):
                        return .inlineData(GeminiInlineData(
                            mimeType: mimeType,
                            data: data.base64EncodedString()
                        ))
                    case .imageURL:
                        // Gemini doesn't support image URLs directly; skip
                        return nil
                    case .videoBase64(let data, let mimeType):
                        return .inlineData(GeminiInlineData(
                            mimeType: mimeType,
                            data: data.base64EncodedString()
                        ))
                    case .pdfBase64(let data):
                        return .inlineData(GeminiInlineData(
                            mimeType: "application/pdf",
                            data: data.base64EncodedString()
                        ))
                    case .audioBase64(let data, let format):
                        return .inlineData(GeminiInlineData(
                            mimeType: format.mimeType,
                            data: data.base64EncodedString()
                        ))
                    }
                }
                if !geminiParts.isEmpty {
                    contents.append(GeminiContent(role: "user", parts: geminiParts))
                }

            case .assistant(let assistantMsg):
                var parts: [GeminiPart] = []
                if !assistantMsg.content.isEmpty {
                    parts.append(.text(assistantMsg.content, thought: nil))
                }
                for toolCall in assistantMsg.toolCalls {
                    // Parse the JSON arguments string back into a dictionary
                    let args: [String: JSONValue]?
                    if let data = toolCall.arguments.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
                        args = decoded
                    } else {
                        args = nil
                    }
                    parts.append(.functionCall(GeminiFunctionCall(
                        name: toolCall.name,
                        args: args,
                        id: toolCall.id
                    )))
                }
                if !parts.isEmpty {
                    contents.append(GeminiContent(role: "model", parts: parts))
                }

            case .tool(let id, let name, let content):
                // Gemini expects functionResponse parts in a "user" role content.
                // Multiple consecutive tool results should be merged into one content.
                let responsePart = GeminiPart.functionResponse(GeminiFunctionResponse(
                    name: name,
                    response: ["result": .string(content)],
                    id: id
                ))

                // Merge with previous content if it's also a user/tool content
                if let last = contents.last, last.role == "user",
                   last.parts.allSatisfy(isFunctionResponse) {
                    var merged = last.parts
                    merged.append(responsePart)
                    contents[contents.count - 1] = GeminiContent(role: "user", parts: merged)
                } else {
                    contents.append(GeminiContent(role: "user", parts: [responsePart]))
                }
            }
        }

        let systemInstruction: GeminiContent? = systemParts.isEmpty
            ? nil
            : GeminiContent(role: nil, parts: systemParts)

        return MappedMessages(systemInstruction: systemInstruction, contents: contents)
    }

    /// Convert AgentRunKit `ToolDefinition` array to Gemini's tool format.
    static func mapTools(_ tools: [ToolDefinition]) -> [GeminiTool]? {
        guard !tools.isEmpty else { return nil }
        let declarations = tools.map { tool in
            GeminiFunctionDeclaration(
                name: tool.name,
                description: tool.description,
                parameters: GeminiSchema(tool.parametersSchema)
            )
        }
        return [GeminiTool(functionDeclarations: declarations)]
    }

    private static func isFunctionResponse(_ part: GeminiPart) -> Bool {
        if case .functionResponse = part { return true }
        return false
    }
}
