import SwiftUI
import AgentRunKit

/// A view that recursively renders a `JSONValue` as a structured key-value tree.
///
/// Sibling key-value pairs within the same object or array are laid out in a
/// two-column `Grid` so that all values share a common leading edge.
/// Nested objects and arrays are rendered as collapsible `DisclosureGroup`s.
struct StructuredContentView: View {
    let value: JSONValue
    let label: String?

    init(_ value: JSONValue, label: String? = nil) {
        self.value = value
        self.label = label
    }

    var body: some View {
        switch value {
        case .object(let dict):
            objectView(dict)
        case .array(let items):
            arrayView(items)
        default:
            primitiveRow(value, label: label)
        }
    }

    // MARK: - Object

    @ViewBuilder
    private func objectView(_ dict: [String: JSONValue]) -> some View {
        if let label = label {
            DisclosureGroup {
                objectEntries(dict)
            } label: {
                Text(label)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        } else {
            objectEntries(dict)
        }
    }

    private func objectEntries(_ dict: [String: JSONValue]) -> some View {
        Grid(alignment: .leading, verticalSpacing: 2) {
            ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                if let child = dict[key] {
                    entryRow(child, label: key)
                }
            }
        }
    }

    // MARK: - Array

    @ViewBuilder
    private func arrayView(_ items: [JSONValue]) -> some View {
        if let label = label {
            DisclosureGroup {
                arrayEntries(items)
            } label: {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("(\(items.count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            arrayEntries(items)
        }
    }

    private func arrayEntries(_ items: [JSONValue]) -> some View {
        Grid(alignment: .leading, verticalSpacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                entryRow(item, label: "[\(index)]")
            }
        }
    }

    // MARK: - Entry Row (Grid-aware)

    @ViewBuilder
    private func entryRow(_ val: JSONValue, label: String) -> some View {
        switch val {
        case .object, .array:
            GridRow {
                StructuredContentView(val, label: label)
                    .gridCellColumns(3)
            }
        default:
            GridRow(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .gridColumnAlignment(.trailing)

                primitiveText(val)
                    .textSelection(.enabled)
                    .gridColumnAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Standalone Primitive Row (outside a Grid)

    private func primitiveRow(_ val: JSONValue, label: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let label = label {
                Text(label)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            primitiveText(val)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    // MARK: - Primitive Value Text

    @ViewBuilder
    private func primitiveText(_ val: JSONValue) -> some View {
        switch val {
        case .string(let s):
            Text(s)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        case .int(let i):
            Text("\(i)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
        case .double(let d):
            Text(formatDouble(d))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
        case .bool(let b):
            Text(b ? "true" : "false")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.orange)
        case .null:
            Text("null")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .italic()
        default:
            Text(val.prettyPrinted())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func formatDouble(_ d: Double) -> String {
        if d == d.rounded() && abs(d) < 1e15 {
            return String(format: "%.1f", d)
        }
        return "\(d)"
    }
}

// MARK: - Previews

#Preview("Structured Content - Object") {
    ScrollView {
        StructuredContentView(
            .object([
                "temperature": .double(72.0),
                "unit": .string("fahrenheit"),
                "conditions": .string("sunny"),
                "humidity": .int(45),
                "is_daytime": .bool(true),
                "alerts": .null,
                "forecast": .array([
                    .object([
                        "day": .string("Monday"),
                        "high": .int(75),
                        "low": .int(58),
                        "conditions": .string("partly cloudy")
                    ]),
                    .object([
                        "day": .string("Tuesday"),
                        "high": .int(68),
                        "low": .int(55),
                        "conditions": .string("rain")
                    ])
                ])
            ])
        )
        .padding()
    }
    .frame(width: 450, height: 400)
}
