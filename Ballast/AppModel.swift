import CallKit
import Foundation
import SwiftUI
import UIKit
import UserNotifications

enum Route {
    case setup
    case session
    case asking
    case closed
}

@Observable
@MainActor
final class AppModel {
    private(set) var state = SessionState()
    private(set) var route: Route = .setup
    private(set) var closed: SessionRecord?

    /// Peak |Δ| per 110 ms bucket. 160 samples ≈ 18 seconds.
    private(set) var trace: [Double] = []
    private(set) var askedAt: TimeInterval = 0
    private(set) var nowTick: TimeInterval = Date().timeIntervalSince1970

    var draft: Prefs

    let store: Store
    let detector = MotionDetector()
    let liveActivity = LiveActivityController()
    let notifications = Notifications()
    let screenTime = ScreenTime()

    private var timer: Timer?
    private let callObserver = CXCallObserver()
    private var callDelegate: CallWatcher?
    private var lastEngineTick: TimeInterval = 0
    private var bucketPeak: Double = 0
    private var bucketStart: TimeInterval = 0
    private var awaySince: TimeInterval?

    /// Total time the app spent out of the foreground during this session — time iOS
    /// gave us no motion at all. Surfaced rather than hidden.
    private(set) var awayTotal: TimeInterval = 0

    init(store: Store = Store()) {
        self.store = store
        self.draft = store.prefs

        detector.onPickup = { [weak self] t in self?.send(.pickup, at: t) }
        detector.onSample = { [weak self] magnitude in self?.sample(magnitude) }

        let watcher = CallWatcher { [weak self] active in
            self?.send(.callChanged(active))
        }
        callDelegate = watcher
        callObserver.setDelegate(watcher, queue: .main)

        UNUserNotificationCenter.current().delegate = notifications
        // Tapping the question is a pick-up: let the engine decide, exactly as it
        // does for a real one.
        notifications.onOpen = { [weak self] in self?.send(.pickup) }

        // After resume: draining first would clear the timestamp with no session
        // to receive it.
        if let open = store.open {
            resume(open)
            drainMonitorSlip()
        }
    }

    // MARK: - Derived

    var config: Config {
        Config(
            intervalMin: draft.intervalMin, mode: draft.mode,
            holdSeconds: draft.holdSeconds, sensitivity: draft.sensitivity)
    }

    var phase: Phase { state.phase(at: nowTick) }

    var elapsed: TimeInterval { nowTick - (state.sessionStart ?? nowTick) }

    /// Seconds until the next pick-up would ask. Nil when nothing is owed.
    var armedIn: TimeInterval? {
        guard let anchor = state.anchor else { return nil }
        return max(0, state.config.interval - (nowTick - anchor))
    }

    var hold: Int {
        holdRemaining(
            holdSeconds: state.config.holdSeconds, askedAt: askedAt, now: nowTick)
    }

    /// Minutes since the anchor, for the asking copy.
    var minutesSinceAnchor: Int {
        guard let anchor = askAnchor else { return draft.intervalMin }
        return Int((askedAt - anchor) / 60)
    }

    private var askAnchor: TimeInterval?

    var open: SessionRecord? { store.open }

    // MARK: - Intent

    func start() {
        guard !draft.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.save(prefs: draft)
        let now = Date().timeIntervalSince1970
        store.begin(task: draft.task, at: now)
        trace = []
        closed = nil
        awayTotal = 0
        awaySince = nil
        detector.threshold = Constants.sensitivityLadder[draft.sensitivity - 1]
        detector.start()
        route = .session
        startClock()
        UIApplication.shared.isIdleTimerDisabled = true
        send(.startSession(task: draft.task, config: config), at: now)
        liveActivity.start(task: draft.task, armedAt: armedAtDate, endsAt: endsAtDate)
        syncActivity()
        armNotifications()

        SharedState.task = draft.task
        SharedState.intervalMin = draft.intervalMin
        SharedState.endsAt = endsAtDate?.timeIntervalSince1970 ?? 0
        SharedState.sessionActive = true
        screenTime.startMonitoring()
    }

    func end() {
        let now = Date().timeIntervalSince1970
        send(.endSession, at: now)
        closed = store.end(at: now)
        detector.stop()
        stopClock()
        UIApplication.shared.isIdleTimerDisabled = false
        liveActivity.end()
        notifications.cancel()
        SharedState.sessionActive = false
        screenTime.stopMonitoring()
    }

    /// iOS suspends accelerometer delivery outside the foreground, so a session that
    /// leaves the screen is a session that sees nothing. Keep the screen awake while
    /// one is running, and account for any gap when the app comes back.
    func setForeground(_ active: Bool) {
        guard state.sessionStart != nil else {
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        if active {
            drainMonitorSlip()
            if let since = awaySince { awayTotal += Date().timeIntervalSince1970 - since }
            awaySince = nil
            UIApplication.shared.isIdleTimerDisabled = true
            detector.start()
            startClock()
        } else {
            awaySince = Date().timeIntervalSince1970
            UIApplication.shared.isIdleTimerDisabled = false
            detector.stop()
            stopClock()
        }
    }

    func logSlip() { send(.slip) }

    /// The simulator has no accelerometer, and the spec puts this under the slip button
    /// regardless. It goes through the same engine path a real pick-up does.
    func simulatePickup() { send(.pickup) }

    func dismiss(_ how: Dismissal) { send(.dismiss(how)) }

    func newSession() {
        closed = nil
        route = .setup
    }

    // MARK: - Engine

    private func send(_ event: Event, at now: TimeInterval = Date().timeIntervalSince1970) {
        // Slip mode consumes the anchor when the question fires, so the copy's "n
        // minutes ago" has to be read before the reduce, not after.
        let anchorBefore = state.anchor
        let (next, effects) = reduce(state, event, now)
        state = next
        for effect in effects { apply(effect, at: now, anchorBefore: anchorBefore) }
        if case .tick = event {} else { syncActivity() }
    }

    /// When the work is due. Held on the store so it survives process death.
    var endsAtDate: Date? {
        guard let start = state.sessionStart else { return nil }
        return Date(timeIntervalSince1970: start + Double(draft.durationMin) * 60)
    }

    /// Minutes left on the work, for the reminder copy.
    var minutesLeft: Int {
        guard let endsAt = endsAtDate else { return 0 }
        return Int((endsAt.timeIntervalSince1970 - nowTick) / 60)
    }

    /// When the next pick-up starts asking, as a wall-clock date for the Lock Screen.
    private var armedAtDate: Date? {
        state.anchor.map { Date(timeIntervalSince1970: $0 + state.config.interval) }
    }

    private func syncActivity() {
        guard state.sessionStart != nil else { return }
        liveActivity.update(armedAt: armedAtDate, asking: state.isAsking, endsAt: endsAtDate)
        rescheduleQuestions()
    }

    /// The app is asleep when the questions come due, so the whole series is scheduled
    /// ahead and rebuilt whenever the anchor moves.
    private func rescheduleQuestions() {
        guard let start = state.sessionStart else {
            notifications.cancel()
            return
        }
        // Reminders are about the work, not about a slip. Running them from the
        // engine's anchor meant "After a scroll" sessions — where the anchor is nil
        // until a feed is logged — scheduled nothing at all.
        let base = max(state.lastNudge ?? start, start)
        notifications.schedule(
            task: state.task,
            from: Date(timeIntervalSince1970: base),
            every: state.config.interval,
            endsAt: endsAtDate)
    }

    private func apply(_ effect: Effect, at now: TimeInterval, anchorBefore: TimeInterval?) {
        switch effect {
        case let .record(kind, t):
            store.append(kind, at: t)
        case let .present(screen):
            switch screen {
            case .asking:
                askAnchor = anchorBefore
                askedAt = now
                nowTick = now
                route = .asking
            case .closed:
                route = .closed
            }
        case .dismissAsking:
            route = .session
        }
    }

    private func resume(_ record: SessionRecord) {
        var s = SessionState(task: record.task, config: config, sessionStart: record.startedAt)
        for event in record.events {
            switch event.type {
            case .slip: s.lastSlip = event.t
            case .pickup: s.lastPickup = event.t
            case .nudge:
                s.lastNudge = event.t
                s.isAsking = true
                if s.config.mode == .slip { s.lastSlip = nil }
            case .down, .through: s.isAsking = false
            }
        }
        state = s
        trace = []
        askedAt = s.lastNudge ?? 0
        route = s.isAsking ? .asking : .session
        detector.threshold = Constants.sensitivityLadder[draft.sensitivity - 1]
        detector.start()
        startClock()
        UIApplication.shared.isIdleTimerDisabled = true
        // A resumed session is still a session: it needs the question scheduled and,
        // if this is the first run, the permission asked for.
        liveActivity.start(task: s.task, armedAt: armedAtDate, endsAt: endsAtDate)
        armNotifications()
    }

    /// The monitor runs in another process and can only leave a timestamp behind.
    /// Fold anything it recorded into the engine the moment the app runs again.
    private func drainMonitorSlip() {
        let recorded = SharedState.lastSlip
        guard recorded > 0, recorded > (state.lastSlip ?? 0) else { return }
        SharedState.lastSlip = 0
        send(.slip, at: recorded)
    }

    /// Asks once, then (re)schedules. Safe to call repeatedly — iOS only shows the
    /// prompt the first time.
    private func armNotifications() {
        Task {
            _ = await notifications.requestAuthorization()
            self.rescheduleQuestions()
        }
    }

    // MARK: - Clock and trace

    private func startClock() {
        stopClock()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onClock() }
        }
    }

    private func stopClock() {
        timer?.invalidate()
        timer = nil
    }

    private func onClock() {
        nowTick = Date().timeIntervalSince1970
        if nowTick - lastEngineTick >= 1 {
            lastEngineTick = nowTick
            send(.tick, at: nowTick)
        }
    }

    private func sample(_ magnitude: Double) {
        trace.append(magnitude)
        if trace.count > 160 { trace.removeFirst(trace.count - 160) }

        // The live trace is 110 ms samples; the stored one is 5 s buckets, peak held,
        // for the whole-session picture on the closed screen.
        let now = Date().timeIntervalSince1970
        if bucketStart == 0 { bucketStart = now }
        bucketPeak = max(bucketPeak, magnitude)
        if now - bucketStart >= 5 {
            store.appendTrace(bucketPeak)
            bucketPeak = 0
            bucketStart = now
        }
    }
}

/// `CXCallObserver` keeps only a weak delegate, so this is held by the model.
private final class CallWatcher: NSObject, CXCallObserverDelegate {
    private let onChange: @MainActor (Bool) -> Void

    init(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    func callObserver(_ observer: CXCallObserver, callChanged call: CXCall) {
        let active = observer.calls.contains { !$0.hasEnded }
        Task { @MainActor in self.onChange(active) }
    }
}
