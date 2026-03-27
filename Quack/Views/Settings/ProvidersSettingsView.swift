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

struct ProvidersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    @State private var editingProfile: ProviderProfile?
    @State private var profileToDelete: ProviderProfile?
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(profiles) { profile in
                    ProfileRow(profile: profile)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingProfile = profile
                    }
                    .contextMenu {
                        Button("Edit\u{2026}") {
                            editingProfile = profile
                        }

                        Divider()

                        Toggle("Enabled", isOn: Binding(
                            get: { profile.isEnabled },
                            set: { newValue in
                                profile.isEnabled = newValue
                                try? modelContext.save()
                                providerService.invalidateCache()
                            }
                        ))

                        Divider()

                        Button("Delete\u{2026}", role: .destructive) {
                            profileToDelete = profile
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Add a Provider\u{2026}") {
                    showingAddSheet = true
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(item: $editingProfile) { profile in
            ProviderDetailSheet(profile: profile)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProviderSheet { profile in
                editingProfile = profile
            }
        }
        .alert(
            "Delete Provider",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    removeProfile(profile)
                }
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \"\(profile.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func removeProfile(_ profile: ProviderProfile) {
        KeychainService.delete(key: KeychainService.apiKeyKey(for: profile.id))
        modelContext.delete(profile)
        try? modelContext.save()
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let profile: ProviderProfile

    var body: some View {
        HStack(spacing: 12) {
            // Rounded-square icon like Xcode
            providerIcon
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(.medium)
                Text(profile.platform.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !profile.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var providerIcon: some View {
        if profile.iconIsCustom {
            profile.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            profile.icon
                .font(.title2)
        }
    }

    private var iconColor: Color {
        profile.iconColor
    }
}

// MARK: - Add Provider Sheet

private struct AddProviderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    var onAdd: (ProviderProfile) -> Void

    @State private var selectedPreset: ProviderPreset = .ollama

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                presetIcon(for: selectedPreset, size: 32)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(presetColor.gradient)
                    )

                Text("Add a Provider")
                    .font(.headline)
                Text("Choose a provider to get started quickly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Preset picker — grid of labelled buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ProviderPreset.allCases) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPreset = preset
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    addProfile()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 380)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func presetIcon(for preset: ProviderPreset, size: CGFloat) -> some View {
        if preset.isCustomIcon {
            preset.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            preset.icon
                .font(.system(size: size * 0.75))
        }
    }

    private var presetColor: Color {
        switch selectedPreset {
        case .ollama:     .gray
        case .openAI:     .green
        case .anthropic:  .orange
        case .gemini:     .blue
        case .openRouter: .purple
        case .groq:       .indigo
        case .together:   .cyan
        case .mistral:    .orange
        case .custom:     .secondary
        }
    }

    private func addProfile() {
        let profile = selectedPreset.makeProfile(sortOrder: profiles.count)
        modelContext.insert(profile)
        try? modelContext.save()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onAdd(profile)
        }
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let preset: ProviderPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                presetIcon
                    .frame(height: 24)

                Text(preset.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var presetIcon: some View {
        if preset.isCustomIcon {
            preset.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            preset.icon
                .font(.title2)
        }
    }
}

#Preview("Provider List") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    ProvidersSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}

#Preview("Add Provider Sheet") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    AddProviderSheet { _ in }
        .previewEnvironment(container: container)
}
