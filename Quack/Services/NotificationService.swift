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

import AppKit
import UserNotifications

/// Manages Notification Center notifications and dock icon badges for events
/// that require user attention when the app is not frontmost.
///
/// Conforms to `UNUserNotificationCenterDelegate` so the system knows to
/// display banners and play sounds even when the app is running.
@Observable
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private static let toolApprovalIdentifier = "tool-approval"

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Requests notification authorization from the user. Safe to call multiple
    /// times; the system only prompts once.
    func requestAuthorization() {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Posts a Notification Center notification and sets a dock badge when a
    /// tool call is waiting for user approval.
    ///
    /// Only fires when the app is **not** the active application, since the
    /// in-app approval card is already visible to the user in that case.
    func showToolApprovalNotification(toolName: String) {
        guard !NSApp.isActive else { return }

        // Dock badge
        NSApp.dockTile.badgeLabel = "!"

        // Local notification
        let content = UNMutableNotificationContent()
        content.title = "Tool Permission Required"
        content.body = "\(toolName) wants to run. Switch to Quack to allow or deny."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.toolApprovalIdentifier,
            content: content,
            trigger: nil // deliver immediately
        )

        Task {
            let center = UNUserNotificationCenter.current()
            try? await center.add(request)
        }
    }

    /// Removes any pending or delivered tool-approval notifications and clears
    /// the dock badge.
    func clearToolApprovalNotification() {
        NSApp.dockTile.badgeLabel = ""

        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(
            withIdentifiers: [Self.toolApprovalIdentifier]
        )
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.toolApprovalIdentifier]
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Tells the system to display the banner and play the sound even when the
    /// app process is running. Without this method, macOS silently drops local
    /// notifications delivered by the running app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
