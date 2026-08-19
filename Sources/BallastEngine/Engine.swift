import Foundation

/// Seconds left before `Carry on` becomes tappable. The friction is the product, so
/// this lives here and is tested rather than sitting as arithmetic inside a view.
public func holdRemaining(
    holdSeconds: TimeInterval, askedAt: TimeInterval, now: TimeInterval
) -> Int {
    max(0, Int((holdSeconds - (now - askedAt)).rounded(.up)))
}

/// The whole product logic. Pure: no clocks, no I/O, no platform types.
public func reduce(_ state: SessionState, _ event: Event, _ now: TimeInterval) -> (SessionState, [Effect]) {
    var s = state

    switch event {
    case let .startSession(task, config):
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        // There is no session without a task.
        guard !trimmed.isEmpty else { return (state, []) }
        s = SessionState(task: trimmed, config: config, sessionStart: now)
        return (s, [])

    case .endSession:
        guard s.sessionStart != nil else { return (state, []) }
        s.sessionStart = nil
        s.isAsking = false
        return (s, [.present(.closed)])

    case .slip:
        guard s.sessionStart != nil else { return (state, []) }
        s.lastSlip = now
        return (s, [.record(.slip, at: now)])

    case .pickup:
        guard s.sessionStart != nil else { return (state, []) }
        // One reach is one pick-up. A debounced sample is not a separate event, so it
        // is not recorded either.
        if let lastPickup = s.lastPickup, now - lastPickup < Constants.pickupDebounce {
            return (state, [])
        }
        s.lastPickup = now
        let recorded: [Effect] = [.record(.pickup, at: now)]

        guard !s.isAsking else { return (s, recorded) }
        // Nothing to measure from.
        guard let anchor = s.anchor else { return (s, recorded) }
        // Too soon.
        guard now - anchor >= s.config.interval else { return (s, recorded) }
        // Just asked.
        if let lastNudge = s.lastNudge, now - lastNudge < Constants.nudgeCooldown {
            return (s, recorded)
        }

        s.lastNudge = now
        // Consume the slip. Without this the anchor stays older than the interval for
        // the rest of the session and every pick-up past the cooldown asks again.
        if s.config.mode == .slip { s.lastSlip = nil }
        s.isAsking = true
        return (s, recorded + [
            .record(.nudge, at: now),
            .present(.asking(holdSeconds: s.config.holdSeconds)),
        ])

    case .askNow:
        guard s.sessionStart != nil, !s.isAsking else { return (state, []) }
        s.lastNudge = now
        if s.config.mode == .slip { s.lastSlip = nil }
        s.isAsking = true
        return (s, [
            .record(.nudge, at: now),
            .present(.asking(holdSeconds: s.config.holdSeconds)),
        ])

    case .tick:
        // The phase is derived, so a tick changes nothing. It exists for the countdown.
        return (state, [])

    case let .dismiss(how):
        guard s.isAsking else { return (state, []) }
        s.isAsking = false
        let kind: RecordKind = how == .down ? .down : .through
        return (s, [.record(kind, at: now), .dismissAsking])
    }
}
