import ActivityKit
import Foundation

/// Owns the Lock Screen activity for a session.
///
/// The app is suspended for most of a session, so this can only push state while the
/// app happens to be running. The countdown on the Lock Screen is a self-running
/// timer for exactly that reason — it keeps ticking with the app asleep.
@MainActor
final class LiveActivityController {
    private var activity: Activity<BallastAttributes>?

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(task: String, armedAt: Date?) {
        guard enabled, activity == nil else { return }
        do {
            activity = try Activity.request(
                attributes: BallastAttributes(task: task),
                content: .init(
                    state: .init(armedAt: armedAt, asking: false), staleDate: nil))
        } catch {
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
