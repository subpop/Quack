import SwiftUI

struct ToolCallView: View {
    let toolCall: ChatService.ActiveToolCall

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.callout)

            Text(toolCall.name)
                .font(.callout.monospaced())

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
                    Text(String(error.prefix(40)))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(8)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
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

#Preview("Running") {
    ToolCallView(toolCall: .init(id: "1", name: "read_file", state: .running))
        .padding()
        .frame(width: 350)
}

#Preview("Completed") {
    ToolCallView(toolCall: .init(id: "2", name: "search_code", state: .completed("Found 3 matches")))
        .padding()
        .frame(width: 350)
}

#Preview("Failed") {
    ToolCallView(toolCall: .init(id: "3", name: "execute_command", state: .failed("Permission denied")))
        .padding()
        .frame(width: 350)
}
