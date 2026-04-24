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

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.providerService) private var providerService
    @Environment(\.chatService) private var chatService
    @Environment(\.mcpService) private var mcpService

    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var allSessions: [ChatSession]
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]
    @Query(sort: \Assistant.sortOrder) private var assistants: [Assistant]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    @State private var selectedSessionID: UUID?
    @State private var showInspector = false
    @State private var showNewChatSheet = false
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    private var selectedSession: ChatSession? {
        allSessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedSessionID: $selectedSessionID,
                assistants: assistants,
                onNewChat: { createNewChat(with: $0) },
                onNewChatWithOptions: { showNewChatSheet = true }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            if let session = selectedSession {
                ChatView(session: session)
                    .id(session.id)
                    .inspector(isPresented: $showInspector) {
                        ChatInspectorView(session: session)
                            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
                    }
            } else {
                ContentUnavailableView {
                    Label("No Chat Selected", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Select a conversation from the sidebar or start a new one.")
                } actions: {
                    Button(action: { createNewChat() }) {
                        Text("New Conversation")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: showInspector ? "sidebar.trailing" : "sidebar.trailing")
                }
                .help("Toggle Inspector")
                .disabled(selectedSession == nil)
            }
        }
        .onAppear {
            seedIfNeeded()
            syncMCPServers()
        }
        .onChange(of: mcpServerConfigs.map(\.configSnapshot)) {
            syncMCPServers()
        }
        .onChange(of: selectedSessionID) {
            syncMCPServers()
        }
        .onChange(of: selectedSession?.enabledMCPServerIDsRaw) {
            syncMCPServers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            createNewChat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChatWithOptions)) { _ in
            showNewChatSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportTranscript)) { _ in
            exportActiveSession()
        }
        .sheet(isPresented: $showNewChatSheet) {
            NewChatSheet(assistants: assistants) { assistant, workingDirectory in
                createNewChat(with: assistant, workingDirectory: workingDirectory)
            }
        }
    }

    private func createNewChat(with assistant: Assistant? = nil, workingDirectory: String? = nil) {
        let resolved = assistant ?? assistants.first(where: \.isDefault) ?? assistants.first
        let session: ChatSession
        if let resolved {
            session = ChatSession(assistant: resolved, workingDirectory: workingDirectory)
        } else {
            // Fallback if no assistants exist yet (shouldn't happen after seeding)
            session = ChatSession(profile: providerService.fallbackProfile(from: profiles), workingDirectory: workingDirectory)
        }
        modelContext.insert(session)
        try? modelContext.save()
        selectedSessionID = session.id
    }

    private func exportActiveSession() {
        guard let session = selectedSession else { return }
        let profile = providerService.resolvedProfile(for: session, profiles: profiles)
        let model = providerService.resolvedModel(for: session, profiles: profiles)
        TranscriptExporter.presentSavePanel(
            session: session,
            modelName: model,
            providerName: profile?.name
        )
    }

    /// Sync MCP server connections to match what the current session needs.
    ///
    /// Only servers that are both globally enabled and enabled for the current
    /// session will be running. When switching sessions, servers that the new
    /// session doesn't need are stopped, and servers it does need are started.
    private func syncMCPServers() {
        guard let session = selectedSession else {
            mcpService.disconnectAll()
            return
        }

        let enabledIDs = session.enabledMCPServerIDs ?? []
        // Only include servers that are also globally enabled
        let globallyEnabled = Set(mcpServerConfigs.filter(\.isEnabled).map(\.id))
        let desired = Set(enabledIDs).intersection(globallyEnabled)

        mcpService.syncServers(desired: desired, allConfigs: mcpServerConfigs)
    }

    /// On first launch, seed the built-in provider profiles and default assistant.
    private func seedIfNeeded() {
        if profiles.isEmpty {
            for profile in ProviderProfile.builtInProfiles() {
                modelContext.insert(profile)
            }
            try? modelContext.save()
        }

        if assistants.isEmpty {
            let firstEnabled = profiles.first(where: \.isEnabled)

            let general = Assistant.defaultAssistant()
            if let firstEnabled {
                general.providerIDString = firstEnabled.id.uuidString
            }
            modelContext.insert(general)

            let coding = Assistant.codingAssistant()
            if let firstEnabled {
                coding.providerIDString = firstEnabled.id.uuidString
            }
            modelContext.insert(coding)

            try? modelContext.save()
        }
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    MainView()
        .previewEnvironment(container: container)
        .frame(width: 700, height: 650)
}
