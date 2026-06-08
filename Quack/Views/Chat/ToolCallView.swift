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
import QuackInterface

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
        case pendingApproval(arguments: String, description: String)
        case denied(reason: String?)
        case completed(String)
        case failed(String)
    }

    /// Create from a live streaming tool call.
    init(from active: ActiveToolCall) {
        self.id = active.id
        self.name = active.name
        self.arguments = active.arguments
        switch active.state {
        case .running:
            self.state = .running
        case .pendingApproval(let args, let desc):
            self.state = .pendingApproval(arguments: args, description: desc)
        case .denied(let reason):
            self.state = .denied(reason: reason)
        case .completed(let r):
            self.state = .completed(r)
        case .failed(let e):
            self.state = .failed(e)
        }
    }

    /// Create from a persisted completed tool call.
    init(from completed: CompletedToolCallData) {
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

    /// Action to approve a pending tool call, provided by the parent view.
    var onApprove: ((String) -> Void)? = nil
    /// Action to deny a pending tool call, provided by the parent view.
    var onDeny: ((String) -> Void)? = nil

    @State private var isExpanded = false

    private var isFinished: Bool {
        switch toolCall.state {
        case .running, .pendingApproval: false
        case .completed, .failed, .denied: true
        }
    }

    private var isExpandable: Bool {
        switch toolCall.state {
        case .completed, .failed, .denied: true
        case .pendingApproval: true
        case .running: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                if isExpandable {
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
                    case .pendingApproval:
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .foregroundStyle(.orange)
                    case .denied:
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.red)
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

                    if isExpandable {
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

            // Approval buttons — shown inline when pending
            if case .pendingApproval(let arguments, _) = toolCall.state {
                Divider()
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if !arguments.isEmpty {
                        structuredDetailSection(title: "Parameters", jsonString: arguments)
                    }

                    HStack(spacing: 12) {
                        Button {
                            onApprove?(toolCall.id)
                        } label: {
                            Label("Allow", systemImage: "checkmark.shield.fill")
                                .font(.callout.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)

                        Button {
                            onDeny?(toolCall.id)
                        } label: {
                            Label("Deny", systemImage: "hand.raised.fill")
                                .font(.callout.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)

                        Spacer()
                    }
                }
                .padding(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Detail — arguments + result (expandable for finished states)
            if isFinished && isExpanded {
                Divider()
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 8) {
                    // Arguments
                    if let args = toolCall.arguments, !args.isEmpty {
                        structuredDetailSection(title: "Parameters", jsonString: args)
                    }

                    // Result / status
                    switch toolCall.state {
                    case .completed(let result):
                        if !result.isEmpty {
                            structuredDetailSection(title: "Result", jsonString: result)
                        }
                    case .failed(let error):
                        structuredDetailSection(title: "Error", jsonString: error, fallbackStyle: .red)
                    case .denied(let reason):
                        if let reason, !reason.isEmpty {
                            structuredDetailSection(title: "Denied", jsonString: reason, fallbackStyle: .red)
                        }
                    case .running, .pendingApproval:
                        EmptyView()
                    }
                }
                .padding(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Renders a JSON string as a structured key-value tree, falling back to
    /// plain text if the string isn't valid JSON.
    private func structuredDetailSection(
        title: String,
        jsonString: String,
        fallbackStyle: Color = .secondary
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)

            Group {
                if let jsonValue = JSONValue.parse(jsonString) {
                    StructuredContentView(jsonValue)
                } else {
                    Text(jsonString)
                        .font(.caption.monospaced())
                        .foregroundStyle(fallbackStyle)
                        .lineLimit(12)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var iconName: String {
        switch toolCall.state {
        case .running: "wrench.and.screwdriver"
        case .pendingApproval: "shield.lefthalf.filled"
        case .denied: "hand.raised.fill"
        case .completed, .failed: "wrench.and.screwdriver.fill"
        }
    }

    private var iconColor: Color {
        switch toolCall.state {
        case .running: .accentColor
        case .pendingApproval: .orange
        case .denied: .red
        case .completed: .green
        case .failed: .red
        }
    }
}

// MARK: - Previews

#Preview("Running") {
    ToolCallView(toolCall: ToolCallDisplayData(
        from: ActiveToolCall(id: "1", name: "read_file", state: .running)
    ))
    .padding()
    .frame(width: 400)
}

#Preview("Pending Approval") {
    ToolCallView(
        toolCall: ToolCallDisplayData(
            from: ActiveToolCall(
                id: "4", name: "execute_command",
                state: .pendingApproval(
                    arguments: "{\"command\": \"swift build\"}",
                    description: "Execute a shell command"
                )
            )
        ),
        onApprove: { _ in },
        onDeny: { _ in }
    )
    .padding()
    .frame(width: 400)
}

#Preview("Completed - Collapsed") {
    ToolCallView(toolCall: ToolCallDisplayData(
        from: CompletedToolCallData(
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
        from: CompletedToolCallData(
            id: "3", name: "execute_command",
            arguments: "{\"command\": \"rm -rf /\"}",
            result: "Permission denied: operation not permitted",
            isError: true
        )
    ))
    .padding()
    .frame(width: 400)
}
