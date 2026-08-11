import Foundation

/// The only channel between the app and the DeviceActivity monitor, which runs as a
/// separate process with a tight memory ceiling. Keep it to plain values.
enum SharedState {
    static let suiteName = "group.app.ballast"
    static let notificationID = "ballast.slip.question"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    /// The user's own words. The monitor needs it to name the task in the question,
    /// which is the one thing the spec says never to ship without.
    static var task: String {
        get { defaults?.string(forKey: "task") ?? "" }
        set { defaults?.set(newValue, forKey: "task") }
    }

    static var intervalMin: Int {
        get { defaults?.object(forKey: "intervalMin") as? Int ?? Constants.defaultIntervalMin }
        set { defaults?.set(newValue, forKey: "intervalMin") }
    }

    /// Written by the monitor, read by the app when it next runs.
    static var lastSlip: TimeInterval {
        get { defaults?.double(forKey: "lastSlip") ?? 0 }
        set { defaults?.set(newValue, forKey: "lastSlip") }
    }

    /// Whether a session is running. The monitor stays silent otherwise.
    static var sessionActive: Bool {
        get { defaults?.bool(forKey: "sessionActive") ?? false }
        set { defaults?.set(newValue, forKey: "sessionActive") }
    }
}
