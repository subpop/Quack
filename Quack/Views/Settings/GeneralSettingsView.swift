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

struct GeneralSettingsView: View {
    @ObservedObject var updater: SoftwareUpdater

    @AppStorage("appearanceMode") private var appearanceMode: AppAppearance = .system

    var body: some View {
        Form {
            LabeledContent("Appearance") {
                AppearancePicker(selection: $appearanceMode)
            }

            Section("Updates") {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    )
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance Picker

private struct AppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppAppearance.allCases) { mode in
                AppearanceOption(
                    mode: mode,
                    isSelected: selection == mode
                ) {
                    selection = mode
                }
            }
        }
    }
}

private struct AppearanceOption: View {
    let mode: AppAppearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                AppearanceThumbnail(mode: mode)
                    .clipShape(.rect(cornerRadius: 5))
                    .padding(2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                isSelected ? Color.accentColor : .clear,
                                lineWidth: 3
                            )
                    }

                Text(mode.label)
                    .font(.callout)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appearance Thumbnail

private struct AppearanceThumbnail: View {
    let mode: AppAppearance

    private static let thumbnailWidth: CGFloat = 90
    private static let thumbnailHeight: CGFloat = 64

    var body: some View {
        switch mode {
        case .light:
            singleVariant(isDark: false)
        case .dark:
            singleVariant(isDark: true)
        case .system:
            systemThumbnail
        }
    }

    // MARK: Light / Dark

    private func singleVariant(isDark: Bool) -> some View {
        desktopScene(isDark: isDark)
            .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
    }

    // MARK: Auto (split)

    private var systemThumbnail: some View {
        HStack(spacing: 0) {
            desktopScene(isDark: false)
                .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
                .clipped()
                .frame(width: Self.thumbnailWidth / 2, alignment: .leading)
                .clipped()

            desktopScene(isDark: true)
                .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
                .clipped()
                .frame(width: Self.thumbnailWidth / 2, alignment: .trailing)
                .clipped()
        }
    }

    // MARK: Desktop Scene

    /// A miniature desktop with wallpaper gradient and two overlapping windows.
    private func desktopScene(isDark: Bool) -> some View {
        let wallpaper = isDark
            ? LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.25),
                    Color(red: 0.15, green: 0.10, blue: 0.35),
                    Color(red: 0.10, green: 0.12, blue: 0.30),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            : LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.60, blue: 0.85),
                    Color(red: 0.55, green: 0.50, blue: 0.80),
                    Color(red: 0.40, green: 0.55, blue: 0.78),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )

        return ZStack {
            wallpaper

            // Back window (peeking behind)
            miniWindow(isDark: isDark)
                .scaleEffect(0.85)
                .offset(x: -6, y: -4)

            // Front window
            miniWindow(isDark: isDark)
                .scaleEffect(0.85)
                .offset(x: 6, y: 4)
        }
    }

    // MARK: Mini Window

    private func miniWindow(isDark: Bool) -> some View {
        let body = isDark
            ? Color(white: 0.18)
            : Color(white: 0.96)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(body)

            HStack(spacing: 2) {
                Circle().fill(.red.opacity(0.85)).frame(width: 3.5, height: 3.5)
                Circle().fill(.yellow.opacity(0.85)).frame(width: 3.5, height: 3.5)
                Circle().fill(.green.opacity(0.85)).frame(width: 3.5, height: 3.5)
            }
            .padding(4)
        }
        .frame(width: 56, height: 40)
        .clipShape(.rect(cornerRadius: 4))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

// MARK: - AppStorage Conformance

extension AppAppearance: RawRepresentable {}

// MARK: - Preview

#Preview {
    GeneralSettingsView(updater: SoftwareUpdater())
        .frame(width: 500)
}
