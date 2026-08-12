import Foundation

/// Every user-visible string comes from here. Anything with a number is a format
/// template — never concatenate.
enum S {
    /// "45 min", "1 hr 15 min" — in the reader's own language.
    static func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// Minutes as the current locale writes them — "1 minute", "8 minutes",
    /// "1 Minute", "8 dakika". Formatting the number into the sentence by hand is
    /// what produced "1 minutes" in every language at once.
    static func minutes(_ n: Int) -> String {
        Measurement(value: Double(max(0, n)), unit: UnitDuration.minutes)
            .formatted(.measurement(width: .wide, usage: .asProvided))
    }

    static func t(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func t(_ key: String, _ n: Int) -> String {
        String(format: t(key), n)
    }

    static func t(_ key: String, _ a: Int, _ b: Int) -> String {
        String(format: t(key), a, b)
    }

    static func t(_ key: String, _ s: String, _ n: Int) -> String {
        String(format: t(key), s, n)
    }

    static func t(_ key: String, _ s: String) -> String {
        String(format: t(key), s)
    }

    static func t(_ key: String, _ a: String, _ b: String) -> String {
        String(format: t(key), a, b)
    }

    static func t(_ key: String, _ n: Int, _ s: String) -> String {
        String(format: t(key), n, s)
    }
}
