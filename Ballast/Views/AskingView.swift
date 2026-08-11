import SwiftUI

/// Appears without transition — a cut, like a hardware interrupt.
struct AskingView: View {
    @Bindable var model: AppModel

    private var held: Bool { model.hold > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()

            Eyebrow(text: S.t("ask.eyebrow"), color: Token.slip)

            Text(S.t("ask.title"))
                .font(Face.display(40, .bold))
                .foregroundStyle(Token.ink)

            VStack(alignment: .leading, spacing: 10) {
                Rectangle().fill(Token.line).frame(height: 0.5)
                Eyebrow(text: S.t("ask.list"))
                Text(model.state.task)
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Token.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Token.line).frame(height: 0.5)
            }

            Text(
                S.t(
                    model.askedAfterSlip ? "ask.body.slip" : "ask.body.any",
                    S.minutes(model.minutesSinceAnchor))
            )
            .font(Face.body(17))
            .foregroundStyle(Token.ink2)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 12) {
                Button(S.t("ask.down")) { model.dismiss(.down) }
                    .buttonStyle(FilledButtonStyle())

                Button(held ? S.t("ask.through.held", model.hold) : S.t("ask.through")) {
                    model.dismiss(.through)
                }
                .buttonStyle(OutlineButtonStyle(inert: held))
                .disabled(held)
                .accessibilityLabel(
                    held ? S.t("a11y.hold", model.hold) : S.t("ask.through"))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.panel)
    }
}
