import SwiftUI

/// A model selection picker that lists models from the provider's API
/// (or hardcoded fallbacks) with a "Custom…" option for arbitrary model IDs.
///
/// Used in both `ProviderDetailSheet` (for `Provider.defaultModel`) and
/// `ChatInspectorView` (for `ChatSession.modelIdentifier`).
struct ModelPicker: View {
    /// The currently selected model identifier.
    @Binding var selection: String

    /// The provider whose models should be listed.
    let provider: Provider

    /// Optional placeholder shown when the selection is empty (e.g. "Default (gpt-4o)").
    /// When set, an additional "Default" option is shown at the top of the picker.
    let placeholder: String?

    @Environment(ModelListService.self) private var modelListService

    /// Sentinel value representing the "Custom…" picker option.
    private static let customTag = "__custom__"

    /// Whether the user has selected "Custom…" and the text field is visible.
    @State private var isCustom: Bool = false

    /// The text in the custom model text field.
    @State private var customText: String = ""

    init(selection: Binding<String>, provider: Provider, placeholder: String? = nil) {
        self._selection = selection
        self.provider = provider
        self.placeholder = placeholder
    }

    var body: some View {
        let models = modelListService.models(for: provider)

        if !models.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                pickerView
                if isCustom {
                    customTextField
                }
            }
            .task {
                await modelListService.fetchModels(for: provider)
                syncCustomState()
            }
            .onChange(of: provider.id) {
                Task { await modelListService.fetchModels(for: provider) }
                syncCustomState()
            }
        }
    }

    // MARK: - Picker

    private var pickerView: some View {
        let models = modelListService.models(for: provider)

        return Picker("Model", selection: pickerBinding) {
            if let placeholder {
                Text(placeholder).tag("")
                Divider()
            }

            ForEach(models, id: \.self) { model in
                Text(model)
                    .tag(model)
            }

            Divider()

            Text("Custom\u{2026}")
                .tag(Self.customTag)
        }
    }

    // MARK: - Custom Text Field

    private var customTextField: some View {
        TextField("Model identifier", text: $customText)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .onSubmit {
                if !customText.isEmpty {
                    selection = customText
                }
            }
            .onChange(of: customText) {
                if !customText.isEmpty {
                    selection = customText
                }
            }
    }

    // MARK: - Bindings

    /// A binding that maps the picker's selected tag to/from the external `selection`.
    ///
    /// - Known models map directly to their string tag.
    /// - The "Custom…" tag activates the text field.
    /// - Selecting a known model after "Custom…" hides the text field.
    private var pickerBinding: Binding<String> {
        Binding(
            get: {
                if isCustom { return Self.customTag }
                let models = modelListService.models(for: provider)
                // If the current selection matches a known model, return it
                if models.contains(selection) || selection.isEmpty {
                    return selection
                }
                // Current value isn't in the list — treat as custom
                return Self.customTag
            },
            set: { newValue in
                if newValue == Self.customTag {
                    isCustom = true
                    customText = selection.isEmpty ? "" : selection
                } else {
                    isCustom = false
                    customText = ""
                    selection = newValue
                }
            }
        )
    }

    // MARK: - Helpers

    /// Syncs the `isCustom` state based on whether the current selection
    /// is in the model list.
    private func syncCustomState() {
        let models = modelListService.models(for: provider)
        if !selection.isEmpty && !models.contains(selection) {
            isCustom = true
            customText = selection
        }
    }
}
