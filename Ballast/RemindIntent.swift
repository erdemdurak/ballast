import AppIntents
import Foundation
import UserNotifications

/// The closest thing iOS allows to "warn me before I use that app".
///
/// A Shortcuts personal automation can run this the moment a chosen app opens —
/// no Screen Time entitlement, and nothing is blocked. The app named the task; this
/// puts it back in front of you at the exact moment you were about to drift.
struct RemindIntent: AppIntent {
    static var title: LocalizedStringResource = "Show my task"
    static var description = IntentDescription(
        "Shows the task you named and how long is left on it. Runs without opening Ballast.")

    /// Must stay false: an automation that yanks you into Ballast would be its own
    /// interruption, and the point is a reminder, not a detour.
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let task = SharedState.task

        guard SharedState.sessionActive, !task.isEmpty else {
            return .result(dialog: "No session running.")
        }

        let left = SharedState.minutesLeft
        let body =
            left > 0
            ? S.t("notif.remaining", left, task)
            : S.t("notif.overrun", task)

        let content = UNMutableNotificationContent()
        content.title = S.t("ask.title")
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // No trigger: deliver now, while the app being opened is still on screen.
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "ballast.intent.\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil))

        return .result(dialog: IntentDialog(stringLiteral: body))
    }
}

struct BallastShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RemindIntent(),
            phrases: [
                "What am I doing in \(.applicationName)",
                "Ask \(.applicationName)",
            ],
            shortTitle: "Show my task",
            systemImageName: "viewfinder")
    }
}
