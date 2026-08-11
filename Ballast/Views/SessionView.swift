import ManagedSettings
import SwiftUI

struct SessionView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            status

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: S.t("session.anchor"))
                Text(model.state.task)
                    .font(Face.display(30, .semibold))
                    .foregroundStyle(Token.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            interruptions
            countdown

            Spacer(minLength: 0)

            // Only worth offering when Screen Time is not watching anything — with
            // apps chosen, self-reporting a slip is redundant.
            if model.screenTime.watchedCount == 0 {
                Button(S.t("session.slipBtn")) { model.logSlip() }
                    .buttonStyle(OutlineButtonStyle(color: Token.slip))
            }

            if model.detector.unavailable {
                Text(S.t("error.motionDenied"))
                    .font(Face.body(13))
                    .foregroundStyle(Token.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(
                        text: "Reminders · \(model.notifications.status)",
                        color: model.notifications.status.contains("queued")
                            ? Token.calm : Token.slip)
                    Eyebrow(
                        text: "Lock screen · \(model.liveActivity.status)",
                        color: model.liveActivity.status == "on" ? Token.calm : Token.slip)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Token.paper)
    }

    private var status: some View {
        HStack {
            Text(clock(model.elapsed))
                .font(Face.data(13, .medium))
                .foregroundStyle(Token.ink)
            Eyebrow(text: S.t("session.inSession"))
            Spacer()
            Button(S.t("session.end")) { model.end() }
                .font(Face.data(13, .medium))
                .foregroundStyle(Token.ink)
                .frame(minHeight: Token.minTarget)
        }
    }

    /// What Screen Time saw: which apps broke the work, and how often. The tokens
    /// are opaque — the system draws the name and icon, this code never reads them.
    @ViewBuilder private var interruptions: some View {
        let counts = SharedState.interruptionCounts()
        let total = counts.reduce(0) { $0 + $1.count }
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Token.line).frame(height: 0.5)
            if total == 0 {
                Eyebrow(text: S.t("session.noInterruptions"), color: Token.calm)
            } else {
                Eyebrow(text: S.t("session.interrupted", total), color: Token.slip)
                ForEach(counts.prefix(4), id: \.index) { row in
                    if row.index < model.screenTime.orderedTokens.count {
                        HStack {
                            Label(model.screenTime.orderedTokens[row.index])
                                .labelStyle(.titleAndIcon)
                                .font(Face.body(15))
                                .foregroundStyle(Token.ink)
                            Spacer()
                            Text("\(row.count)×")
                                .font(Face.data(13, .medium))
                                .foregroundStyle(Token.slip)
                        }
                    }
                }
            }
            Rectangle().fill(Token.line).frame(height: 0.5)
        }
    }

    @ViewBuilder private var countdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch model.phase {
            case .armed:
                Eyebrow(text: S.t("session.armed"), color: Token.slip)
            case .waiting:
                Eyebrow(text: S.t("session.armedIn"))
                Text(clock(model.armedIn ?? 0))
                    .font(Face.data(40, .regular))
                    .foregroundStyle(Token.ink)
                    .monospacedDigit()
            default:
                Eyebrow(text: S.t("session.quiet"), color: Token.calm)
            }
        }
    }
}
