import Foundation
import SwiftUI

enum MarkdownRenderer {
    /// Render markdown with full block-level parsing (paragraphs, lists, code blocks).
    ///
    /// Pre-processes the input to convert single newlines into hard line breaks
    /// (two trailing spaces + newline) outside of fenced code blocks. This prevents
    /// CommonMark's default behavior of collapsing single `\n` into spaces, which
    /// strips intended line breaks from LLM responses.
    static func renderFull(_ markdown: String) -> AttributedString {
        let processed = preserveLineBreaks(in: markdown)
        do {
            let result = try AttributedString(
                markdown: processed,
                options: .init(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
            return result
        } catch {
            return AttributedString(markdown)
        }
    }

    // MARK: - Private

    /// Convert single newlines into CommonMark hard line breaks (two trailing spaces)
    /// while leaving fenced code blocks, blank lines, and block-level structures untouched.
    private static func preserveLineBreaks(in markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        var result: [String] = []
        var inCodeFence = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            // Track fenced code block boundaries (``` or ~~~)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inCodeFence.toggle()
                result.append(String(line))
                continue
            }

            // Inside code fences: pass through unchanged
            if inCodeFence {
                result.append(String(line))
                continue
            }

            // Don't modify the last line (nothing follows it)
            let isLastLine = index == lines.count - 1

            // Don't add hard breaks to empty lines (they're already paragraph breaks)
            let isEmpty = trimmed.isEmpty

            // Don't add hard breaks to lines that are block-level constructs
            let isBlockElement = trimmed.hasPrefix("#")       // headings
                || trimmed.hasPrefix(">")                     // blockquotes
                || trimmed.hasPrefix("- ")                    // unordered lists
                || trimmed.hasPrefix("* ")                    // unordered lists
                || trimmed.hasPrefix("+ ")                    // unordered lists
                || trimmed.first?.isNumber == true && trimmed.drop(while: \.isNumber).hasPrefix(". ")  // ordered lists
                || trimmed.hasPrefix("---")                   // horizontal rules
                || trimmed.hasPrefix("***")
                || trimmed.hasPrefix("___")

            // Don't modify if line already ends with a hard break (two+ trailing spaces)
            let alreadyHardBreak = line.hasSuffix("  ")

            // Check if the next line is empty (i.e., this line is already followed by a paragraph break)
            let nextLineEmpty = index + 1 < lines.count && lines[index + 1].allSatisfy({ $0 == " " || $0 == "\t" || $0 == "\n" })

            if !isLastLine && !isEmpty && !isBlockElement && !alreadyHardBreak && !nextLineEmpty {
                // Append two spaces to create a CommonMark hard line break
                result.append(String(line) + "  ")
            } else {
                result.append(String(line))
            }
        }

        return result.joined(separator: "\n")
    }
}
