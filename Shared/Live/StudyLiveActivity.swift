import AppIntents
import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

/// The study timer on the Lock Screen and in the Dynamic Island, in the style of the workout: the
/// course, the time studied counting up, the week toward its goal, and buttons to stop and log the
/// time, or cancel a timer started by mistake, without unlocking. It starts with the timer and ends with it.
struct StudyActivityAttributes: Codable, Hashable {
    struct ContentState: Codable, Hashable {
        /// When the timer started: the elapsed time counts up from it.
        var start: Date
        /// Minutes already studied this week, before this session.
        var weekMinutesBefore: Int
        var weeklyGoalMinutes: Int

        /// The end of what the timer can log (`StudentState.stopTimer` keeps four hours at most).
        var cap: Date { start.addingTimeInterval(StudyLiveActivity.maxSeconds) }
    }

    var courseName: String
    var colorHex: String
}

#if canImport(ActivityKit)
extension StudyActivityAttributes: ActivityAttributes {}
#endif

enum StudyLiveActivity {
    /// Four hours, the most a session logs.
    static let maxSeconds: TimeInterval = 4 * 3600

    /// What the Live Activity shows for this state, or nil when no timer is running.
    static func content(for state: StudentState, now: Date = Date()) -> (StudyActivityAttributes, StudyActivityAttributes.ContentState)? {
        guard let start = state.timerStart else { return nil }
        let course = state.course(state.timerCourseID)
        let attributes = StudyActivityAttributes(
            courseName: course?.name ?? tr("Étude"),
            colorHex: course?.colorHex ?? ScheduleKind.course.colorHex
        )
        let content = StudyActivityAttributes.ContentState(
            start: start,
            weekMinutesBefore: Int(StudentMath.studyMinutes(state, weekOf: now)),
            weeklyGoalMinutes: max(1, Int((state.weeklyStudyGoalHours * 60).rounded()))
        )
        return (attributes, content)
    }

    /// Starts, updates or ends the Live Activity to match the timer. Safe to call often.
    static func sync(_ state: StudentState, now: Date = Date()) async {
        #if canImport(ActivityKit) && os(iOS)
        let running = Activity<StudyActivityAttributes>.activities
        #if DEBUG
        // Captures of the test build (`-screenshotScreen`): no Live Activity, or its Dynamic Island shows on every screenshot.
        if UserDefaults.standard.string(forKey: "screenshotScreen") != nil {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        #endif
        guard let (attributes, content) = Self.content(for: state, now: now) else {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        // After four hours nothing more is logged: the activity is drawn again as stale.
        let activityContent = ActivityContent(state: content, staleDate: content.cap)
        if let current = running.first(where: { $0.attributes == attributes }) {
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

// MARK: - The view (shared: the Lock Screen, and a preview inside the app)

struct StudyActivityView: View {
    let attributes: StudyActivityAttributes
    let state: StudyActivityAttributes.ContentState
    /// False inside the app: buttons don't run and the timer shows a still value.
    var isLive = true
    var now = Date()

    /// The app style chosen in Ardane: the Lock Screen follows its colors and its font.
    private var style: AppStyle { AppStyle.style(SharedStore.shared.settings.appStyle) }
    private var accent: Color { style.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(tr("Temps d'étude"), systemImage: "book.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: attributes.colorHex))
                            .frame(width: 9, height: 9)
                        Text(attributes.courseName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text(tr("\(Fmt.minutes(Double(state.weekMinutesBefore))) sur \(Fmt.minutes(Double(state.weeklyGoalMinutes))) cette semaine"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                elapsedView
            }
            StudyGoalProgress(state: state, isLive: isLive, now: now)
                .tint(accent)
            HStack(spacing: 8) {
                actionButton(tr("Annuler"), symbol: "xmark", prominent: false, intent: CancelStudyIntent())
                    .frame(maxWidth: 120)
                actionButton(tr("Terminer"), symbol: "stop.fill", prominent: true, intent: StopStudyIntent())
            }
        }
        .padding(16)
        .fontDesign(style.fontDesign)
    }

    /// The Lock Screen background: the style's screen color, or its card color at night.
    static var background: Color { WorkoutActivityView.background }

    private var elapsedView: some View {
        Group {
            if isLive {
                Text(timerInterval: state.start...state.cap, countsDown: false)
                    .font(.system(.title, design: .rounded).weight(.semibold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 130, alignment: .trailing)
            } else {
                Text(Duration.seconds(min(StudyLiveActivity.maxSeconds, max(0, now.timeIntervalSince(state.start))))
                    .formatted(.time(pattern: .hourMinuteSecond)))
                    .font(.system(.title, design: .rounded).weight(.semibold).monospacedDigit())
            }
        }
    }

    @ViewBuilder
    private func actionButton<I: AppIntent>(_ title: String, symbol: String, prominent: Bool, intent: I) -> some View {
        let label = Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(prominent ? style.onAccent : accent)
            .padding(.horizontal, 6)
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

/// The week toward its study goal, filling live while the timer runs.
struct StudyGoalProgress: View {
    let state: StudyActivityAttributes.ContentState
    var isLive = true
    var now = Date()

    var body: some View {
        let goal = Double(state.weeklyGoalMinutes) * 60
        let before = Double(state.weekMinutesBefore) * 60
        if isLive, before < goal {
            // The bar starts where the week was when the timer started, and is full at the goal.
            let origin = state.start.addingTimeInterval(-before)
            ProgressView(timerInterval: origin...origin.addingTimeInterval(goal), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        } else {
            let studied = before + (isLive ? 0 : min(StudyLiveActivity.maxSeconds, max(0, now.timeIntervalSince(state.start))))
            ProgressView(value: min(studied, goal), total: max(1, goal))
        }
    }
}
