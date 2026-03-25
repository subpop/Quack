import SwiftUI
import SwiftData

struct ChatSessionRow: View {
    let session: ChatSession
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 2)
    }
}

#Preview("Normal") {
    @Previewable @State var renameText = ""
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatSessionRow(session: data.session, isRenaming: false, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}

#Preview("Pinned") {
    @Previewable @State var renameText = ""
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)
    let _ = (data.session.isPinned = true)

    ChatSessionRow(session: data.session, isRenaming: false, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}

#Preview("Renaming") {
    @Previewable @State var renameText = "Hello World"
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatSessionRow(session: data.session, isRenaming: true, renameText: $renameText)
        .frame(width: 260)
        .padding()
        .modelContainer(container)
}
