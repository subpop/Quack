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

/// Settings tab for managing local MLX models.
///
/// Shows the currently loaded model, downloaded (inactive) models with
/// load/delete actions, and a browser for discovering new models from
/// the mlx-community on HuggingFace.
struct LocalModelsSettingsView: View {
    @Environment(\.mlxModelServiceBox) private var mlxModelService
    @Environment(\.openURL) private var openURL

    @State private var showingModelBrowser = false
    @State private var modelToDelete: DownloadedMLXModel?

    var body: some View {
        Form {
            // MARK: - Active Model
            Section("Active Model") {
                activeModelView
            }

            // MARK: - Downloaded Models
            Section("Downloaded Models") {
                downloadedModelsList
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    openURL(URL(string: "https://huggingface.co/mlx-community")!)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                        Text("HuggingFace")
                    }
                }

                Spacer()

                Button("Browse Models\u{2026}") {
                    showingModelBrowser = true
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .task {
            mlxModelService.scanDownloadedModels()
        }
        .onChange(of: isReady) {
            // Re-scan when a model finishes loading (it may have been newly downloaded)
            // or when a model is unloaded.
            mlxModelService.scanDownloadedModels()
        }
        .sheet(isPresented: $showingModelBrowser) {
            MLXModelBrowserView { modelID in
                Task {
                    try? await mlxModelService.loadModel(id: modelID)
                    mlxModelService.scanDownloadedModels()
                }
            }
        }
        .alert(
            "Delete Model",
            isPresented: Binding(
                get: { modelToDelete != nil },
                set: { if !$0 { modelToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { modelToDelete = nil }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    mlxModelService.deleteDownloadedModel(model)
                    modelToDelete = nil
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Delete \"\(model.shortName)\" (\(model.formattedSize))? The model will need to be re-downloaded to use it again.")
            }
        }
    }

    // MARK: - Active Model

    @ViewBuilder
    private var activeModelView: some View {
        switch mlxModelService.loadState {
        case .idle:
            HStack(spacing: 12) {
                modelIcon(color: .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Model Loaded")
                        .fontWeight(.medium)
                    Text("Load a downloaded model or browse for new ones.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

        case .downloading(let progress):
            HStack(spacing: 12) {
                modelIcon(color: .teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mlxModelService.loadedModelID ?? "Downloading")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    ProgressView(value: progress)
                        .frame(maxWidth: 200)
                    Text("Downloading\u{2026} \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .destructive) {
                    mlxModelService.unloadModel()
                }
                .controlSize(.small)
            }
            .padding(.vertical, 4)

        case .loading:
            HStack(spacing: 12) {
                modelIcon(color: .teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mlxModelService.loadedModelID ?? "Loading")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("Loading model into GPU memory\u{2026}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
            .padding(.vertical, 4)

        case .ready:
            HStack(spacing: 12) {
                modelIcon(color: .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mlxModelService.loadedModelID ?? "Model")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("Loaded and ready for inference")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Unload") {
                    mlxModelService.unloadModel()
                }
                .controlSize(.small)
            }
            .padding(.vertical, 4)

        case .failed(let error):
            HStack(spacing: 12) {
                modelIcon(color: .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mlxModelService.loadedModelID ?? "Failed")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                if let modelID = mlxModelService.loadedModelID {
                    Button("Retry") {
                        Task {
                            try? await mlxModelService.loadModel(id: modelID)
                        }
                    }
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Downloaded Models List

    @ViewBuilder
    private var downloadedModelsList: some View {
        let downloaded = mlxModelService.downloadedModels
        let activeModelID = mlxModelService.loadedModelID

        if downloaded.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No downloaded models")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Use \"Browse Models\" to discover and download models from HuggingFace.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            ForEach(downloaded) { model in
                let isActive = model.id == activeModelID && isReady
                let isLoading = model.id == mlxModelService.loadedModelID && !isReady

                HStack(spacing: 12) {
                    modelIcon(color: isActive ? .green : .teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.shortName)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(model.formattedSize)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if isActive {
                                Text("Active")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(.green.opacity(0.12))
                                    )
                            }
                        }
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if !isActive {
                        Button {
                            Task {
                                try? await mlxModelService.loadModel(id: model.id)
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Load model into memory")
                    }

                    Button(role: .destructive) {
                        modelToDelete = model
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Delete model from disk")
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .contextMenu {
                    if !isActive {
                        Button("Load Model") {
                            Task {
                                try? await mlxModelService.loadModel(id: model.id)
                            }
                        }
                        Divider()
                    }

                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: model.url.path)
                    }

                    Divider()

                    Button("Delete\u{2026}", role: .destructive) {
                        modelToDelete = model
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func modelIcon(color: Color) -> some View {
        Image(systemName: "cpu")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.gradient)
            )
    }

    /// Equatable check for load state (only comparing `.ready`).
    private var isReady: Bool {
        if case .ready = mlxModelService.loadState { return true }
        return false
    }
}

// MARK: - Previews

#Preview("No Model") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    LocalModelsSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}
