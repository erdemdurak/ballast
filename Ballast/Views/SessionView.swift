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

            trace
            countdown

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button(S.t("session.slipBtn")) { model.logSlip() }
                    .buttonStyle(OutlineButtonStyle(color: Token.slip))

                Button(S.t("session.simulate")) { model.simulatePickup() }
                    .font(Face.body(13))
                    .foregroundStyle(Token.mute)
                    .frame(minHeight: Token.minTarget)
            }

            if model.detector.unavailable {
                Text(S.t("error.motionDenied"))
                    .font(Face.body(13))
                    .foregroundStyle(Token.ink2)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var trace: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Token.line).frame(height: 0.5)
            TraceView(
                samples: model.trace,
                events: model.open?.events ?? [],
                now: model.nowTick,
                reduceMotion: reduceMotion)
            Rectangle().fill(Token.line).frame(height: 0.5)
            HStack {
                Eyebrow(
                    text: model.detector.isRunning
                        ? S.t("session.motionLive") : S.t("session.motionOff"),
                    color: model.detector.isRunning ? Token.calm : Token.mute)
                Spacer()
                Eyebrow(
                    text: S.t(
                        "session.counts", model.open?.count(.pickup) ?? 0,
                        model.open?.count(.slip) ?? 0))
            }
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
