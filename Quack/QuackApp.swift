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

    @Environment(\.openWindow) private var openWindow

    var sharedModelContainer: ModelContainer = {
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
                .environment(providerService)
                .environment(chatService)
                .environment(mcpService)
                .environment(builtInToolService)
                .environment(modelListService)
                .environment(modelPricingService)
                .task {
                    chatService.notificationService = notificationService
                    notificationService.requestAuthorization()
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
                .environment(providerService)
                .environment(chatService)
                .environment(mcpService)
                .environment(builtInToolService)
                .environment(modelListService)
                .environment(modelPricingService)
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
