import AppIntents
import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

/// The workout in progress on the Lock Screen and in the Dynamic Island: the current exercise and
/// set, the rest counting down between sets, and buttons to validate a set or skip the rest without
/// unlocking. It starts with the session and ends with it.
struct WorkoutActivityAttributes: Codable, Hashable {
    struct ContentState: Codable, Hashable {
        var exercise: String
        var setNumber: Int
        var sets: Int
        /// « 10 × 60 kg ».
        var load: String
        var doneSets: Int
        var totalSets: Int
        var restStart: Date?
        var restEnd: Date?
        /// Seconds left of a rest on pause.
        var restPaused: Double?

        func isResting(at date: Date) -> Bool {
            guard let restEnd else { return false }
            return restEnd > date
        }
    }

    var routineName: String
}

#if canImport(ActivityKit)
extension WorkoutActivityAttributes: ActivityAttributes {}
#endif

enum WorkoutLiveActivity {
    /// What the Live Activity shows for this state, or nil when no session is in progress.
    static func content(for state: FitnessState, now: Date = Date()) -> (WorkoutActivityAttributes, WorkoutActivityAttributes.ContentState)? {
        guard let session = state.active, !session.isFinished, let exercise = session.currentExercise else { return nil }
        let load = exercise.weight > 0
            ? tr("\(exercise.reps) × \(Self.kilograms(exercise.weight)) kg")
            : tr("\(exercise.reps) répétitions")
        var content = WorkoutActivityAttributes.ContentState(
            exercise: exercise.name,
            setNumber: session.setIndex + 1,
            sets: exercise.sets,
            load: load,
            doneSets: session.sets.count,
            totalSets: session.totalSets
        )
        if let end = session.restEndsAt, end > now {
            content.restStart = min(session.sets.last?.date ?? now, now)
            content.restEnd = end
        }
        content.restPaused = session.restPausedRemaining
        return (WorkoutActivityAttributes(routineName: session.routineName), content)
    }

    private static func kilograms(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Starts, updates or ends the Live Activity to match the workout. Safe to call often.
    static func sync(_ state: FitnessState, now: Date = Date()) async {
        #if canImport(ActivityKit) && os(iOS)
        let running = Activity<WorkoutActivityAttributes>.activities
        guard let (attributes, content) = Self.content(for: state, now: now) else {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        // At the end of the rest the activity is drawn again: « Prêt » replaces the countdown.
        let activityContent = ActivityContent(state: content, staleDate: content.restEnd)
        if let current = running.first(where: { $0.attributes.routineName == attributes.routineName }) {
            await current.update(activityContent)
            for other in running where other.id != current.id {
                await other.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            for other in running {
                await other.end(nil, dismissalPolicy: .immediate)
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity.request(attributes: attributes, content: activityContent, pushType: nil)
        }
        #endif
    }
}

// MARK: - The view (shared: the Lock Screen, and the preview inside the app)

struct WorkoutActivityView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    /// False inside the app: buttons don't run and the timer shows a still value.
    var isLive = true
    var now = Date()

    /// The app style chosen in Tessera: the Lock Screen follows its colors and its font.
    private var style: AppStyle { AppStyle.style(SharedStore.shared.settings.appStyle) }
    private var accent: Color { style.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(attributes.routineName, systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    Text(state.exercise)
                        .font(.headline)
                        .lineLimit(1)
                    Text(tr("Série \(state.setNumber)/\(state.sets) · \(state.load)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                restView
            }
            ProgressView(value: Double(state.doneSets), total: Double(max(1, state.totalSets)))
                .tint(accent)
            HStack(spacing: 8) {
                if state.restPaused != nil {
                    actionButton(tr("Reprendre"), symbol: "play.fill", prominent: false, intent: ResumeRestIntent())
                } else if state.isResting(at: now) {
                    actionButton(tr("Pause"), symbol: "pause.fill", prominent: false, intent: PauseRestIntent())
                }
                if state.isResting(at: now) || state.restPaused != nil {
                    actionButton(tr("Passer"), symbol: "forward.fill", prominent: false, intent: SkipRestIntent())
                }
                actionButton(tr("Série faite"), symbol: "checkmark", prominent: true, intent: CompleteSetIntent())
            }
        }
        .padding(16)
        .fontDesign(style.fontDesign)
    }

    /// The Lock Screen background: the style's screen color, or its card color at night.
    static var background: Color {
        let style = AppStyle.style(SharedStore.shared.settings.appStyle)
        return Color(light: style.screenLight, dark: style.cardDark)
    }

    @ViewBuilder private var restView: some View {
        if let paused = state.restPaused {
            VStack(alignment: .trailing, spacing: 2) {
                Text(tr("En pause"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(Duration.seconds(paused).formatted(.time(pattern: .minuteSecond)))
                    .font(.system(.title, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(accent)
            }
        } else if let start = state.restStart, let end = state.restEnd, end > now {
            VStack(alignment: .trailing, spacing: 2) {
                Text(tr("Repos"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if isLive {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(.title, design: .rounded).weight(.semibold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                } else {
                    Text(Duration.seconds(max(0, end.timeIntervalSince(now))).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(.title, design: .rounded).weight(.semibold).monospacedDigit())
                }
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text(tr("Repos"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(tr("Prêt"))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    @ViewBuilder
    private func actionButton<I: AppIntent>(_ title: String, symbol: String, prominent: Bool, intent: I) -> some View {
        let label = Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(prominent ? style.onAccent : accent)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(prominent ? accent : accent.opacity(0.18), in: Capsule())
        if isLive {
            Button(intent: intent) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}
