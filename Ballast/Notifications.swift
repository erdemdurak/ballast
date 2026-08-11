import Foundation
import UserNotifications

/// The only way to interrupt from a closed app without an entitlement.
///
/// The app is suspended for most of a session, so the questions cannot be posted as
/// they come due — the whole series is scheduled up front and cancelled when the
/// session ends or the anchor moves.
@MainActor
final class Notifications: NSObject {
    /// iOS caps pending local notifications at 64 per app.
    private static let maxPending = 48

    var onOpen: (() -> Void)?

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Ballast: notification authorisation failed — \(error)")
            return false
        }
    }

    /// Schedules a question at every interval from `anchor` for the rest of the day.
    /// `interruptionLevel` stays `.active`: `.timeSensitive` needs an entitlement, and
    /// entitlements are what we cannot sign for yet.
    func schedule(
        task: String, from anchor: Date, every interval: TimeInterval, endsAt: Date?
    ) {
        cancel()
        guard interval > 0 else { return }

        let now = Date()
        var fire = anchor.addingTimeInterval(interval)
        var scheduled = 0
        let center = UNUserNotificationCenter.current()

        while scheduled < Self.maxPending, fire.timeIntervalSince(now) < 12 * 60 * 60 {
            if fire > now {
                // Each reminder states the time left on the work at the moment it
                // will actually arrive, not when it was scheduled.
                let content = UNMutableNotificationContent()
                content.title = S.t("ask.title")
                if let endsAt {
                    let left = Int((endsAt.timeIntervalSince(fire) / 60).rounded())
                    content.body =
                        left > 0
                        ? S.t("notif.remaining", left, task)
                        : S.t("notif.overrun", task)
                } else {
                    content.body = S.t("notif.body", task)
                }
                content.sound = .default
                content.interruptionLevel = .active

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
