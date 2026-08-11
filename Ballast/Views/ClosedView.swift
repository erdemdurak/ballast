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

                VStack(alignment: .leading, spacing: 6) {
                    Rectangle().fill(Token.line).frame(height: 0.5)
                    TraceView(
                        samples: record.trace.map { Double($0) / 127 * 6 },
                        events: record.events,
                        now: record.endedAt ?? record.startedAt,
                        window: max(record.length, 1))
                    Rectangle().fill(Token.line).frame(height: 0.5)
                }

                VStack(spacing: 0) {
                    row(S.t("closed.length"), clock(record.length))
                    row(S.t("closed.feeds"), "\(record.count(.slip))")
                    row(S.t("closed.pickups"), "\(record.count(.pickup))")
                    row(S.t("closed.questions"), "\(record.count(.nudge))")
                }

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
