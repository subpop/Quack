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

/// Shared preview infrastructure for Quack views.
/// Provides an in-memory ModelContainer, seeded sample data, and environment services.
enum PreviewSupport {
    /// An in-memory ModelContainer with all Quack model types.
    @MainActor
    static var container: ModelContainer {
        let schema = Schema([
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
            MCPServerConfig.self,
            Assistant.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    /// Seed the container with sample data and return key objects.
    @MainActor
    static func seed(_ container: ModelContainer) -> SeedData {
        let context = container.mainContext

        // Provider Profiles
        let profiles = ProviderProfile.previewProfiles()
        for p in profiles { context.insert(p) }

        let openAI = profiles[0]
        openAI.isEnabled = true

        // Assistants
        let defaultAssistant = Assistant.defaultAssistant()
        defaultAssistant.providerIDString = openAI.id.uuidString
        context.insert(defaultAssistant)

        let codeAssistant = Assistant(
            name: "Code Review",
            systemPrompt: "You are a code review assistant. Focus on correctness, performance, and maintainability.",
            sortOrder: 1
        )
        codeAssistant.iconName = "chevron.left.forwardslash.chevron.right"
        codeAssistant.colorRaw = "orange"
        context.insert(codeAssistant)

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
            profile: openAI
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
            profiles: profiles,
            assistants: [defaultAssistant, codeAssistant],
            mcpServer: mcpServer,
            session: session1,
            emptySession: emptySession,
            userMessage: userMsg,
            assistantMessage: assistantMsg
        )
    }

    struct SeedData {
        let profiles: [ProviderProfile]
        let assistants: [Assistant]
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
    @MainActor static let modelListService = ModelListService()
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
            .environment(PreviewSupport.modelListService)
    }
}
