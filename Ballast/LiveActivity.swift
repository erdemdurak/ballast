import ActivityKit
import Foundation

/// Owns the Lock Screen activity for a session.
///
/// The app is suspended for most of a session, so this can only push state while the
/// app happens to be running. The countdown on the Lock Screen is a self-running
/// timer for exactly that reason — it keeps ticking with the app asleep.
@Observable
@MainActor
final class LiveActivityController {
    private var activity: Activity<BallastAttributes>?

    /// Surfaced in the session screen. Silent failure here looks identical to "iOS
    /// cannot do this", and the two need telling apart.
    private(set) var status: String = "—"

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(task: String, armedAt: Date?) {
        guard activity == nil else { return }
        guard enabled else {
            status = "off in Settings"
            return
        }
        do {
            activity = try Activity.request(
                attributes: BallastAttributes(task: task),
                content: .init(
                    state: .init(armedAt: armedAt, asking: false), staleDate: nil))
            status = "on"
        } catch {
            status = "failed: \(error)"
            // Not swallowed: without this the whole point of the session is invisible.
            print("Ballast: could not start the Live Activity — \(error)")
        }
    }

    func update(armedAt: Date?, asking: Bool) {
        guard let activity else { return }
        Task {
            await activity.update(
                .init(state: .init(armedAt: armedAt, asking: asking), staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
