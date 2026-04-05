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

/// Renders a sequence of `MarkdownBlock`s, delegating text blocks to
/// `Text(attributedString)` and table blocks to `MarkdownTableView`.
///
/// Each block is wrapped in the standard chat-bubble styling (rounded
/// rectangle background with padding).
struct MarkdownContentView: View {
    let blocks: [MarkdownBlock]

    var body: some View {
        ForEach(blocks) { block in
            switch block {
            case .attributedString(let content):
                Text(content)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Color(.controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

            case .table(let table):
                MarkdownTableView(table: table)
                    .padding(.vertical, 6)
                    .background(
                        Color(.controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
    }
}

#Preview("Mixed Content") {
    let blocks = MarkdownRenderer.renderBlocks("""
    Here is a summary of the data:

    | Name | Score | Grade |
    |------|------:|:-----:|
    | Alice | 95 | A |
    | Bob | 87 | B+ |
    | Charlie | 72 | C |

    The average score across all students is **84.7**.
    """)

    VStack(alignment: .leading, spacing: 6) {
        MarkdownContentView(blocks: blocks)
    }
    .padding(.trailing, 60)
    .padding(.horizontal, 16)
    .frame(width: 500, alignment: .leading)
}
