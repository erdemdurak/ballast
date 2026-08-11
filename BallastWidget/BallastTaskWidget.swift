import SwiftUI
import WidgetKit

/// Unlocking the phone lands you on the Home Screen, so the task is put there too.
/// Unlike the Live Activity this has no 8-hour ceiling and survives between sessions.
struct TaskEntry: TimelineEntry {
    let date: Date
    let task: String
    let endsAt: Date?
    let active: Bool

    var minutesLeft: Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(date) / 60))
    }
}

struct TaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(), task: S.t("setup.task.placeholder"),
            endsAt: Date().addingTimeInterval(1800), active: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        completion(current(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        // A minute a step for the next hour, so the remaining time stays honest
        // without the app having to run.
        let now = Date()
        let entries = (0..<60).map { current(at: now.addingTimeInterval(Double($0) * 60)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func current(at date: Date) -> TaskEntry {
        let ends = SharedState.endsAt
        return TaskEntry(
            date: date,
            task: SharedState.task,
            endsAt: ends > 0 ? Date(timeIntervalSince1970: ends) : nil,
            active: SharedState.sessionActive)
    }
}

struct BallastTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BallastTaskWidget", provider: TaskProvider()) { entry in
            TaskWidgetView(entry: entry)
                .containerBackground(Token.paper, for: .widget)
        }
        .configurationDisplayName("Paperweight")
        .description("The one thing you named, and how long is left.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline,
        ])
    }
}

private struct TaskWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TaskEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.active ? "\(entry.minutesLeft)m · \(entry.task)" : "Paperweight")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(S.t("session.anchor").uppercased(with: .current))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Text(entry.task).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                if entry.active, let endsAt = entry.endsAt, endsAt > entry.date {
                    Text(timerInterval: entry.date...endsAt, countsDown: true)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text(S.t("session.anchor").uppercased(with: .current))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(10 * 0.18)
                    .foregroundStyle(Token.mute)

                Text(entry.active ? entry.task : S.t("empty.noSessions"))
                    .font(.system(size: family == .systemSmall ? 18 : 22, weight: .semibold)
                        .width(.condensed))
                    .foregroundStyle(Token.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if entry.active, let endsAt = entry.endsAt {
                    if endsAt > entry.date {
                        Text(timerInterval: entry.date...endsAt, countsDown: true)
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundStyle(Token.ink)
                    } else {
                        Text(S.t("live.done"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Token.slip)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
