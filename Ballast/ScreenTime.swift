import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension DeviceActivityName {
    static let daily = Self("ballast.daily")
}

extension DeviceActivityEvent.Name {
    static let feedOpened = Self("ballast.feedOpened")
}

/// The detection half of Screen Time, and only that half. `ManagedSettingsStore` — the
/// shielding API — is deliberately never touched: Ballast warns, it does not block.
///
/// Apple hands back opaque tokens, so the app never learns which apps were chosen.
/// "We cannot see your usage" is literally true.
@Observable
@MainActor
final class ScreenTime {
    /// Called when the watched apps change, so a session already running starts
    /// watching the new choice instead of the old one.
    var onSelectionChanged: (() -> Void)?

    var selection = FamilyActivitySelection() {
        didSet {
            persist()
            onSelectionChanged?()
        }
    }

    private(set) var status = S.t("status.notSetUp")

    private let center = DeviceActivityCenter()
    private let storageKey = "ballast.selection"
    private let orderKey = "ballast.tokenOrder"

    /// A Set has no stable order, so the order the monitor's indices refer to is
    /// frozen here when monitoring starts.
    private(set) var orderedTokens: [ApplicationToken] = []



    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        {
            selection = decoded
        }
        // The monitor's indices point into this list, so it has to survive relaunches.
        if let data = UserDefaults.standard.data(forKey: orderKey),
            let decoded = try? JSONDecoder().decode([ApplicationToken].self, from: data)
        {
            orderedTokens = decoded
        }
        refreshStatus()
    }

    var authorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    var watchedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshStatus()
        } catch {
            status = S.t("status.denied")
            print("Ballast: Screen Time authorisation failed — \(error)")
        }
    }

    /// There is no app-open callback on iOS. `DeviceActivityMonitor` is threshold-driven
    /// only, so the smallest useful granularity is a minute of accumulated use — which
    /// also filters out a three-second glance at a notification.
    func startMonitoring(stepsPerApp: Int = 8, durationMin: Int = 60) {
        guard authorized, watchedCount > 0 else {
            refreshStatus()
            return
        }

        // The window has to start with the session, not at midnight.
        //
        // A threshold counts usage accumulated since the interval began. With a daily
        // 00:00–23:59 schedule, anyone who had already spent a minute in Instagram that
        // morning had crossed every threshold before the session even started — so
        // nothing ever fired again until the next day. Each session now gets its own
        // window, and the count starts at zero with it.
        //
        // Apple requires at least fifteen minutes between start and end.
        let calendar = Calendar.current
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(max(15, durationMin) * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: end),
            repeats: false)

        // One event per app per minute-step. A single event fires only once per
        // monitoring interval, so a ladder of thresholds is the only way to count
        // more than one interruption a day — and per-app events are what make
        // attribution possible at all.
        orderedTokens = Array(selection.applicationTokens)
        if let data = try? JSONEncoder().encode(orderedTokens) {
            UserDefaults.standard.set(data, forKey: orderKey)
        }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for (index, token) in orderedTokens.enumerated() {
            for step in 1...max(1, stepsPerApp) {
                events[DeviceActivityEvent.Name("ballast.\(index).\(step)")] =
                    DeviceActivityEvent(
                        applications: [token],
                        threshold: DateComponents(minute: step))
            }
        }
        if !selection.categoryTokens.isEmpty {
            events[.feedOpened] = DeviceActivityEvent(
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: 1))
        }

        center.stopMonitoring([.daily])
        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
            status = S.t("status.watching", watchedCount)
        } catch {
            status = S.t("status.failed")
            print("Ballast: could not start monitoring — \(error)")
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily])
        refreshStatus()
    }

    private func refreshStatus() {
        if !authorized {
            status = S.t("status.notAllowed")
        } else if watchedCount == 0 {
            status = S.t("status.noApps")
        } else {
            status = S.t("status.chosen", watchedCount)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        refreshStatus()
    }
}
