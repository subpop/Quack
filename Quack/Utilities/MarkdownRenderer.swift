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

import Foundation
import Markdown
import SwiftUI

/// A structured block produced by the Markdown renderer.
///
/// Most content is represented as `.attributedString`, but tables are
/// extracted as `.table` so that SwiftUI can render them using a proper
/// grid layout instead of flat inline text.
enum MarkdownBlock: Identifiable {
    case attributedString(AttributedString)
    case table(MarkdownTable)

    var id: String {
        switch self {
        case .attributedString(let s):
            return "text-\(s.hashValue)"
        case .table(let t):
            return "table-\(t.hashValue)"
        }
    }
}

/// A parsed Markdown table with styled header cells, body rows,
/// and column alignment information from GFM syntax.
struct MarkdownTable: Hashable {
    let headers: [AttributedString]
    let alignments: [HorizontalAlignment]
    let rows: [[AttributedString]]

    func hash(into hasher: inout Hasher) {
        hasher.combine(headers.count)
        hasher.combine(rows.count)
        for h in headers { hasher.combine(h.hashValue) }
    }

    static func == (lhs: MarkdownTable, rhs: MarkdownTable) -> Bool {
        lhs.headers == rhs.headers && rhs.rows == lhs.rows
    }
}

enum MarkdownRenderer {
    /// Parse markdown using swift-markdown's CommonMark parser and convert
    /// the resulting AST into an `AttributedString` with proper styling for
    /// paragraphs, headings, lists, code blocks, inline formatting, etc.
    ///
    /// Pre-processes the raw text to insert paragraph breaks before bold
    /// section headers that some models (e.g. Apple Intelligence) jam
    /// inline without any newlines.
    static func renderFull(_ markdown: String) -> AttributedString {
        let cleaned = preprocess(markdown)
        let document = Document(parsing: cleaned)
        var visitor = AttributedStringMarkupVisitor()
        return visitor.visit(document)
    }

    /// Parse markdown and return structured blocks, separating tables
    /// from inline text so they can be rendered with proper grid layout.
    static func renderBlocks(_ markdown: String) -> [MarkdownBlock] {
        let cleaned = preprocess(markdown)
        let document = Document(parsing: cleaned)
        var visitor = AttributedStringMarkupVisitor()

        var blocks: [MarkdownBlock] = []
        var pendingText = AttributedString()
        let children = Array(document.children)

        for (index, child) in children.enumerated() {
            if let table = child as? Markdown.Table {
                // Flush any accumulated text before this table
                if !pendingText.characters.isEmpty {
                    blocks.append(.attributedString(pendingText))
                    pendingText = AttributedString()
                }

                // Build structured table data
                let tableBlock = visitor.buildTable(table)
                blocks.append(.table(tableBlock))
            } else {
                // Add inter-block spacing
                if index > 0 && !pendingText.characters.isEmpty {
                    pendingText += AttributedString("\n\n")
                }
                pendingText += visitor.visit(child)
            }
        }

        // Flush remaining text
        if !pendingText.characters.isEmpty {
            blocks.append(.attributedString(pendingText))
        }

        return blocks
    }

    // MARK: - Pre-processing

    /// Apply all pre-processing fixes for common LLM output quirks.
    private static func preprocess(_ markdown: String) -> String {
        var text = markdown
        text = mergeDetachedListItems(in: text)
        text = separateInlineSections(in: text)
        return text
    }

    /// Merge numbered list markers that are separated from their content by a
    /// blank line.
    ///
    /// Some models (especially Apple Intelligence) output numbered lists as:
    /// ```
    /// 1.
    ///
    /// **Bold Header**: Content...
    ///
    /// 2.
    ///
    /// **Another Header**: More content...
    /// ```
    ///
    /// CommonMark parses `1.\n\n` as an empty list item and the bold paragraph
    /// as a separate block. This method collapses `N.\n\n` into `N. ` so the
    /// content becomes part of the list item.
    private static func mergeDetachedListItems(in markdown: String) -> String {
        // Match: a line that is ONLY a number + period (ordered list marker),
        // followed by a blank line, then content.
        // Replace the marker + blank line with the marker + space on the same line.
        let pattern = #"(?m)^(\d+\.)\s*\n\n"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return markdown
        }

        let mutable = NSMutableString(string: markdown)
        let range = NSRange(location: 0, length: mutable.length)

        let matches = regex.matches(in: markdown, range: range)
        for match in matches.reversed() {
            let markerRange = match.range(at: 1)
            guard markerRange.location != NSNotFound else { continue }
            let marker = mutable.substring(with: markerRange)
            mutable.replaceCharacters(in: match.range, with: "\(marker) ")
        }

        return mutable as String
    }

    /// Insert paragraph breaks before bold text that appears to be a section
    /// header jammed inline after sentence-ending punctuation.
    ///
    /// Some models return the entire response as a single continuous string,
    /// producing text like: `"...strategies.**Personalization**: ..."`.
    /// This detects those patterns and inserts `\n\n` paragraph breaks.
    private static func separateInlineSections(in markdown: String) -> String {
        guard markdown.contains("**") else { return markdown }

        // Match punctuation followed by optional horizontal whitespace then a
        // bold marker opening with a capital letter — but only when there is
        // no newline between them.
        // The negative lookbehind (?<!\d) prevents matching list markers like "1."
        let pattern = #"(?<!\d)([.!?:])[^\S\n]*(\*\*[A-Z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return markdown
        }

        let mutable = NSMutableString(string: markdown)
        let range = NSRange(location: 0, length: mutable.length)

        let matches = regex.matches(in: markdown, range: range)
        for match in matches.reversed() {
            let punctuationRange = match.range(at: 1)
            let boldRange = match.range(at: 2)
            guard punctuationRange.location != NSNotFound,
                  boldRange.location != NSNotFound else { continue }

            let insertionPoint = punctuationRange.location + punctuationRange.length
            let replacementLength = boldRange.location - insertionPoint
            mutable.replaceCharacters(
                in: NSRange(location: insertionPoint, length: replacementLength),
                with: "\n\n"
            )
        }

        return mutable as String
    }
}

// MARK: - AST → AttributedString Visitor

/// Walks a `swift-markdown` AST and builds a styled `AttributedString`.
struct AttributedStringMarkupVisitor: MarkupVisitor {
    typealias Result = AttributedString

    // Tracks nesting for list indentation.
    private var listDepth = 0
    // Counter for ordered list items.
    private var orderedListCounter = 0
    // Whether we're inside a block that already added trailing spacing.
    private var isFirstBlockChild = true

    // MARK: - Default

    mutating func defaultVisit(_ markup: Markup) -> AttributedString {
        // Fallback: concatenate children
        var result = AttributedString()
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    // MARK: - Document

    mutating func visitDocument(_ document: Document) -> AttributedString {
        var result = AttributedString()
        let children = Array(document.children)
        for (index, child) in children.enumerated() {
            if index > 0 {
                result += AttributedString("\n\n")
            }
            result += visit(child)
        }
        return result
    }

    // MARK: - Paragraph

    mutating func visitParagraph(_ paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()
        for child in paragraph.children {
            result += visit(child)
        }
        return result
    }

    // MARK: - Heading

    mutating func visitHeading(_ heading: Heading) -> AttributedString {
        var content = AttributedString()
        for child in heading.children {
            content += visit(child)
        }

        let range = content.startIndex..<content.endIndex
        switch heading.level {
        case 1:
            content[range].font = .title.bold()
        case 2:
            content[range].font = .title2.bold()
        case 3:
            content[range].font = .title3.bold()
        default:
            content[range].font = .headline
        }

        return content
    }

    // MARK: - Code Block

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> AttributedString {
        let code = codeBlock.code.hasSuffix("\n")
            ? String(codeBlock.code.dropLast())
            : codeBlock.code
        var result = AttributedString(code)
        let range = result.startIndex..<result.endIndex
        result[range].font = .system(.body, design: .monospaced)
        result[range].foregroundColor = .secondary
        return result
    }

    // MARK: - Block Quote

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> AttributedString {
        var content = AttributedString()
        let children = Array(blockQuote.children)
        for (index, child) in children.enumerated() {
            if index > 0 {
                content += AttributedString("\n")
            }
            content += visit(child)
        }

        // Prefix each line-equivalent with a bar indicator
        var indicator = AttributedString("▏ ")
        indicator[indicator.startIndex..<indicator.endIndex].foregroundColor = .secondary
        return indicator + content
    }

    // MARK: - Unordered List

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> AttributedString {
        listDepth += 1
        defer { listDepth -= 1 }

        var result = AttributedString()
        let items = Array(unorderedList.children)
        for (index, item) in items.enumerated() {
            if index > 0 {
                result += AttributedString("\n")
            }
            let indent = String(repeating: "  ", count: listDepth - 1)
            result += AttributedString("\(indent)•  ")
            result += visit(item)
        }
        return result
    }

    // MARK: - Ordered List

    mutating func visitOrderedList(_ orderedList: OrderedList) -> AttributedString {
        listDepth += 1
        defer { listDepth -= 1 }

        var result = AttributedString()
        let items = Array(orderedList.children)
        for (index, item) in items.enumerated() {
            if index > 0 {
                result += AttributedString("\n")
            }
            let indent = String(repeating: "  ", count: listDepth - 1)
            let number = Int(orderedList.startIndex) + index
            result += AttributedString("\(indent)\(number).  ")
            result += visit(item)
        }
        return result
    }

    // MARK: - List Item

    mutating func visitListItem(_ listItem: ListItem) -> AttributedString {
        var result = AttributedString()
        let children = Array(listItem.children)
        for (index, child) in children.enumerated() {
            if index > 0 {
                result += AttributedString("\n")
            }
            result += visit(child)
        }
        return result
    }

    // MARK: - Thematic Break

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> AttributedString {
        var result = AttributedString("———")
        result[result.startIndex..<result.endIndex].foregroundColor = .secondary
        return result
    }

    // MARK: - Inline Elements

    mutating func visitText(_ text: Markdown.Text) -> AttributedString {
        return AttributedString(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> AttributedString {
        var content = AttributedString()
        for child in strong.children {
            content += visit(child)
        }
        let range = content.startIndex..<content.endIndex
        content[range].inlinePresentationIntent = .stronglyEmphasized
        return content
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> AttributedString {
        var content = AttributedString()
        for child in emphasis.children {
            content += visit(child)
        }
        let range = content.startIndex..<content.endIndex
        content[range].inlinePresentationIntent = .emphasized
        return content
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> AttributedString {
        var content = AttributedString()
        for child in strikethrough.children {
            content += visit(child)
        }
        let range = content.startIndex..<content.endIndex
        content[range].inlinePresentationIntent = .strikethrough
        return content
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> AttributedString {
        var result = AttributedString(inlineCode.code)
        let range = result.startIndex..<result.endIndex
        result[range].inlinePresentationIntent = .code
        result[range].font = .system(.body, design: .monospaced)
        return result
    }

    mutating func visitLink(_ link: Markdown.Link) -> AttributedString {
        var content = AttributedString()
        for child in link.children {
            content += visit(child)
        }
        if let destination = link.destination, let url = URL(string: destination) {
            let range = content.startIndex..<content.endIndex
            content[range].link = url
        }
        return content
    }

    mutating func visitImage(_ image: Markdown.Image) -> AttributedString {
        // Images can't be rendered in AttributedString easily;
        // show the alt text instead.
        let alt = image.plainText
        if alt.isEmpty {
            return AttributedString("[image]")
        }
        return AttributedString("[\(alt)]")
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> AttributedString {
        return AttributedString("\n")
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> AttributedString {
        // Treat soft breaks as newlines to preserve the line structure from
        // LLM responses, rather than collapsing them into spaces.
        return AttributedString("\n")
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> AttributedString {
        return AttributedString(inlineHTML.rawHTML)
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> AttributedString {
        return AttributedString(html.rawHTML)
    }

    // MARK: - Table (structured)

    /// Build a `MarkdownTable` from a parsed `Markdown.Table` node,
    /// extracting header cells, body rows, and column alignments.
    mutating func buildTable(_ table: Markdown.Table) -> MarkdownTable {
        // Map column alignments from swift-markdown to SwiftUI
        let alignments: [HorizontalAlignment] = table.columnAlignments.map { alignment in
            switch alignment {
            case .center: return .center
            case .right: return .trailing
            case .left, .none: return .leading
            }
        }

        // Render header cells
        let headerCells = Array(table.head.children)
        var headers: [AttributedString] = []
        for cell in headerCells {
            var content = visitTableCell(cell as! Markdown.Table.Cell)
            if !content.characters.isEmpty {
                let range = content.startIndex..<content.endIndex
                content[range].inlinePresentationIntent = .stronglyEmphasized
            }
            headers.append(content)
        }

        // Render body rows
        var rows: [[AttributedString]] = []
        for row in table.body.children {
            let cells = Array(row.children)
            var rowData: [AttributedString] = []
            for cell in cells {
                let content = visitTableCell(cell as! Markdown.Table.Cell)
                rowData.append(content)
            }
            rows.append(rowData)
        }

        // Ensure alignments array covers all columns
        let columnCount = max(headers.count, rows.first?.count ?? 0)
        var paddedAlignments = alignments
        while paddedAlignments.count < columnCount {
            paddedAlignments.append(.leading)
        }

        return MarkdownTable(
            headers: headers,
            alignments: paddedAlignments,
            rows: rows
        )
    }

    // MARK: - Table (flat fallback)

    mutating func visitTable(_ table: Markdown.Table) -> AttributedString {
        var result = AttributedString()

        // Render header
        result += visitTableHead(table.head)

        // Render body rows
        result += visitTableBody(table.body)

        return result
    }

    mutating func visitTableHead(_ tableHead: Markdown.Table.Head) -> AttributedString {
        var row = AttributedString()
        let cells = Array(tableHead.children)
        for (index, cell) in cells.enumerated() {
            if index > 0 {
                row += AttributedString("  |  ")
            }
            row += visit(cell)
        }
        let range = row.startIndex..<row.endIndex
        row[range].inlinePresentationIntent = .stronglyEmphasized
        return row
    }

    mutating func visitTableBody(_ tableBody: Markdown.Table.Body) -> AttributedString {
        var result = AttributedString()
        for row in tableBody.children {
            result += AttributedString("\n")
            result += visit(row)
        }
        return result
    }

    mutating func visitTableRow(_ tableRow: Markdown.Table.Row) -> AttributedString {
        var row = AttributedString()
        let cells = Array(tableRow.children)
        for (index, cell) in cells.enumerated() {
            if index > 0 {
                row += AttributedString("  |  ")
            }
            row += visit(cell)
        }
        return row
    }

    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) -> AttributedString {
        var result = AttributedString()
        for child in tableCell.children {
            result += visit(child)
        }
        return result
    }
}
