import DeviceActivity
import Foundation
import UserNotifications

/// Wakes when a watched app has been used for the threshold, records the interruption,
/// and sounds an alarm.
///
/// The alarm was removed once, on the grounds that the event arrived far too late to be
/// about "now". Most of that lateness turned out to be a bug of ours: thresholds counted
/// usage from midnight, so they were frequently crossed before the session had even
/// begun. With each session opening its own window the event lands close to the minute
/// of use — and being heard is the entire point of it.
///
/// The extension runs under a ~6 MB ceiling; a tally and one notification is all of it.
class BallastMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard SharedState.sessionActive else { return }

        let now = Date().timeIntervalSince1970
        SharedState.lastSlip = now

        // "ballast.<appIndex>.<step>" for a chosen app; anything else is a category,
        // which fires as a single event with no token behind it. Dropping those meant
        // a category selection was detected and then silently thrown away.
        let parts = event.rawValue.split(separator: ".")
        let index = if parts.count == 3, let i = Int(parts[1]) { i } else { Interruption.category }
        SharedState.recordInterruption(appIndex: index, at: now)

        let task = SharedState.task
        guard !task.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = S.t("ask.title")
        content.body = S.t("notif.slipNow", task)
        // The bundled tone rather than the default tick, which a pocket swallows.
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.interruptionLevel = .timeSensitive

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "\(SharedState.notificationID).\(Int(now))",
                content: content,
                trigger: nil))
    }
}
