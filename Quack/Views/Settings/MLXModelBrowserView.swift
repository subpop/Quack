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

/// A searchable model browser that queries the HuggingFace API for
/// MLX-compatible text-generation models from the `mlx-community` organization.
///
/// Presented as a sheet from the MLX provider detail view. When the user
/// selects a model, its HuggingFace ID is passed back via the `onSelect` callback.
struct MLXModelBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Called when the user selects a model. Receives the full HuggingFace model ID.
    let onSelect: (String) -> Void

    @State private var models: [HuggingFaceAPI.Model] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var error: String?

    /// Debounce timer for search input.
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            modelList
            Divider()
            footer
        }
        .frame(width: 520, height: 480)
        .task {
            await fetchModels()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 28))
                .foregroundStyle(.teal)
            Text("MLX Model Browser")
                .font(.headline)
            Text("Browse models from the mlx-community on HuggingFace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search models\u{2026}", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) {
                    // Debounce search to avoid excessive API calls
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        await fetchModels(query: searchText)
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Task { await fetchModels() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Model List

    private var modelList: some View {
        Group {
            if isLoading && models.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading models\u{2026}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await fetchModels(query: searchText) }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if models.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No models found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(models) { model in
                            ModelRow(model: model) {
                                onSelect(model.id)
                                dismiss()
                            }
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                openURL(URL(string: "https://huggingface.co/mlx-community")!)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                    Text("Browse on HuggingFace")
                }
            }
            .buttonStyle(.link)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Data

    private func fetchModels(query: String? = nil) async {
        isLoading = true
        error = nil

        do {
            models = try await HuggingFaceAPI.searchMLXModels(
                query: query,
                limit: 50
            )
            isLoading = false
        } catch is CancellationError {
            // Search was cancelled by a newer query -- don't update state
        } catch {
            self.error = "Failed to load models: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: HuggingFaceAPI.Model
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.shortName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let quant = model.quantization {
                            Text(quant)
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.secondary.opacity(0.12))
                                )
                        }

                        Label(model.formattedDownloads, systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("\(model.likes)", systemImage: "heart")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
