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

import SwiftUI
import SwiftData
import QuackInterface

struct ChatSessionRow: View {
    let session: ChatSession
    let assistant: Assistant?
    let isRenaming: Bool
    @Binding var renameText: String

    private var lastMessage: ChatMessageRecord? {
        session.sortedMessages.last
    }

    private var subtitle: String {
        if let last = lastMessage {
            return String(last.content.prefix(80))
        }
        return "No messages yet"
    }

    // MARK: - Avatar

    private var avatarIcon: String {
        assistant?.resolvedIcon ?? "person.crop.circle.fill"
    }

    private var avatarColor: Color {
        assistant?.resolvedColor ?? .gray
    }

    private var avatarView: some View {
        Image(systemName: avatarIcon)
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(avatarColor.gradient)
            )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                if isRenaming {
                    TextField("Chat name", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.body.weight(.medium))
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)

                        Spacer()

                        Text(session.updatedAt, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        if session.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(4)
        .padding(.vertical, 2)
    }
}

#Preview("Normal") {
    @Previewable @State var renameText = ""
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatSessionRow(session: data.session, assistant: data.assistants.first, isRenaming: false, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}

#Preview("Pinned") {
    @Previewable @State var renameText = ""
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)
    let _ = (data.session.isPinned = true)

    ChatSessionRow(session: data.session, assistant: data.assistants.first, isRenaming: false, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}

#Preview("No Assistant") {
    @Previewable @State var renameText = ""
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatSessionRow(session: data.session, assistant: nil, isRenaming: false, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}

#Preview("Renaming") {
    @Previewable @State var renameText = "Hello World"
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatSessionRow(session: data.session, assistant: data.assistants.first, isRenaming: true, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}
