import ManagedSettings
import SwiftUI

struct ClosedView: View {
    @Bindable var model: AppModel

    private var record: SessionRecord? { model.closed }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Eyebrow(text: S.t("closed.title"))

            if let record {
                Text(record.task)
                    .font(Face.display(30, .semibold))
                    .foregroundStyle(Token.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    row(S.t("closed.length"), clock(record.length))
                    row(S.t("closed.feeds"), "\(record.count(.slip))")
                    row(S.t("closed.pickups"), "\(record.count(.pickup))")
                    row(S.t("closed.questions"), "\(record.count(.nudge))")
                }

                interruptions

                // The only number that matters.
                Text(S.t("closed.putDown", record.count(.down), record.count(.nudge)))
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Token.ink)

                if record.count(.nudge) > 0 && record.count(.down) == 0 {
                    Text(S.t("closed.longer"))
                        .font(Face.body(14))
                        .foregroundStyle(Token.ink2)
                }
            }

            Spacer()

            Button(S.t("closed.next")) { model.newSession() }
                .buttonStyle(FilledButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Token.paper)
    }

    /// Named, so the summary answers "what actually broke the work".
    @ViewBuilder private var interruptions: some View {
        let counts = SharedState.interruptionCounts()
        if !counts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: S.t("closed.interruptedBy"), color: Token.slip)
                ForEach(counts.prefix(4), id: \.index) { entry in
                    if entry.index < model.screenTime.orderedTokens.count {
                        HStack {
                            Label(model.screenTime.orderedTokens[entry.index])
                                .labelStyle(.titleAndIcon)
                                .font(Face.body(15))
                                .foregroundStyle(Token.ink)
                            Spacer()
                            Text("\(entry.count)×")
                                .font(Face.data(13, .medium))
                                .foregroundStyle(Token.slip)
                        }
                    }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(Face.body(15))
                    .foregroundStyle(Token.ink2)
                Spacer()
                Text(value)
                    .font(Face.data(15, .medium))
                    .foregroundStyle(Token.ink)
            }
            .frame(minHeight: 40)
            Rectangle().fill(Token.line).frame(height: 0.5)
        }
    }
}
