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
        content.body = S.t("notif.remaining", S.minutes(SharedState.minutesLeft), task)
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // The interval is deliberate: the question arrives once the impulse has had
        // time to become invisible again.
        let delay = TimeInterval(SharedState.intervalMin * 60)
        let request = UNNotificationRequest(
            identifier: SharedState.notificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))

        UNUserNotificationCenter.current().add(request)
    }
}
