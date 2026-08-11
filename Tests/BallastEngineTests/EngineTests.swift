import Foundation
import Testing

@testable import BallastEngine

private let t0: TimeInterval = 1_754_900_000
private let min: TimeInterval = 60
private let task = "Finish the chemistry lab write-up"

private func start(_ mode: Mode) -> (Event, TimeInterval) {
    (.startSession(task: task, config: Config(mode: mode)), t0)
}

/// Applies a script of (event, time) pairs and returns the final state.
private func run(_ script: [(Event, TimeInterval)]) -> SessionState {
    var s = SessionState()
    for (event, now) in script { (s, _) = reduce(s, event, now) }
    return s
}

private func asks(_ effects: [Effect]) -> Bool {
    effects.contains { if case .present(.asking) = $0 { return true } else { return false } }
}

private func records(_ effects: [Effect], _ kind: RecordKind) -> Bool {
    effects.contains { if case .record(kind, _) = $0 { return true } else { return false } }
}

// MARK: - §2.5, plus the row it was missing

private struct Row {
    let name: String
    let script: [(Event, TimeInterval)]
    let pickupAt: TimeInterval
    let expectRecorded: Bool
    let expectQuestion: Bool
}

@Test func pickupDecisionTable() {
    let rows: [Row] = [
        Row(
            name: "QUIET, no slip",
            script: [start(.slip)],
            pickupAt: t0 + 30 * min,
            expectRecorded: true, expectQuestion: false),

        Row(
            name: "WAITING, t−t₀ = 19 min",
            script: [start(.slip), (.slip, t0)],
            pickupAt: t0 + 19 * min,
            expectRecorded: true, expectQuestion: false),

        Row(
            name: "WAITING, t−t₀ = 20 min",
            script: [start(.slip), (.slip, t0)],
            pickupAt: t0 + 20 * min,
            expectRecorded: true, expectQuestion: true),

        Row(
            name: "ASKING dismissed 30 s ago",
            script: [
                start(.slip), (.slip, t0),
                (.pickup, t0 + 20 * min),
                (.dismiss(.through), t0 + 20 * min + 2),
            ],
            pickupAt: t0 + 20 * min + 32,
            expectRecorded: true, expectQuestion: false),

        Row(
            name: "ANY mode, no slip ever, t−sessionStart ≥ I",
            script: [start(.any)],
            pickupAt: t0 + 20 * min,
            expectRecorded: true, expectQuestion: true),

        Row(
            name: "SLIP mode, no slip ever",
            script: [start(.slip)],
            pickupAt: t0 + 90 * min,
            expectRecorded: true, expectQuestion: false),

        Row(
            name: "ARMED, call in progress",
            script: [start(.slip), (.slip, t0), (.callChanged(true), t0 + 1)],
            pickupAt: t0 + 20 * min,
            expectRecorded: true, expectQuestion: false),

        // Not in §2.5. Without consuming the slip, this row asks again — and would keep
        // asking every 60 s for the rest of the session.
        Row(
            name: "SLIP mode, dismissed, cooldown expired",
            script: [
                start(.slip), (.slip, t0),
                (.pickup, t0 + 20 * min),
                (.dismiss(.through), t0 + 20 * min + 2),
            ],
            pickupAt: t0 + 21 * min + 5,
            expectRecorded: true, expectQuestion: false),
    ]

    for row in rows {
        let state = run(row.script)
        let (_, effects) = reduce(state, .pickup, row.pickupAt)
        #expect(records(effects, .pickup) == row.expectRecorded, "\(row.name): recorded")
        #expect(asks(effects) == row.expectQuestion, "\(row.name): question")
    }
}

// MARK: - The remaining §2.5 row, which is about the anchor rather than a pick-up

@Test func slipWhileArmedResetsTheAnchor() {
    let armed = run([start(.slip), (.slip, t0)])
    #expect(armed.phase(at: t0 + 20 * min) == .armed)

    let (reset, _) = reduce(armed, .slip, t0 + 20 * min)
    #expect(reset.phase(at: t0 + 20 * min) == .waiting)
}

// MARK: - Behaviour the table implies but does not state

@Test func slipModeGoesQuietAfterAQuestion() {
    let asked = run([start(.slip), (.slip, t0), (.pickup, t0 + 20 * min)])
    #expect(asked.phase(at: t0 + 20 * min) == .asking)

    let (dismissed, _) = reduce(asked, .dismiss(.down), t0 + 20 * min + 2)
    #expect(dismissed.phase(at: t0 + 20 * min + 2) == .quiet)
}

@Test func anyModeReArmsWithoutASlip() {
    var s = run([start(.any), (.pickup, t0 + 20 * min)])
    #expect(s.phase(at: t0 + 20 * min) == .asking)

    // Not QUIET: the anchor is now the nudge, so the next interval is already running.
    // ANY mode never goes quiet — that is the whole difference between the two modes.
    (s, _) = reduce(s, .dismiss(.through), t0 + 20 * min + 2)
    #expect(s.phase(at: t0 + 20 * min + 2) == .waiting)
    #expect(s.phase(at: t0 + 40 * min) == .armed)

    let (_, effects) = reduce(s, .pickup, t0 + 40 * min)
    #expect(asks(effects))
}

@Test func debouncedPickupIsNeitherRecordedNorAsked() {
    let s = run([start(.slip), (.slip, t0), (.pickup, t0 + 20 * min)])
    let (unchanged, effects) = reduce(s, .pickup, t0 + 20 * min + 24)
    #expect(effects.isEmpty)
    #expect(unchanged == s)
}

@Test func blankTaskStartsNothing() {
    let (s, effects) = reduce(SessionState(), .startSession(task: "   ", config: Config()), t0)
    #expect(s.sessionStart == nil)
    #expect(s.phase(at: t0) == .idle)
    #expect(effects.isEmpty)
}

@Test func dismissalIsRecordedEitherWay() {
    let asked = run([start(.slip), (.slip, t0), (.pickup, t0 + 20 * min)])

    let (_, down) = reduce(asked, .dismiss(.down), t0 + 20 * min + 6)
    #expect(records(down, .down))

    let (_, through) = reduce(asked, .dismiss(.through), t0 + 20 * min + 6)
    #expect(records(through, .through))
}

@Test func theQuestionCarriesTheHold() {
    let s = run([start(.slip), (.slip, t0)])
    let (_, effects) = reduce(s, .pickup, t0 + 20 * min)
    #expect(effects.contains(.present(.asking(holdSeconds: Constants.hold))))
}

@Test func aZeroHoldSurvivesToThePresentation() {
    var s = SessionState()
    (s, _) = reduce(s, .startSession(task: task, config: Config(holdSeconds: 0)), t0)
    (s, _) = reduce(s, .slip, t0)
    let (_, effects) = reduce(s, .pickup, t0 + 20 * min)
    #expect(effects.contains(.present(.asking(holdSeconds: 0))))
}

// MARK: - The hold

@Test func theHoldCountsDownAndThenReleases() {
    let asked = t0 + 20 * min
    let table: [(now: TimeInterval, expect: Int)] = [
        (asked, 4),
        (asked + 0.4, 4),
        (asked + 1, 3),
        (asked + 3.1, 1),
        (asked + 3.9, 1),
        (asked + 4, 0),
        (asked + 30, 0),
    ]
    for row in table {
        let left = holdRemaining(holdSeconds: 4, askedAt: asked, now: row.now)
        #expect(left == row.expect, "at +\(row.now - asked)s")
    }
}

@Test func aZeroHoldIsNeverHeld() {
    #expect(holdRemaining(holdSeconds: 0, askedAt: t0, now: t0) == 0)
}

@Test func eventsOutsideASessionDoNothing() {
    for event in [Event.slip, .pickup, .endSession, .dismiss(.down)] {
        let (s, effects) = reduce(SessionState(), event, t0)
        #expect(s == SessionState(), "\(event)")
        #expect(effects.isEmpty, "\(event)")
    }
}
