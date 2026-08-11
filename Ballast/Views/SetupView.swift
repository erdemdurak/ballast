import FamilyControls
import SwiftUI

struct SetupView: View {
    @Bindable var model: AppModel
    @FocusState private var taskFocused: Bool
    @State private var showPicker = false

    private var canStart: Bool {
        !model.draft.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Eyebrow(text: "Hold Focus", color: Token.ink)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text(S.t("setup.title"))
                        .font(Face.display(34, .bold))
                        .foregroundStyle(Token.ink)
                    Text(S.t("setup.sub"))
                        .font(Face.body(15))
                        .foregroundStyle(Token.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                field
                duration
                feeds
                holdToggle

                Button(S.t("setup.start")) { model.start() }
                    .buttonStyle(FilledButtonStyle())
                    .disabled(!canStart)
                    .opacity(canStart ? 1 : 0.35)

                recent
            }
            .padding(24)
        }
        .background(Token.paper)
        .scrollDismissesKeyboard(.interactively)
    }

    // The one required field, and the only element with a heavy underline.
    private var field: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: S.t("setup.task.label"))
            TextField(S.t("setup.task.placeholder"), text: $model.draft.task, axis: .vertical)
                .font(Face.display(24, .semibold))
                .foregroundStyle(Token.ink)
                .tint(Token.slip)
                .lineLimit(1...3)
                .focused($taskFocused)
                .submitLabel(.done)
                // A vertical-axis TextField inserts a newline instead of submitting,
                // so onSubmit never fires and the keyboard stays up. Catch the return
                // here — a task is one sentence, it never wants a line break.
                .onChange(of: model.draft.task) { _, entered in
                    guard entered.contains("\n") else { return }
                    model.draft.task =
                        entered
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                    taskFocused = false
                }
            Rectangle()
                .fill(Token.ink)
                .frame(height: 2)
        }
    }

    /// The work's own clock. This is what the reminder counts down.
    private var duration: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: S.t("setup.duration"))
                Spacer()
                Text("\(model.draft.durationMin) min")
                    .font(Face.data(13, .medium))
                    .foregroundStyle(Token.ink)
            }
            Slider(
                value: Binding(
                    get: { Double(model.draft.durationMin) },
                    set: { model.draft.durationMin = Int($0) }),
                in: 15...240, step: 15
            )
            .tint(Token.ink)
        }
    }

    /// Screen Time is what lets the question fire because you slipped rather than
    /// because a timer expired.
    private var feeds: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: S.t("setup.feeds"))
                Spacer()
                Text(model.screenTime.status)
                    .font(Face.data(13, .medium))
                    .foregroundStyle(
                        model.screenTime.watchedCount > 0 ? Token.calm : Token.mute)
            }
            Button(S.t("setup.feeds.pick")) {
                Task {
                    if !model.screenTime.authorized { await model.screenTime.authorize() }
                    if model.screenTime.authorized { showPicker = true }
                }
            }
            .buttonStyle(OutlineButtonStyle(color: Token.ink))
            HStack {
                Eyebrow(text: S.t("setup.steps"))
                Spacer()
                Text("\(model.draft.interruptionSteps)")
                    .font(Face.data(13, .medium))
                    .foregroundStyle(Token.ink)
            }
            Slider(
                value: Binding(
                    get: { Double(model.draft.interruptionSteps) },
                    set: { model.draft.interruptionSteps = Int($0) }),
                in: 1...12, step: 1
            )
            .tint(Token.ink)
            Text(S.t("setup.steps.hint"))
                .font(Face.body(13))
                .foregroundStyle(Token.mute)
                .fixedSize(horizontal: false, vertical: true)
            Text(S.t("perm.screentime.pre"))
                .font(Face.body(13))
                .foregroundStyle(Token.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        // screenTime is a let, so the picker gets an explicit binding rather than a key path.
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Binding(
                get: { model.screenTime.selection },
                set: { model.screenTime.selection = $0 }))
    }

    private var holdToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                S.t("setup.holdZero"),
                isOn: Binding(
                    get: { model.draft.holdSeconds == 0 },
                    set: { model.draft.holdSeconds = $0 ? 0 : Constants.hold })
            )
            .font(Face.body(14))
            .foregroundStyle(Token.ink2)
            .tint(Token.ink)
            Text(S.t("setup.holdZero.hint"))
                .font(Face.body(13))
                .foregroundStyle(Token.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: S.t("setup.recent"))
            if model.store.sessions.isEmpty {
                Text(S.t("empty.noSessions"))
                    .font(Face.body(14))
                    .foregroundStyle(Token.mute)
            } else {
                ForEach(model.store.sessions.prefix(3)) { session in
                    HStack {
                        Text(session.task)
                            .font(Face.display(15))
                            .foregroundStyle(Token.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(
                            "\(clock(session.length)) · \(session.count(.down))/\(session.count(.nudge))"
                        )
                        .font(Face.data(13))
                        .foregroundStyle(Token.mute)
                    }
                    Divider().overlay(Token.line)
                }
                // No confirmation gauntlet, per §3.
                Button(S.t("setup.wipe")) { model.store.wipe() }
                    .font(Face.body(14))
                    .foregroundStyle(Token.slip)
                    .frame(minHeight: Token.minTarget)
            }
            if let failure = model.store.loadError {
                Text(S.t("error.load"))
                    .font(Face.body(13))
                    .foregroundStyle(Token.slip)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHint(failure)
            }
        }
    }
}

func clock(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
