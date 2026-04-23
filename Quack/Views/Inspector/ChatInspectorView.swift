// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import QuackInterface

/// The tabs available in the chat inspector, displayed as an icon-only segmented control.
enum ChatInspectorTab: String, CaseIterable, Identifiable, InspectorTabItem {
    case session
    case model
    case prompt
    case tools
    case context

    nonisolated var id: String { rawValue }

    nonisolated var icon: String {
        switch self {
        case .session: "chart.bar.fill"
        case .model: "cpu"
        case .prompt: "text.quote"
        case .tools: "wrench.and.screwdriver"
        case .context: "brain"
        }
    }

    nonisolated var label: String {
        switch self {
        case .session: "Session"
        case .model: "Model & Parameters"
        case .prompt: "System Prompt"
        case .tools: "Tools"
        case .context: "Context & Skills"
        }
    }
}

/// An inspector panel that displays detailed chat session configuration organized into
/// Xcode-style icon-only segmented tabs.
struct ChatInspectorView: View {
    @Bindable var session: ChatSession

    @State private var selectedTab: ChatInspectorTab = .session

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabBar(selection: $selectedTab, tabs: ChatInspectorTab.allCases)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()

            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .session:
            InspectorSessionTab(session: session)
        case .model:
            InspectorModelTab(session: session)
        case .prompt:
            InspectorPromptTab(session: session)
        case .tools:
            InspectorToolsTab(session: session)
        case .context:
            InspectorContextTab(session: session)
        }
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    ChatInspectorView(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 700)
}
