import DeviceActivity
import FamilyControls
import Foundation

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
    var selection = FamilyActivitySelection() {
        didSet { persist() }
    }

    private(set) var status = "not set up"

    private let center = DeviceActivityCenter()
    private let storageKey = "ballast.selection"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        {
            selection = decoded
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
            status = "denied"
            print("Ballast: Screen Time authorisation failed — \(error)")
        }
    }

    /// There is no app-open callback on iOS. `DeviceActivityMonitor` is threshold-driven
    /// only, so the smallest useful granularity is a minute of accumulated use — which
    /// also filters out a three-second glance at a notification.
    func startMonitoring() {
        guard authorized, watchedCount > 0 else {
            refreshStatus()
            return
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true)

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: 1))

        center.stopMonitoring([.daily])
        do {
            try center.startMonitoring(.daily, during: schedule, events: [.feedOpened: event])
            status = "watching \(watchedCount)"
        } catch {
            status = "failed: \(error)"
            print("Ballast: could not start monitoring — \(error)")
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily])
        refreshStatus()
    }

    private func refreshStatus() {
        if !authorized {
            status = "not allowed"
        } else if watchedCount == 0 {
            status = "no apps chosen"
        } else {
            status = "\(watchedCount) chosen"
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        refreshStatus()
    }
}
