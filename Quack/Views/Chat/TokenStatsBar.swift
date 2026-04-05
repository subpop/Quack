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

/// A compact bar that shows aggregated input tokens, output tokens, and
/// estimated cost for a chat session. Numbers animate with a sliding digit
/// transition as they change.
struct TokenStatsBar: View {
    let session: ChatSession

    @Environment(ProviderService.self) private var providerService
    @Environment(ModelPricingService.self) private var modelPricingService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    var body: some View {
        let stats = computeStats()

        if stats.inputTokens > 0 || stats.outputTokens > 0 {
            HStack(spacing: 14) {
                tokenItem(
                    symbol: "arrow.up",
                    value: stats.inputTokens
                )

                tokenItem(
                    symbol: "arrow.down",
                    value: stats.outputTokens
                )

                costItem(stats.estimatedCost)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    // MARK: - Subviews

    private func tokenItem(symbol: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .imageScale(.small)
                .foregroundStyle(.tertiary)
            Text(Self.formatCompact(value))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
        }
    }

    private func costItem(_ cost: Double?) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "dollarsign")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
            if let cost {
                Text(Self.formatCost(cost))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: cost)
            } else {
                Text("--")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Stats Computation

    private func computeStats() -> (inputTokens: Int, outputTokens: Int, estimatedCost: Double?) {
        let assistantMessages = session.messages.filter { $0.role == .assistant }

        let inputTokens = assistantMessages.compactMap(\.inputTokens).reduce(0, +)
        let outputTokens = assistantMessages.compactMap(\.outputTokens).reduce(0, +)
        let reasoningTokens = assistantMessages.compactMap(\.reasoningTokens).reduce(0, +)

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

        return (inputTokens, outputTokens, estimatedCost)
    }

    // MARK: - Formatting

    /// Formats a token count compactly: "842", "1.2K", "14K", "1.2M".
    static func formatCompact(_ value: Int) -> String {
        if value < 1_000 {
            return "\(value)"
        } else if value < 10_000 {
            let k = Double(value) / 1_000
            return String(format: "%.1fK", k)
        } else if value < 1_000_000 {
            let k = Double(value) / 1_000
            return String(format: "%.0fK", k)
        } else {
            let m = Double(value) / 1_000_000
            return String(format: "%.1fM", m)
        }
    }

    /// Formats a cost value: "$0.0012" for tiny amounts, "$1.23" for normal
    static func formatCost(_ value: Double) -> String {
        if value < 0.01 {
            return String(format: "%.4f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    TokenStatsBar(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 400)
        .padding()
}
