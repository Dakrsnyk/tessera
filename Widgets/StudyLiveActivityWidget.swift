import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The study timer on the Lock Screen and in the Dynamic Island (see `StudyLiveActivity`).
struct StudyLiveActivityWidget: Widget {
    /// The app style chosen in Ardane, like the workout's Live Activity.
    private var accent: Color { AppStyle.style(SharedStore.shared.settings).accent }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            StudyActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(StudyActivityView.background)
                .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.courseName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(tr("Temps d'étude"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsed(state, font: .title2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        StudyGoalProgress(state: state)
                            .tint(accent)
                        HStack(spacing: 8) {
                            Button(intent: CancelStudyIntent()) {
                                Label(tr("Annuler"), systemImage: "xmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(accent.opacity(0.4))
                            Button(intent: StopStudyIntent()) {
                                Label(tr("Terminer"), systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(accent)
                        }
                        .font(.subheadline.weight(.bold))
                    }
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .foregroundStyle(accent)
            } compactTrailing: {
                elapsed(state, font: .caption)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "book.fill")
                    .foregroundStyle(accent)
            }
        }
    }

    private func elapsed(_ state: StudyActivityAttributes.ContentState, font: Font) -> some View {
        Text(timerInterval: state.start...state.cap, countsDown: false)
            .font(font.monospacedDigit().weight(.semibold))
            .multilineTextAlignment(.trailing)
    }
}
