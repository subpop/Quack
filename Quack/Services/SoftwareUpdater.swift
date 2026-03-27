// Copyright (c) 2026 Link Dupont
// SPDX-License-Identifier: MIT

import Combine
import Foundation
import Sparkle

@MainActor
final class SoftwareUpdater: ObservableObject {
    @Published var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    private let updaterController: SPUStandardUpdaterController
    private let updater: SPUUpdater

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = updaterController.updater

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
