import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen, Dynamic Island and StandBy. This is the answer to "I picked the phone
/// up and nothing happened": the phone shows the Lock Screen on every raise, so the
/// task is already there when you look.
struct BallastLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BallastAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Token.paper)
                .activitySystemActionForegroundColor(Token.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(S.t("session.anchor").uppercased(with: .current))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Token.mute)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.task)
                            .font(.system(size: 22, weight: .semibold).width(.condensed))
                            .lineLimit(2)
                        StatusLine(state: context.state)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Mark()
            } compactTrailing: {
                if let armedAt = context.state.armedAt, !context.state.asking {
                    Text(timerInterval: Date()...armedAt, countsDown: true)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Mark()
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<BallastAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                (context.state.asking ? S.t("ask.title") : S.t("session.anchor"))
                    .uppercased(with: .current)
            )
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(11 * 0.18)
            .foregroundStyle(context.state.asking ? Token.slip : Token.mute)

            Text(context.attributes.task)
                .font(.system(size: 26, weight: .semibold).width(.condensed))
                .foregroundStyle(Token.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Token.line).frame(height: 0.5)

            StatusLine(state: context.state)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusLine: View {
    let state: BallastAttributes.ContentState

    var body: some View {
        if state.asking {
            Text(S.t("ask.list"))
                .font(.system(size: 13))
                .foregroundStyle(Token.slip)
        } else if let armedAt = state.armedAt, armedAt > Date() {
            HStack(spacing: 8) {
                Text(S.t("session.armedIn").uppercased(with: .current))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Token.mute)
                Text(timerInterval: Date()...armedAt, countsDown: true)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(Token.ink)
            }
        } else {
            Text(S.t("session.armed").uppercased(with: .current))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Token.slip)
        }
    }
}

/// The icon mark, at Dynamic Island scale.
private struct Mark: View {
    var body: some View {
        Canvas { context, size in
            let inset = size.width * 0.16
            let arm = size.width * 0.20
            let a = inset
            let b = size.width - inset
            var path = Path()
            path.move(to: CGPoint(x: a, y: a + arm))
            path.addLine(to: CGPoint(x: a, y: a))
            path.addLine(to: CGPoint(x: a + arm, y: a))
            path.move(to: CGPoint(x: b - arm, y: a))
            path.addLine(to: CGPoint(x: b, y: a))
            path.addLine(to: CGPoint(x: b, y: a + arm))
            path.move(to: CGPoint(x: b, y: b - arm))
            path.addLine(to: CGPoint(x: b, y: b))
            path.addLine(to: CGPoint(x: b - arm, y: b))
            path.move(to: CGPoint(x: a + arm, y: b))
            path.addLine(to: CGPoint(x: a, y: b))
            path.addLine(to: CGPoint(x: a, y: b - arm))
            context.stroke(
                path, with: .color(.primary),
                style: StrokeStyle(lineWidth: size.width * 0.09, lineCap: .round, lineJoin: .round))
            let r = size.width * 0.07
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: size.width / 2 - r, y: size.height / 2 - r, width: r * 2, height: r * 2)),
                with: .color(.primary))
        }
        .frame(width: 20, height: 20)
    }
}
