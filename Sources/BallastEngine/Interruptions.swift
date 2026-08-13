import Foundation

public struct Interruption: Equatable, Sendable {
    /// Categories arrive as one event with no per-app token, so they cannot be
    /// attributed to anything nameable. They still count.
    public static let category = -1

    public let index: Int
    public let count: Int

    public init(index: Int, count: Int) {
        self.index = index
        self.count = count
    }
}

/// Tallies the "appIndex:timestamp" lines the DeviceActivity monitor leaves in the
/// shared container.
///
/// Ties break on index, not on dictionary order: without that the rows swap places
/// between redraws whenever two apps interrupted the same number of times.
/// Malformed lines are dropped rather than crashing — this input crosses a process
/// boundary and is not ours to trust.
public func tallyInterruptions(_ entries: [String]) -> [Interruption] {
    var counts: [Int: Int] = [:]
    for entry in entries {
        guard let field = entry.split(separator: ":").first,
            let index = Int(field),
            index >= Interruption.category
        else { continue }
        counts[index, default: 0] += 1
    }
    return
        counts
        .map { Interruption(index: $0.key, count: $0.value) }
        .sorted { ($0.count, $1.index) > ($1.count, $0.index) }
}
