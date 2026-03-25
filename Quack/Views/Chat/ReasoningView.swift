import SwiftUI

struct ReasoningView: View {
    let reasoning: String
    let isStreaming: Bool

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(reasoning)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .foregroundStyle(.purple)
                Text("Thinking")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .padding(8)
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview("Streaming") {
    ReasoningView(
        reasoning: "The user is asking about Swift. I should cover its key features and platform support.",
        isStreaming: true
    )
    .padding()
    .frame(width: 400)
}

#Preview("Complete") {
    ReasoningView(
        reasoning: "The user is asking about Swift. I should cover its key features, safety model, and platform support across Apple's ecosystem.",
        isStreaming: false
    )
    .padding()
    .frame(width: 400)
}
