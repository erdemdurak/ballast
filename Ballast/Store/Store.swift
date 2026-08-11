import Foundation

struct Prefs: Codable {
    var task = ""
    var intervalMin = Constants.defaultIntervalMin
    var holdSeconds: TimeInterval = Constants.hold
    /// How long the work itself should take. The countdown the user actually cares about.
    var durationMin: Int = 60
    /// Threshold crossings countable per app per day. Apple documents no ceiling on
    /// DeviceActivityEvent count, so this is adjustable and starts modest.
    var interruptionSteps: Int = 8
}

struct Ev: Codable {
    var t: TimeInterval
    var type: RecordKind
}

struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    var task = ""
    var startedAt: TimeInterval = 0
    /// Frozen at the start. Reading the live preference meant moving the slider
    /// mid-session moved the deadline underneath the user.
    var durationMin: Int = 60
    var endedAt: TimeInterval?
    var events: [Ev] = []
    /// Int8 per 5 s bucket, capped magnitude.
    var trace: [Int8] = []

    /// Records written before a field existed must still load. A stored session that
    /// cannot be decoded is a session the user cannot end — and its reminders keep
    /// arriving with no way to stop them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        task = try c.decodeIfPresent(String.self, forKey: .task) ?? ""
        startedAt = try c.decodeIfPresent(TimeInterval.self, forKey: .startedAt) ?? 0
        durationMin = try c.decodeIfPresent(Int.self, forKey: .durationMin) ?? 60
        endedAt = try c.decodeIfPresent(TimeInterval.self, forKey: .endedAt)
        events = try c.decodeIfPresent([Ev].self, forKey: .events) ?? []
        trace = try c.decodeIfPresent([Int8].self, forKey: .trace) ?? []
    }

    init(task: String = "", startedAt: TimeInterval = 0, durationMin: Int = 60) {
        self.task = task
        self.startedAt = startedAt
        self.durationMin = durationMin
    }

    var length: TimeInterval { (endedAt ?? startedAt) - startedAt }
    func count(_ kind: RecordKind) -> Int { events.filter { $0.type == kind }.count }
}

/// Local only. No account, no sync, no server.
@Observable
final class Store {
    private(set) var prefs = Prefs()
    private(set) var sessions: [SessionRecord] = []
    /// The session in progress, persisted after every event so process death is survivable.
    private(set) var open: SessionRecord?
    /// Set when the disk read fails, so the UI can say so instead of pretending.
    private(set) var loadError: String?

    private let url: URL

    init(url: URL? = nil) {
        self.url =
            url
            ?? URL.applicationSupportDirectory.appending(path: "Ballast/store.json")
        load()
    }

    // MARK: - Mutation

    func save(prefs: Prefs) {
        self.prefs = prefs
        persist()
    }

    func begin(task: String, durationMin: Int, at t: TimeInterval) {
        open = SessionRecord(task: task, startedAt: t, durationMin: durationMin)
        persist()
    }

    func append(_ kind: RecordKind, at t: TimeInterval) {
        open?.events.append(Ev(t: t, type: kind))
        persist()
    }

    @discardableResult
    func end(at t: TimeInterval) -> SessionRecord? {
        guard var record = open else { return nil }
        record.endedAt = t
        sessions.insert(record, at: 0)
        open = nil
        prune()
        persist()
        return record
    }

    func wipe() {
        sessions = []
        open = nil
        persist()
    }

    // MARK: - Disk

    private struct Disk: Codable {
        var prefs = Prefs()
        var sessions: [SessionRecord] = []
        var open: SessionRecord?
    }

    /// 30 days of full sessions, then drop them.
    private func prune() {
        let cutoff = Date().timeIntervalSince1970 - 30 * 24 * 60 * 60
        sessions.removeAll { $0.startedAt < cutoff }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let disk = try JSONDecoder().decode(Disk.self, from: Data(contentsOf: url))
            prefs = disk.prefs
            sessions = disk.sessions
            open = disk.open
        } catch {
            loadError = String(describing: error)
        }
    }

    private func persist() {
        let disk = Disk(prefs: prefs, sessions: sessions, open: open)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(disk).write(to: url, options: .atomic)
        } catch {
            // Not swallowed: the next launch would silently lose the session.
            assertionFailure("Ballast: could not persist — \(error)")
            print("Ballast: could not persist — \(error)")
        }
    }
}
