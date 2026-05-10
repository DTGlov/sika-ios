import SwiftUI
import UIKit
import UserNotifications

/// Push notifications toggle. Drives iOS-level permission state only.
///
/// TODO: Wire APNs device token to push_subscriptions table when push backend
/// is built. For S1 this only toggles the iOS permission flow — the actual
/// per-device subscription registration is out of scope.
struct NotificationSettings: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var showOpenSettingsAlert = false

    private let goldColor = Color(hex: 0xD4A017)

    private var isEnabled: Bool {
        status == .authorized
    }

    var body: some View {
        SettingsCard(
            title: "Notifications",
            subtitle: "Income reminders and your daily insight, sent to this device."
        ) {
            HStack {
                Text(statusLabel)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in handleToggle(newValue) }
                ))
                .labelsHidden()
                .tint(goldColor)
            }
        }
        .task { await refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshStatus() }
        }
        .alert(
            "Notifications disabled in iOS Settings",
            isPresented: $showOpenSettingsAlert
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Tap Open Settings to enable notifications for Sika.")
        }
    }

    private var statusLabel: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Blocked in iOS Settings"
        case .notDetermined: return "Off"
        @unknown default: return "Off"
        }
    }

    private func handleToggle(_ newValue: Bool) {
        switch (newValue, status) {
        case (true, .notDetermined):
            Task { await requestPermission() }
        case (true, .denied):
            showOpenSettingsAlert = true
        case (false, _):
            // No iOS-level affordance to revoke from the app — user goes to iOS Settings.
            // Nothing to persist here for S1; APNs registration is deferred.
            break
        default:
            break
        }
    }

    @MainActor
    private func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await refreshStatus()
        } catch {
            #if DEBUG
            print("⚠️ Notification permission request failed: \(error)")
            #endif
        }
    }

    @MainActor
    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.status = settings.authorizationStatus
    }
}
