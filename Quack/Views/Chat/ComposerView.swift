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
import UniformTypeIdentifiers
import QuackInterface
import QuackKit

struct ComposerView: View {
    @State private var inputText = ""
    @State private var attachments: [Attachment] = []
    @State private var showFilePicker = false
    @FocusState private var isInputFocused: Bool

    @Binding var isDropTargeted: Bool
    @Binding var droppedURLs: [URL]

    var isStreaming: Bool
    var onSend: (String, [Attachment]) -> Void
    var onStop: () -> Void

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .bottom, spacing: 8) {
                attachButton

                VStack(spacing: 0) {
                    attachmentStrip
                    messageField
                }
                .glassEffect(in: .rect(cornerRadius: 20))

                actionButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onPasteCommand(of: [.image, .pdf]) { providers in
            pasteItems(providers)
        }
        .onChange(of: droppedURLs) {
            if !droppedURLs.isEmpty {
                addAttachments(from: droppedURLs)
                droppedURLs = []
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                addAttachments(from: urls)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var attachmentStrip: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(attachments) { attachment in
                        AttachmentThumbnail(attachment: attachment) {
                            withAnimation {
                                attachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
            .scrollIndicators(.hidden)

            Divider()
                .padding(.horizontal, 14)
        }
    }

    private var attachButton: some View {
        Button("Attach file", systemImage: "plus", action: { showFilePicker = true })
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .glassEffect(in: .circle)
            .help("Attach image or PDF")
    }

    private var messageField: some View {
        TextField("Message", text: $inputText, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...12)
            .focused($isInputFocused)
            .font(.body)
            .onSubmit {
                if !NSEvent.modifierFlags.contains(.shift) {
                    send()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isStreaming {
            Button {
                onStop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                    .glassEffect(in: .circle)
            }
            .buttonStyle(.plain)
            .help("Stop generating")
        } else {
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                    .glassEffect(in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help("Send message (Return)")
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    // MARK: - Actions

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachments.isEmpty else { return }

        let sentAttachments = attachments
        inputText = ""
        attachments = []

        onSend(text, sentAttachments)
    }

    private func addAttachments(from urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let attachment = try ImageProcessor.attachment(from: url)
                withAnimation {
                    attachments.append(attachment)
                }
            } catch {
                // Silently skip files that can't be processed.
            }
        }
    }

    private func pasteItems(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in
                        if let attachment = try? ImageProcessor.attachment(from: data, fileName: "Pasted Image") {
                            withAnimation {
                                attachments.append(attachment)
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in
                        let attachment = Attachment(
                            type: .pdf,
                            mimeType: "application/pdf",
                            data: data,
                            fileName: "Pasted Document.pdf"
                        )
                        withAnimation {
                            attachments.append(attachment)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Attachment Thumbnail

private struct AttachmentThumbnail: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if attachment.type == .image, let nsImage = NSImage(data: attachment.data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    Label(attachment.fileName ?? "PDF", systemImage: "doc.fill")
                        .font(.caption)
                        .lineLimit(2)
                        .frame(width: 80, height: 80)
                        .background(.quaternary, in: .rect(cornerRadius: 8))
                }
            }

            Button("Remove", systemImage: "xmark.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .imageScale(.large)
                .foregroundStyle(.white, .black.opacity(0.6))
                .offset(x: 6, y: -6)
        }
    }
}
#Preview("Empty") {
    ComposerView(
        isDropTargeted: .constant(false),
        droppedURLs: .constant([]),
        isStreaming: false,
        onSend: { _, _ in },
        onStop: {}
    )
    .frame(width: 500)
}

#Preview("Streaming") {
    ComposerView(
        isDropTargeted: .constant(false),
        droppedURLs: .constant([]),
        isStreaming: true,
        onSend: { _, _ in },
        onStop: {}
    )
    .frame(width: 500)
}

