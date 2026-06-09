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

/// The type of an attachment in a chat message.
public enum AttachmentType: String, Codable, Sendable {
    case image
    case pdf
}

/// A file attachment (image or PDF) associated with a chat message.
///
/// Attachments are serialized as JSON in ``ChatMessageRecord/attachmentsJSON``
/// for SwiftData persistence. The ``data`` field holds the raw file bytes
/// (base64-encoded by `Codable`).
public struct Attachment: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let type: AttachmentType
    public let mimeType: String
    public let data: Data
    public let fileName: String?

    public init(
        id: UUID = UUID(),
        type: AttachmentType,
        mimeType: String,
        data: Data,
        fileName: String? = nil
    ) {
        self.id = id
        self.type = type
        self.mimeType = mimeType
        self.data = data
        self.fileName = fileName
    }
}

// MARK: - Encoding / Decoding Helpers

/// Decode attachments from a JSON string.
public func decodeAttachments(from json: String?) -> [Attachment] {
    guard let json, !json.isEmpty,
          let data = json.data(using: .utf8),
          let attachments = try? JSONDecoder().decode([Attachment].self, from: data)
    else { return [] }
    return attachments
}

/// Encode attachments to a JSON string.
public func encodeAttachments(_ attachments: [Attachment]) -> String? {
    guard !attachments.isEmpty else { return nil }
    guard let data = try? JSONEncoder().encode(attachments),
          let json = String(data: data, encoding: .utf8)
    else { return nil }
    return json
}
