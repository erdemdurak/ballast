import Foundation
import UserNotifications

/// The only way to interrupt from a closed app without an entitlement.
///
/// The app is suspended for most of a session, so the questions cannot be posted as
/// they come due — the whole series is scheduled up front and cancelled when the
/// session ends or the anchor moves.
@Observable
@MainActor
final class Notifications: NSObject {
    /// iOS caps pending local notifications at 64 per app.
    private static let maxPending = 48

    var onOpen: (() -> Void)?

    /// Shown in the session screen. "Nothing buzzed" has too many possible causes to
    /// keep guessing at.
    private(set) var status = "—"


    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if !granted { status = "not allowed" }
            return granted
        } catch {
            print("Ballast: notification authorisation failed — \(error)")
            return false
        }
    }

    /// Schedules a question at every interval from `anchor` for the rest of the day.
    /// `.timeSensitive` so a Focus mode does not silence the reminder — the whole
    /// point is reaching someone who is trying to concentrate.
    func schedule(
        task: String, from anchor: Date, every interval: TimeInterval, endsAt: Date?
    ) {
        cancel()
        guard interval > 0 else { return }

        let now = Date()
        var fire = anchor.addingTimeInterval(interval)
        var scheduled = 0
        let center = UNUserNotificationCenter.current()

        // Stop at the deadline. Running to a fixed 12-hour window meant a 15-minute
        // task kept asking for the rest of the day, and the only way to stop it was
        // to open the app and end the session.
        let horizon = endsAt ?? now.addingTimeInterval(12 * 60 * 60)

        while scheduled < Self.maxPending, fire < horizon {
            if fire > now {
                // Each reminder states the time left on the work at the moment it
                // will actually arrive, not when it was scheduled.
                let content = UNMutableNotificationContent()
                content.title = S.t("ask.title")
                if let endsAt {
                    let left = Int((endsAt.timeIntervalSince(fire) / 60).rounded())
                    content.body =
                        left > 0
                        ? S.t("notif.remaining", S.minutes(left), task)
                        : S.t("notif.overrun", task)
                } else {
                    content.body = S.t("notif.body", task)
                }
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let request = UNNotificationRequest(
                    identifier: "ballast.question.\(scheduled)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: fire.timeIntervalSince(now), repeats: false))
                center.add(request) { error in
                    if let error { print("Ballast: could not schedule — \(error)") }
                }
                scheduled += 1
            }
            fire = fire.addingTimeInterval(interval)
        }

        refreshStatus()
    }

    private func refreshStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                status = "not allowed"
                return
            }
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let next = pending.compactMap {
                ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval
            }.min()
            status =
                next.map { "\(pending.count) queued, next in \(Int($0 / 60))m" }
                ?? "\(pending.count) queued"
        }
    }

    func cancel() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

extension Notifications: UNUserNotificationCenterDelegate {
    /// Show it even if Ballast happens to be open — the question is the point.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { self.onOpen?() }
    }
}
