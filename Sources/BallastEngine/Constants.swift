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
    /// A pick-up requires prior stillness, or walking triggers it.
    public static let restBeforePickup: TimeInterval = 12
    /// The friction itself.
    public static let hold: TimeInterval = 4
    /// Below the noise floor of a phone on a table.
    public static let stillnessDelta = 0.3

    /// Δ-magnitude thresholds, very low → very high. Read by the platform motion
    /// detector, not by the engine.
    public static let sensitivityLadder = [4.5, 3.2, 2.2, 1.4, 0.9]

    /// 1-based, per `prefs.sensitivity`. Normal = 2.2.
    public static let defaultSensitivity = 3
}
