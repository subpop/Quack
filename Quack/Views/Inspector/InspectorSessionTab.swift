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
import SwiftData
import UniformTypeIdentifiers
import QuackInterface

/// Displays session statistics including token counts, a distribution bar, and estimated cost.
struct InspectorSessionTab: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.providerService) private var providerService
    @Environment(ModelPricingService.self) private var modelPricingService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    @State private var showFolderPicker = false

    var body: some View {
        Form {
            workingDirectorySection

            Section("Session") {
                let stats = sessionStats

                // Stat cards grid
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ]

                LazyVGrid(columns: columns, spacing: 10) {
                    statCard(
                        icon: "arrow.up.circle.fill",
                        color: .blue,
                        value: stats.inputTokens,
                        label: "Input"
                    )

                    statCard(
                        icon: "arrow.down.circle.fill",
                        color: .green,
                        value: stats.outputTokens,
                        label: "Output"
                    )

                    if stats.reasoningTokens > 0 {
                        statCard(
                            icon: "brain.fill",
                            color: .orange,
                            value: stats.reasoningTokens,
                            label: "Reasoning"
                        )
                    }

                    statCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        color: .secondary,
                        value: stats.messageCount,
                        label: "Messages"
                    )
                }
                .animation(.easeInOut(duration: 0.3), value: stats)

                // Token distribution bar
                if stats.totalTokens > 0 {
                    tokenDistributionBar(stats: stats)
                        .padding(.top, 4)
                }

                // Cost row
                costDisplay(stats: stats)
                    .padding(.top, 2)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Stat Card

    private func statCard(icon: String, color: Color, value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text(value.formatted())
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.easeInOut(duration: 0.4), value: value)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Token Distribution Bar

    private func tokenDistributionBar(stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Token Distribution")
                .font(.caption2)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let total = max(stats.totalTokens, 1)
                let inputFraction = CGFloat(stats.inputTokens) / CGFloat(total)
                let outputFraction = CGFloat(stats.outputTokens) / CGFloat(total)
                let reasoningFraction = CGFloat(stats.reasoningTokens) / CGFloat(total)

                HStack(spacing: 2) {
                    if stats.inputTokens > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.blue)
                            .frame(width: max(inputFraction * geo.size.width - 2, 4))
                    }
                    if stats.outputTokens > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.green)
                            .frame(width: max(outputFraction * geo.size.width - 2, 4))
                    }
                    if stats.reasoningTokens > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.orange)
                            .frame(width: max(reasoningFraction * geo.size.width - 2, 4))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: stats)
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // Legend
            HStack(spacing: 12) {
                legendDot(color: .blue, label: "Input")
                legendDot(color: .green, label: "Output")
                if stats.reasoningTokens > 0 {
                    legendDot(color: .orange, label: "Reasoning")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Cost Display

    private func costDisplay(stats: SessionStats) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                Text("Estimated Cost")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let cost = stats.estimatedCost {
                    Text(cost, format: .currency(code: "USD").precision(.fractionLength(2...4)))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: cost)
                } else {
                    Text("N/A")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Working Directory

    @ViewBuilder
    private var workingDirectorySection: some View {
        Section {
            if let workDir = session.workingDirectory, !workDir.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Project Session")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(directoryDisplayName(workDir))
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()
                    }

                    Text(workDir)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        Button("Change\u{2026}") {
                            showFolderPicker = true
                        }
                        .controlSize(.small)

                        Button("Clear") {
                            session.workingDirectory = nil
                            try? modelContext.save()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("General Session")
                            .font(.system(.body, design: .rounded, weight: .medium))

                        Text("No working directory set")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Set\u{2026}") {
                        showFolderPicker = true
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Working Directory")
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                session.workingDirectory = url.path(percentEncoded: false)
                try? modelContext.save()
            }
        }
    }

    /// Extracts the last path component as a display name for the directory.
    private func directoryDisplayName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    // MARK: - Stats Computation

    private var sessionStats: SessionStats {
        let assistantMessages = session.messages.filter { $0.role == .assistant }
        let userMessages = session.messages.filter { $0.role == .user }

        let inputTokens = assistantMessages.compactMap(\.inputTokens).reduce(0, +)
        let outputTokens = assistantMessages.compactMap(\.outputTokens).reduce(0, +)
        let reasoningTokens = assistantMessages.compactMap(\.reasoningTokens).reduce(0, +)
        let messageCount = userMessages.count + assistantMessages.count

        let profile = providerService.resolvedProfile(for: session, profiles: profiles)
        let model = providerService.resolvedModel(for: session, profiles: profiles)
        let platform = profile?.platform ?? .openAICompatible

        let estimatedCost: Double?
        if inputTokens > 0 || outputTokens > 0,
           let pricing = modelPricingService.price(
               for: model,
               platform: platform,
               modelsDevProviderID: profile?.modelsDevProviderID
           ) {
            estimatedCost = pricing.cost(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                reasoningTokens: reasoningTokens
            )
        } else {
            estimatedCost = nil
        }

        return SessionStats(
            messageCount: messageCount,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            reasoningTokens: reasoningTokens,
            estimatedCost: estimatedCost
        )
    }
}

// MARK: - Session Stats

struct SessionStats: Equatable {
    let messageCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
    let estimatedCost: Double?

    var totalTokens: Int { inputTokens + outputTokens + reasoningTokens }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    InspectorSessionTab(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 500)
}
