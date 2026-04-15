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
import QuackKit
import MLXLMCommon
import os

@main
struct QuackApp: App {
    @StateObject private var updater = SoftwareUpdater()

    @State private var providerService = ProviderService()
    @State private var chatService = ChatService()
    @State private var mcpService = MCPService()
    @State private var builtInToolService = BuiltInToolService()
    @State private var modelListService = ModelListService()
    @State private var notificationService = NotificationService()
    @State private var modelPricingService = ModelPricingService()
    @State private var mlxModelService: MLXModelService
    @State private var mlxModelServiceBox: MLXModelServiceBox

    @Environment(\.openWindow) private var openWindow

    init() {
        let service = MLXModelService()
        _mlxModelService = State(initialValue: service)
        _mlxModelServiceBox = State(initialValue: MLXModelServiceBox(service: service))

        // Inject build-time secrets into the framework.
        SecretsProvider.tavilyAPIKey = Secrets.tavilyAPIKey

        // Register the provider client factory so ProviderPlatform can
        // construct LLM clients without importing provider-specific modules.
        ProviderPlatform.clientFactory = { platform, baseURL, apiKey, model, maxTokens, contextWindowSize, reasoningConfig, retryPolicy, cachingEnabled, projectID, location, mlxContainer in
            switch platform {
            case .openAICompatible:
                return OpenAIClientFactory.makeClient(
                    baseURL: baseURL, apiKey: apiKey, model: model,
                    maxTokens: maxTokens, contextWindowSize: contextWindowSize,
                    reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                    cachingEnabled: cachingEnabled)
            case .anthropic:
                return AnthropicClientFactory.makeClient(
                    baseURL: baseURL, apiKey: apiKey, model: model,
                    maxTokens: maxTokens, contextWindowSize: contextWindowSize,
                    reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                    cachingEnabled: cachingEnabled)
            case .foundationModels:
                return FoundationModelsClientFactory.makeClient()
            case .gemini:
                return GeminiClientFactory.makeClient(
                    apiKey: apiKey, model: model, maxTokens: maxTokens,
                    contextWindowSize: contextWindowSize,
                    reasoningConfig: reasoningConfig, retryPolicy: retryPolicy)
            case .vertexGemini:
                return VertexGoogleClientFactory.makeClient(
                    model: model, maxTokens: maxTokens,
                    contextWindowSize: contextWindowSize,
                    reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                    projectID: projectID, location: location)
            case .vertexAnthropic:
                return VertexAnthropicClientFactory.makeClient(
                    model: model, maxTokens: maxTokens,
                    contextWindowSize: contextWindowSize,
                    reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                    cachingEnabled: cachingEnabled,
                    projectID: projectID, location: location)
            case .mlx:
                return MLXClientFactory.makeClient(
                    container: mlxContainer as? MLXLMCommon.ModelContainer, model: model,
                    maxTokens: maxTokens, contextWindowSize: contextWindowSize)
            }
        }

        // Register the model list factory so ProviderPlatform can list
        // available models from provider APIs.
        ProviderPlatform.modelListFactory = { platform, baseURL, apiKey, projectID, location in
            switch platform {
            case .openAICompatible:
                return try await OpenAIClientFactory.listModels(baseURL: baseURL, apiKey: apiKey)
            case .gemini:
                return try await GeminiClientFactory.listModels(apiKey: apiKey)
            case .vertexGemini:
                return try await VertexGoogleClientFactory.listModels(projectID: projectID, location: location)
            default:
                return []
            }
        }
    }

    var sharedModelContainer: SwiftData.ModelContainer = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        #if DEBUG
        let storeURL = appSupport
            .appendingPathComponent("app.subpop.Quack")
            .appendingPathComponent("QuackDebug.store")
        #else
        let storeURL = appSupport
            .appendingPathComponent("app.subpop.Quack")
            .appendingPathComponent("Quack.store")
        #endif

        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let config = ModelConfiguration(url: storeURL)

        do {
            return try ModelContainer(
                for: ChatSession.self, ChatMessageRecord.self,
                     ProviderProfile.self, MCPServerConfig.self,
                     Assistant.self,
                migrationPlan: QuackMigrationPlan.self,
                configurations: config
            )
        } catch {
            Logger.database.error(
                "Failed to create persistent ModelContainer, falling back to in-memory store: \(error)"
            )
            do {
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: ChatSession.self, ChatMessageRecord.self,
                         ProviderProfile.self, MCPServerConfig.self,
                         Assistant.self,
                    configurations: fallbackConfig
                )
            } catch {
                fatalError("Cannot create even an in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environment(\.providerService, providerService)
                .environment(\.chatService, chatService)
                .environment(\.mcpService, mcpService)
                .environment(\.builtInToolService, builtInToolService)
                .environment(\.modelListService, modelListService)
                .environment(modelPricingService)
                .environment(\.mlxModelServiceBox, mlxModelServiceBox)
                .task {
                    chatService.notificationService = notificationService
                    chatService.titleGenerator = { message in
                        await TextGenerationService.generateTitle(for: message)
                    }
                    notificationService.requestAuthorization()
                    providerService.mlxModelService = mlxModelService
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Export Transcript…") {
                    NotificationCenter.default.post(name: .exportTranscript, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            SidebarCommands()
            CommandGroup(after: .singleWindowList) {
                Button("Quack", systemImage: "macwindow") {
                    if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                        window.deminiaturize(nil)
                        window.makeKeyAndOrderFront(nil)
                        NSApplication.shared.activate()
                    } else {
                        openWindow(id: "main")
                    }
                }
                .keyboardShortcut("0")
            }
        }

        Settings {
            SettingsView(updater: updater)
                .environment(\.providerService, providerService)
                .environment(\.chatService, chatService)
                .environment(\.mcpService, mcpService)
                .environment(\.builtInToolService, builtInToolService)
                .environment(\.modelListService, modelListService)
                .environment(modelPricingService)
                .environment(\.mlxModelServiceBox, mlxModelServiceBox)
                .modelContainer(sharedModelContainer)
        }
    }
}

extension Notification.Name {
    static let newChat = Notification.Name("newChat")
    static let exportTranscript = Notification.Name("exportTranscript")
}

extension Logger {
    static let database = Logger(subsystem: "com.quack.app", category: "database")
}
