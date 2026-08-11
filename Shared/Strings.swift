import Foundation

/// Every user-visible string comes from here. Anything with a number is a format
/// template — never concatenate.
enum S {
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

    static func t(_ key: String, _ n: Int, _ s: String) -> String {
        String(format: t(key), n, s)
    }
}
