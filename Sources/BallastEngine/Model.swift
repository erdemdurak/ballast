import Foundation

public enum Mode: String, Codable, Sendable {
    case slip
    case any
}

/// Derived from the timestamps in `SessionState`, never stored. Storing it is what let the
/// diagram and the pseudocode drift apart.
public enum Phase: Equatable, Sendable {
    case idle
    case quiet
    case waiting
    case armed
    case asking
}

public struct Config: Equatable, Sendable {
    public var intervalMin: Int
    public var mode: Mode
    /// Reducible to 0 through accessibility settings only.
    public var holdSeconds: TimeInterval

    public init(
        intervalMin: Int = Constants.defaultIntervalMin,
        mode: Mode = .any,
        holdSeconds: TimeInterval = Constants.hold
    ) {
        self.intervalMin = intervalMin
        self.mode = mode
        self.holdSeconds = holdSeconds
    }

    public var interval: TimeInterval { TimeInterval(intervalMin * 60) }
}

public enum Event: Equatable, Sendable {
    case startSession(task: String, config: Config)
    case endSession
    case slip
    case pickup
    /// The user tapped a reminder. The question was already asked; refusing to show
    /// it because an interval or cooldown says so leaves a tap that does nothing.
    case askNow
    case tick
    case dismiss(Dismissal)
    case callChanged(Bool)
}

public enum Dismissal: String, Codable, Sendable {
    case down
    case through
}

public enum RecordKind: String, Codable, Sendable {
    case slip
    case pickup
    case nudge
    case down
    case through
}

public enum Screen: Equatable, Sendable {
    case asking(holdSeconds: TimeInterval)
    case closed
}

public enum Effect: Equatable, Sendable {
    case record(RecordKind, at: TimeInterval)
    case present(Screen)
    case dismissAsking
}

public struct SessionState: Equatable, Sendable {
    public var task: String
    public var config: Config
    public var sessionStart: TimeInterval?
    public var lastSlip: TimeInterval?
    public var lastNudge: TimeInterval?
    public var lastPickup: TimeInterval?
    public var callActive: Bool
    public var isAsking: Bool

    public init(
        task: String = "",
        config: Config = Config(),
        sessionStart: TimeInterval? = nil,
        lastSlip: TimeInterval? = nil,
        lastNudge: TimeInterval? = nil,
        lastPickup: TimeInterval? = nil,
        callActive: Bool = false,
        isAsking: Bool = false
    ) {
        self.task = task
        self.config = config
        self.sessionStart = sessionStart
        self.lastSlip = lastSlip
        self.lastNudge = lastNudge
        self.lastPickup = lastPickup
        self.callActive = callActive
        self.isAsking = isAsking
    }

    /// What the interval is measured from. `nil` means nothing is owed — the engine's
    /// spelling of QUIET.
    public var anchor: TimeInterval? {
        guard let sessionStart else { return nil }
        switch config.mode {
        case .slip:
            return lastSlip
        case .any:
            return max(lastSlip ?? sessionStart, lastNudge ?? sessionStart, sessionStart)
        }
    }

    public func phase(at now: TimeInterval) -> Phase {
        guard sessionStart != nil else { return .idle }
        if isAsking { return .asking }
        guard let anchor else { return .quiet }
        return now - anchor >= config.interval ? .armed : .waiting
    }
}
