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
    /// The friction itself.
    public static let hold: TimeInterval = 4
}
