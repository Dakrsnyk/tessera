import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The workout in progress on the Lock Screen and in the Dynamic Island (see `WorkoutLiveActivity`).
struct WorkoutLiveActivityWidget: Widget {
    private let accent = Color(hex: "FF6B57")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
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
                        if state.isResting(at: Date()) {
                            Button(intent: SkipRestIntent()) {
                                Label(tr("Passer"), systemImage: "forward.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(accent.opacity(0.4))
                        }
                        Button(intent: CompleteSetIntent()) {
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
