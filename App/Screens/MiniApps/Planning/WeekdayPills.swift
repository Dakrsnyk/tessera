import SwiftUI

/// « Répéter » of an event: seven round pills (L M M J V S D), several can be on, with the sentence that
/// says what they mean under them. No pill on = the event happens once.
struct WeekdayPills: View {
    @Binding var days: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(WeekdayRepeat.ordered(), id: \.self) { weekday in
                    let isOn = days.contains(weekday)
                    Button {
                        Haptics.tap()
                        var set = Set(days)
                        if isOn { set.remove(weekday) } else { set.insert(weekday) }
                        days = WeekdayRepeat.normalized(set)
                    } label: {
                        Text(WeekdayRepeat.initial(of: weekday))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(isOn ? Color.accentColor : Color.secondary.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(WeekdayRepeat.name(of: weekday)))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .accessibilityIdentifier("weekday-pills")
            Text(WeekdayRepeat.summary(days))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
