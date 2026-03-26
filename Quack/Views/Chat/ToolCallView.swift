import SwiftUI

// MARK: - Unified Tool Call Display Data

/// A view-level representation of a tool call, used by both live streaming
/// and persisted message display.
struct ToolCallDisplayData: Identifiable {
    let id: String
    let name: String
    let arguments: String?
    let state: State

    enum State {
        case running
        case completed(String)
        case failed(String)
    }

    /// Create from a live streaming tool call.
    init(from active: ChatService.ActiveToolCall) {
        self.id = active.id
        self.name = active.name
        self.arguments = active.arguments
        switch active.state {
        case .running: self.state = .running
        case .completed(let r): self.state = .completed(r)
        case .failed(let e): self.state = .failed(e)
        }
    }

    /// Create from a persisted completed tool call.
    init(from completed: ChatService.CompletedToolCallData) {
        self.id = completed.id
        self.name = completed.name
        self.arguments = completed.arguments
        self.state = completed.isError
            ? .failed(completed.result ?? "Unknown error")
            : .completed(completed.result ?? "")
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCallDisplayData

    @State private var isExpanded = false

    private var isFinished: Bool {
        switch toolCall.state {
        case .running: false
        case .completed, .failed: true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                if isFinished {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                        .font(.callout)

                    Text(toolCall.name)
                        .font(.callout.monospaced())
                        .foregroundStyle(.primary)

                    Spacer()

                    switch toolCall.state {
                    case .running:
                        ProgressView()
                            .controlSize(.small)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failed(let error):
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(String(error.prefix(30)))
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }

                    if isFinished {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable detail — arguments + result
            if isExpanded {
                Divider()
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 8) {
                    // Arguments
                    if let args = toolCall.arguments, !args.isEmpty {
                        detailSection(title: "Parameters", content: formatJSON(args), style: .secondary)
                    }

                    // Result
                    switch toolCall.state {
                    case .completed(let result):
                        if !result.isEmpty {
                            detailSection(title: "Result", content: result, style: .secondary)
                        }
                    case .failed(let error):
                        detailSection(title: "Error", content: error, style: .red)
                    case .running:
                        EmptyView()
                    }
                }
                .padding(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func detailSection(title: String, content: String, style: some ShapeStyle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)

            Text(content)
                .font(.caption.monospaced())
                .foregroundStyle(style)
                .textSelection(.enabled)
                .lineLimit(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    /// Try to pretty-print JSON, fall back to raw string.
    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8)
        else { return json }
        return result
    }

    private var iconName: String {
        switch toolCall.state {
        case .running: "wrench.and.screwdriver"
        case .completed: "wrench.and.screwdriver.fill"
        case .failed: "wrench.trianglebadge.exclamationmark"
        }
    }

    private var iconColor: Color {
        switch toolCall.state {
        case .running: .accentColor
        case .completed: .green
        case .failed: .red
        }
    }
}

// MARK: - Previews

#Preview("Running") {
    ToolCallView(toolCall: ToolCallDisplayData(
        from: ChatService.ActiveToolCall(id: "1", name: "read_file", state: .running)
    ))
    .padding()
    .frame(width: 400)
}

#Preview("Completed - Collapsed") {
    ToolCallView(toolCall: ToolCallDisplayData(
        from: ChatService.CompletedToolCallData(
            id: "2", name: "search_code",
            arguments: "{\"query\": \"TODO\", \"path\": \"src/\"}",
            result: "Found 3 matches in 2 files:\n- src/main.swift:12\n- src/utils.swift:45\n- src/utils.swift:78",
            isError: false
        )
    ))
    .padding()
    .frame(width: 400)
}

#Preview("Failed - Collapsed") {
    ToolCallView(toolCall: ToolCallDisplayData(
        from: ChatService.CompletedToolCallData(
            id: "3", name: "execute_command",
            arguments: "{\"command\": \"rm -rf /\"}",
            result: "Permission denied: operation not permitted",
            isError: true
        )
    ))
    .padding()
    .frame(width: 400)
}
