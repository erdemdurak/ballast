import DeviceActivity
import Foundation
import UserNotifications

/// Wakes when a watched app has been used for the threshold. This is the one signal
/// iOS gives a closed app, and it is the whole reason the Screen Time half exists:
/// the question fires because you slipped, not because a timer expired.
///
/// The extension runs under a ~6 MB ceiling. It records a timestamp and schedules one
/// notification — nothing else belongs here.
class BallastMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard SharedState.sessionActive else { return }

        let now = Date().timeIntervalSince1970
        SharedState.lastSlip = now

        // "ballast.<appIndex>.<step>" — the index attributes the crossing to one app
        // without this process ever learning which app that is.
        let parts = event.rawValue.split(separator: ".")
        if parts.count == 3, let index = Int(parts[1]) {
            SharedState.recordInterruption(appIndex: index, at: now)
        }

        let task = SharedState.task
        guard !task.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = S.t("ask.title")
        content.body = S.t("notif.slipNow", task)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.interruptionLevel = .timeSensitive

        // Now, not later. Delaying this by the reminder interval meant opening a
        // watched app produced silence, and the warning landed twenty minutes after
        // the moment it was about.
        let request = UNNotificationRequest(
            identifier: "\(SharedState.notificationID).\(Int(now))",
            content: content,
            trigger: nil)

        UNUserNotificationCenter.current().add(request)
    }
}
