import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The workout in progress on the Lock Screen and in the Dynamic Island (see `WorkoutLiveActivity`).
struct WorkoutLiveActivityWidget: Widget {
    /// The app style chosen in Ardane, like the rest of the session's screens.
    private var accent: Color { AppStyle.style(SharedStore.shared.settings.appStyle).accent }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WorkoutActivityView.background)
                .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.exercise)
                            .font(.headline)
                            .lineLimit(1)
                        Text(tr("Série \(state.setNumber)/\(state.sets)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    rest(state, font: .title2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        backButton(state)
                        if state.restPaused != nil {
                            Button(intent: ResumeRestIntent()) {
                                Label(tr("Reprendre"), systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(accent.opacity(0.4))
                        } else if state.isResting(at: Date()) {
                            Button(intent: PauseRestIntent()) {
                                Label(tr("Pause"), systemImage: "pause.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(accent.opacity(0.4))
                        }
                        // Passes the set shown (not counted), during the rest or not.
                        Button(intent: SkipSetIntent(expecting: state.position)) {
                            Label(tr("Passer"), systemImage: "forward.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(accent.opacity(0.4))
                        Button(intent: CompleteSetIntent(expecting: state.position)) {
                            Label(tr("Série faite"), systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(accent)
                    }
                    .font(.subheadline.weight(.bold))
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(accent)
            } compactTrailing: {
                rest(state, font: .caption)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: state.isResting(at: Date()) ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(accent)
            }
        }
    }

    /// The small back arrow (or the cross of a session without any set): icon only, so « Série faite » keeps its room.
    @ViewBuilder
    private func backButton(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        let label = Image(systemName: state.backSymbol)
            .frame(width: 22)
            .accessibilityLabel(Text(state.backTitle))
        if state.undoesSet {
            Button(intent: UndoSetIntent(expecting: state.position)) { label }
                .buttonBorderShape(.circle)
                .tint(accent.opacity(0.4))
        } else {
            Button(intent: CancelWorkoutIntent()) { label }
                .buttonBorderShape(.circle)
                .tint(accent.opacity(0.4))
        }
    }

    @ViewBuilder
    private func rest(_ state: WorkoutActivityAttributes.ContentState, font: Font) -> some View {
        if let start = state.restStart, let end = state.restEnd, end > Date() {
            Text(timerInterval: start...end, countsDown: true)
                .font(font.monospacedDigit().weight(.semibold))
                .multilineTextAlignment(.trailing)
        } else {
            Text("\(state.setNumber)/\(state.sets)")
                .font(font.weight(.semibold))
                .foregroundStyle(accent)
        }
    }
}
