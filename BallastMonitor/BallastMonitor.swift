import DeviceActivity
import Foundation

/// Wakes when a watched app has been used for the threshold.
///
/// It records, it does not alert. Apple delivers these events minutes after the fact,
/// so an alarm here fires once you are already back at work — "you are in Instagram
/// now" when you are not. A reminder that is wrong about *now* teaches you to ignore
/// the ones that are right. The count, though, is about the past and stays true
/// however late it lands, so that is what this keeps.
///
/// The extension runs under a ~6 MB ceiling; a timestamp and a tally is all of it.
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
        // "ballast.<appIndex>.<step>" for a chosen app; anything else is a category,
        // which fires as a single event with no token behind it. Dropping those meant
        // a category selection was detected and then silently thrown away.
        let parts = event.rawValue.split(separator: ".")
        let index = if parts.count == 3, let i = Int(parts[1]) { i } else { Interruption.category }
        SharedState.recordInterruption(appIndex: index, at: now)

    }
}
