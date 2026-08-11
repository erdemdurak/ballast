import SwiftUI

/// The interface signature. Amplitude is peak |Δ| per sample, mirrored about a
/// baseline, capped at 6 m/s². Direction is locked left-to-right in every locale —
/// mirroring it under RTL would reverse what a session means.
struct TraceView: View {
    let samples: [Double]
    let events: [Ev]
    let now: TimeInterval
    /// Seconds of history across the full width.
    var window: TimeInterval = 18
    var sampleInterval: TimeInterval = 0.11
    var reduceMotion = false

    var body: some View {
        Canvas { context, size in
            let mid = size.height / 2
            context.stroke(
                Path { $0.move(to: CGPoint(x: 0, y: mid)); $0.addLine(to: CGPoint(x: size.width, y: mid)) },
                with: .color(Token.line), lineWidth: 0.5)

            guard !samples.isEmpty else { return }
            let step = size.width / CGFloat(max(samples.count - 1, 1))
            for (i, value) in samples.enumerated() {
                let amplitude = CGFloat(min(value, 6) / 6) * (mid - 2)
                guard amplitude > 0.3 else { continue }
                let x = CGFloat(i) * step
                context.stroke(
                    Path {
                        $0.move(to: CGPoint(x: x, y: mid - amplitude))
                        $0.addLine(to: CGPoint(x: x, y: mid + amplitude))
                    },
                    with: .color(Token.ink), lineWidth: 1)
            }

            for event in events {
                guard let x = position(of: event.t, width: size.width) else { continue }
                let color: Color
                switch event.type {
                case .slip: color = Token.slip
                case .pickup, .nudge: color = Token.pickup
                default: continue
                }
                context.stroke(
                    Path {
                        $0.move(to: CGPoint(x: x, y: 0))
                        $0.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(color), lineWidth: 1)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 2, y: 0, width: 4, height: 4)),
                    with: .color(color))
            }
        }
        .frame(height: 72)
        .accessibilityElement()
        .accessibilityLabel(summary)
    }

    private func position(of t: TimeInterval, width: CGFloat) -> CGFloat? {
        let age = now - t
        guard age >= 0, age <= window else { return nil }
        return width * CGFloat(1 - age / window)
    }

    /// A summary, not a waveform. Updated at most once a minute by the caller.
    private var summary: String {
        let pickups = events.filter { $0.type == .pickup }.count
        let quietFor = samples.reversed().prefix(while: { $0 < Constants.stillnessDelta }).count
        let state =
            quietFor == samples.count && !samples.isEmpty
            ? S.t("a11y.trace.quiet", Int(Double(quietFor) * sampleInterval / 60))
            : S.t("a11y.trace.active")
        return S.t("a11y.trace", state, pickups)
    }
}
