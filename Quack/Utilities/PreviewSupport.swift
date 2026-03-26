import SwiftUI
import SwiftData

/// Shared preview infrastructure for Quack views.
/// Provides an in-memory ModelContainer, seeded sample data, and environment services.
enum PreviewSupport {
    /// An in-memory ModelContainer with all Quack model types.
    @MainActor
    static var container: ModelContainer {
        let schema = Schema([
            ChatSession.self,
            ChatMessageRecord.self,
            Provider.self,
            MCPServerConfig.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    /// Seed the container with sample data and return key objects.
    @MainActor
    static func seed(_ container: ModelContainer) -> SeedData {
        let context = container.mainContext

        // Providers
        let providers = Provider.previewProviders()
        for p in providers { context.insert(p) }

        let openAI = providers[0]
        openAI.isEnabled = true

        // MCP Server
        let mcpServer = MCPServerConfig(
            name: "Example MCP",
            command: "/usr/local/bin/example-mcp",
            arguments: ["--stdio"],
            isEnabled: true
        )
        context.insert(mcpServer)

        // Chat sessions
        let session1 = ChatSession(
            title: "Hello World",
            providerID: openAI.id
        )
        context.insert(session1)

        let userMsg = ChatMessageRecord(role: .user, content: "What is Swift?")
        userMsg.session = session1
        session1.messages.append(userMsg)

        let assistantMsg = ChatMessageRecord(
            role: .assistant,
            content: "Swift is a powerful and intuitive programming language developed by Apple.\n\nIt is used for building apps across all Apple platforms:\n\n- **iOS** and **iPadOS**\n- **macOS**\n- **watchOS** and **tvOS**\n\nSwift is designed to be safe, fast, and expressive.",
            reasoning: "The user is asking about the Swift programming language. I should provide a concise overview.",
            inputTokens: 12,
            outputTokens: 85,
            reasoningTokens: 20
        )
        assistantMsg.session = session1
        session1.messages.append(assistantMsg)

        let session2 = ChatSession(title: "Pinned Chat")
        session2.isPinned = true
        context.insert(session2)

        let session3 = ChatSession(title: "Archived Chat")
        session3.isArchived = true
        context.insert(session3)

        let emptySession = ChatSession(title: "New Chat")
        context.insert(emptySession)

        try? context.save()

        return SeedData(
            providers: providers,
            mcpServer: mcpServer,
            session: session1,
            emptySession: emptySession,
            userMessage: userMsg,
            assistantMessage: assistantMsg
        )
    }

    struct SeedData {
        let providers: [Provider]
        let mcpServer: MCPServerConfig
        let session: ChatSession
        let emptySession: ChatSession
        let userMessage: ChatMessageRecord
        let assistantMessage: ChatMessageRecord
    }

    // MARK: - Services

    @MainActor static let providerService = ProviderService()
    @MainActor static let chatService = ChatService()
    @MainActor static let mcpService = MCPService()
}

// MARK: - View Modifier for Preview Environment

extension View {
    /// Apply the full Quack preview environment (services + model container).
    @MainActor
    func previewEnvironment(container: ModelContainer) -> some View {
        self
            .modelContainer(container)
            .environment(PreviewSupport.providerService)
            .environment(PreviewSupport.chatService)
            .environment(PreviewSupport.mcpService)
    }
}
