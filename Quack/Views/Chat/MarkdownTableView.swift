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

/// Renders a `MarkdownTable` as a SwiftUI `Grid` with clean minimal styling:
/// bold header row, subtle separator, and alternating row backgrounds.
struct MarkdownTableView: View {
    let table: MarkdownTable

    var body: some View {
        let columnCount = table.headers.count

        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            // Header row
            GridRow {
                ForEach(0..<columnCount, id: \.self) { col in
                    cellView(
                        content: table.headers[col],
                        alignment: alignment(for: col),
                        isHeader: true
                    )
                }
            }

            // Separator
            GridRow {
                separator
                    .gridCellColumns(columnCount)
            }

            // Body rows
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { col in
                        let content = col < row.count ? row[col] : AttributedString("")
                        cellView(
                            content: content,
                            alignment: alignment(for: col),
                            isHeader: false
                        )
                        .background(
                            rowIndex % 2 == 1
                                ? Color.primary.opacity(0.03)
                                : Color.clear
                        )
                    }
                }
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Subviews

    private func cellView(
        content: AttributedString,
        alignment: HorizontalAlignment,
        isHeader: Bool
    ) -> some View {
        let textAlignment: TextAlignment = switch alignment {
        case .center: .center
        case .trailing: .trailing
        default: .leading
        }

        return Text(content)
            .font(isHeader ? .callout.weight(.semibold) : .callout)
            .multilineTextAlignment(textAlignment)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func alignment(for column: Int) -> HorizontalAlignment {
        guard column < table.alignments.count else { return .leading }
        return table.alignments[column]
    }
}

#Preview("Simple Table") {
    let table = MarkdownTable(
        headers: [
            AttributedString("Name"),
            AttributedString("Age"),
            AttributedString("City"),
        ],
        alignments: [.leading, .center, .trailing],
        rows: [
            [AttributedString("Alice"), AttributedString("30"), AttributedString("New York")],
            [AttributedString("Bob"), AttributedString("25"), AttributedString("Los Angeles")],
            [AttributedString("Charlie"), AttributedString("35"), AttributedString("Chicago")],
            [AttributedString("Diana"), AttributedString("28"), AttributedString("San Francisco")],
        ]
    )

    MarkdownTableView(table: table)
        .padding()
        .frame(width: 450)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
}
