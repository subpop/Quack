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

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var allSessions: [ChatSession]
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    @Binding var selectedSessionID: UUID?
    var assistants: [Assistant]
    var onNewChat: (Assistant?) -> Void

    @State private var searchText = ""
    @State private var renamingSessionID: UUID?
    @State private var renameText = ""

    // MARK: - Filtered Sessions

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

    // MARK: - Date Grouping

    private enum DateGroup: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case previousWeek = "Previous 7 Days"
        case previousMonth = "Previous 30 Days"
        case older = "Older"
    }

    private func dateGroup(for date: Date) -> DateGroup {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: Date()))!
        if date >= weekAgo { return .previousWeek }
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: Date()))!
        if date >= monthAgo { return .previousMonth }
        return .older
    }

    private func groupedSessions(_ sessions: [ChatSession]) -> [(DateGroup, [ChatSession])] {
        let grouped = Dictionary(grouping: sessions) { dateGroup(for: $0.updatedAt) }
        return DateGroup.allCases.compactMap { group in
            guard let sessions = grouped[group], !sessions.isEmpty else { return nil }
            return (group, sessions)
        }
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selectedSessionID) {
            if !pinnedSessions.isEmpty {
                Section {
                    ForEach(pinnedSessions) { session in
                        sessionRow(session)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(groupedSessions(unpinnedSessions), id: \.0) { group, sessions in
                Section {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                } header: {
                    Text(group.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if !archivedSessions.isEmpty {
                DisclosureGroup {
                    ForEach(archivedSessions) { session in
                        sessionRow(session)
                    }
                } label: {
                    Label("Archived", systemImage: "archivebox")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                newChatButton
            }
        }
    }

    // MARK: - New Chat Button

    @ViewBuilder
    private var newChatButton: some View {
        if assistants.count > 1 {
            Menu {
                ForEach(assistants) { assistant in
                    Button {
                        onNewChat(assistant)
                    } label: {
                        Label(
                            assistant.name,
                            systemImage: assistant.resolvedIcon
                        )
                        if assistant.isDefault {
                            Text("(Default)")
                        }
                    }
                }
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
            } primaryAction: {
                onNewChat(nil)
            }
            .help("New Conversation")
        } else {
            Button(action: { onNewChat(nil) }) {
                Label("New Chat", systemImage: "square.and.pencil")
            }
            .help("New Conversation")
        }
    }

    // MARK: - Session Row

    @ViewBuilder
    private func sessionRow(_ session: ChatSession) -> some View {
        ChatSessionRow(
            session: session,
            isRenaming: renamingSessionID == session.id,
            renameText: $renameText
        )
        .tag(session.id)
        .contextMenu {
            Button {
                session.isPinned.toggle()
                try? modelContext.save()
            } label: {
                Label(
                    session.isPinned ? "Unpin" : "Pin",
                    systemImage: session.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                renameText = session.title
                renamingSessionID = session.id
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                let profile = providerService.resolvedProfile(for: session, profiles: profiles)
                let model = providerService.resolvedModel(for: session, profiles: profiles)
                TranscriptExporter.presentSavePanel(
                    session: session,
                    modelName: model,
                    providerName: profile?.name
                )
            } label: {
                Label("Export as Markdown…", systemImage: "doc.text")
            }

            Divider()

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

            Divider()

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

    SidebarView(selectedSessionID: $selectedID, assistants: [], onNewChat: { _ in })
        .frame(width: 280, height: 500)
        .modelContainer(container)
}
