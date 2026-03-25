import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Environment(ChatService.self) private var chatService
    @Environment(MCPService.self) private var mcpService

    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var allSessions: [ChatSession]
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    @State private var selectedSessionID: UUID?
    @State private var showInspector = false
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    private var selectedSession: ChatSession? {
        allSessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedSessionID: $selectedSessionID,
                onNewChat: createNewChat
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
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
                    Text("Select a chat from the sidebar or create a new one.")
                } actions: {
                    Button("New Chat", action: createNewChat)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .disabled(selectedSession == nil)
            }
        }
        .onAppear {
            seedProvidersIfNeeded()
        }
    }

    private func createNewChat() {
        let defaultProvider = providerService.defaultProvider(from: providers)
        let session = ChatSession(
            providerID: defaultProvider?.id,
            modelIdentifier: nil
        )
        modelContext.insert(session)
        try? modelContext.save()
        selectedSessionID = session.id
    }

    /// On first launch, seed the built-in provider definitions.
    private func seedProvidersIfNeeded() {
        guard providers.isEmpty else { return }
        for provider in Provider.builtInProviders() {
            modelContext.insert(provider)
        }
        try? modelContext.save()

        // Set the first enabled provider as default
        if let first = providers.first(where: \.isEnabled) {
            providerService.defaultProviderID = first.id
        }
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    MainView()
        .previewEnvironment(container: container)
        .frame(width: 800, height: 600)
}
