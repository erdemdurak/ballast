import Foundation

struct Prefs: Codable {
    var task = ""
    var intervalMin = Constants.defaultIntervalMin
    var sensitivity = Constants.defaultSensitivity
    var mode: Mode = .slip
    var holdSeconds: TimeInterval = Constants.hold
    /// How long the work itself should take. The countdown the user actually cares about.
    var durationMin: Int = 60
}

struct Ev: Codable {
    var t: TimeInterval
    var type: RecordKind
}

struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    var task = ""
    var startedAt: TimeInterval = 0
    var endedAt: TimeInterval?
    var events: [Ev] = []
    /// Int8 per 5 s bucket, capped magnitude.
    var trace: [Int8] = []

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

    func begin(task: String, at t: TimeInterval) {
        open = SessionRecord(task: task, startedAt: t)
        persist()
    }

    func append(_ kind: RecordKind, at t: TimeInterval) {
        open?.events.append(Ev(t: t, type: kind))
        persist()
    }

    /// Held in memory and written out with the next event or at session end. A trace
    /// bucket is not an event, and rewriting the whole store every 5 s to save one
    /// byte of decoration is not worth the churn.
    func appendTrace(_ magnitude: Double) {
        let capped = Int8(clamping: Int((min(magnitude, 6) / 6 * 127).rounded()))
        open?.trace.append(capped)
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
