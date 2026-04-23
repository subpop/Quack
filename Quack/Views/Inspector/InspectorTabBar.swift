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

/// A type that can be displayed as a tab in an ``InspectorTabBar``.
protocol InspectorTabItem: Identifiable, Hashable, Sendable {
    /// The SF Symbol name for the tab icon.
    var icon: String { get }
    /// A human-readable label used for accessibility and tooltips.
    var label: String { get }
}

/// An Xcode-style capsule segmented control for inspector tabs.
///
/// Displays icon-only buttons inside a rounded capsule container. The selected
/// tab is highlighted with an animated tinted capsule behind the icon using
/// `matchedGeometryEffect`.
struct InspectorTabBar<Tab: InspectorTabItem>: View {
    @Binding var selection: Tab
    var tabs: [Tab]
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                tabButton(tab)
            }
        }
        .padding(3)
        .background(.fill.quaternary, in: Capsule())
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 28)
                .foregroundStyle(selection == tab ? .white : .secondary)
                .background {
                    if selection == tab {
                        Capsule()
                            .fill(.tint)
                            .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tab.label)
        .accessibilityLabel(tab.label)
    }
}
