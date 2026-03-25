import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var allSessions: [ChatSession]

    @Binding var selectedSessionID: UUID?
    var onNewChat: () -> Void

    @State private var searchText = ""
    @State private var renamingSessionID: UUID?
    @State private var renameText = ""

    private var activeSessions: [ChatSession] {
        let active = allSessions.filter { !$0.isArchived }
        if searchText.isEmpty { return active }
        return active.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedSessions: [ChatSession] {
        activeSessions.filter(\.isPinned)
    }

    private var unpinnedSessions: [ChatSession] {
        activeSessions.filter { !$0.isPinned }
    }

    private var archivedSessions: [ChatSession] {
        let archived = allSessions.filter(\.isArchived)
        if searchText.isEmpty { return archived }
        return archived.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(selection: $selectedSessionID) {
            if !pinnedSessions.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedSessions) { session in
                        sessionRow(session)
                    }
                }
            }

            Section {
                ForEach(unpinnedSessions) { session in
                    sessionRow(session)
                }
            } header: {
                if !pinnedSessions.isEmpty {
                    Text("Chats")
                }
            }

            if !archivedSessions.isEmpty {
                DisclosureGroup("Archived") {
                    ForEach(archivedSessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search chats")
        .toolbar {
            ToolbarItem {
                Button(action: onNewChat) {
                    Label("New Chat", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: ChatSession) -> some View {
        ChatSessionRow(
            session: session,
            isRenaming: renamingSessionID == session.id,
            renameText: $renameText
        )
        .tag(session.id)
        .contextMenu {
            Button(session.isPinned ? "Unpin" : "Pin") {
                session.isPinned.toggle()
                try? modelContext.save()
            }

            Button("Rename") {
                renameText = session.title
                renamingSessionID = session.id
            }

            Divider()

            Button(session.isArchived ? "Unarchive" : "Archive") {
                withAnimation {
                    session.isArchived.toggle()
                    session.updatedAt = Date()
                    try? modelContext.save()
                }
            }

            Button("Delete", role: .destructive) {
                withAnimation {
                    if selectedSessionID == session.id {
                        selectedSessionID = nil
                    }
                    modelContext.delete(session)
                    try? modelContext.save()
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    if selectedSessionID == session.id {
                        selectedSessionID = nil
                    }
                    modelContext.delete(session)
                    try? modelContext.save()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation {
                    session.isArchived.toggle()
                    session.updatedAt = Date()
                    try? modelContext.save()
                }
            } label: {
                Label(
                    session.isArchived ? "Unarchive" : "Archive",
                    systemImage: session.isArchived ? "tray.and.arrow.up" : "archivebox"
                )
            }
            .tint(.orange)
        }
        .onSubmit {
            if renamingSessionID == session.id {
                session.title = renameText
                renamingSessionID = nil
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedID: UUID?
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    SidebarView(selectedSessionID: $selectedID, onNewChat: {})
        .frame(width: 260, height: 500)
        .modelContainer(container)
}
