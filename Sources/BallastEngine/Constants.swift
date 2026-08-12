import Foundation

/// Product, not configuration. Argue with the reason, not the number.
public enum Constants {
    /// Long enough that the question feels earned, short enough to catch a session.
    public static let defaultIntervalMin = 20
    public static let intervalRange = 5...90
    public static let intervalStep = 5

    /// Two questions in a row reads as nagging.
    public static let nudgeCooldown: TimeInterval = 60
    /// One reach = one pick-up, not eight.
    public static let pickupDebounce: TimeInterval = 25
    /// 5-minute steps up to an hour, then quarter hours. A linear slider spent most
    /// of its travel on durations nobody picks.
    public static let durationSteps = [5, 10, 15, 30, 45, 60, 75, 90, 120, 150, 180, 240]

    /// A reminder that lands after the work is over is no reminder at all. Five
    /// minutes of work gets asked at five minutes, not at twenty.
    public static func reminderInterval(intervalMin: Int, durationMin: Int) -> Int {
        max(1, min(intervalMin, durationMin))
    }

    /// The friction itself.
    public static let hold: TimeInterval = 4
}
