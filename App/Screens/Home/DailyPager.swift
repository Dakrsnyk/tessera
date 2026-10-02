import SwiftUI

/// A « Mon Quotidien » card with several views: swiping left or right shows the next or previous
/// one, dots under the card show where the person is, and the view chosen stays for the next launch.
/// Taps still open the card (the swipe needs a clearly horizontal movement), the vertical scroll of
/// Home is untouched, and VoiceOver offers « Vue suivante » / « Vue précédente ».
struct DailyPager<Content: View>: View {
    /// The card's key in the settings (`AppSettings.dailyCardPages`).
    let id: String
    let titles: [String]
    let accentHex: String
    @ViewBuilder let content: (Int) -> Content
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var direction: CGFloat = 1
    @State private var drag: CGFloat = 0

    private var count: Int { titles.count }
    private var page: Int { min(max(0, model.settings.dailyCardPages[id] ?? 0), count - 1) }

    var body: some View {
        VStack(spacing: 7) {
            content(page)
                .id(page)
                .transition(transition)
                .offset(x: reduceMotion ? 0 : drag * 0.25)
                .frame(maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .simultaneousGesture(swipe)
            dots
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Vue suivante")) { go(by: 1) }
        .accessibilityAction(named: Text("Vue précédente")) { go(by: -1) }
        .accessibilityIdentifier("daily-pager-\(id)")
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .offset(x: 40 * direction).combined(with: .opacity),
            removal: .offset(x: -40 * direction).combined(with: .opacity)
        )
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color(hex: accentHex) : Color.secondary.opacity(0.3))
                    .frame(width: index == page ? 16 : 6, height: 6)
            }
        }
        .animation(.snappy, value: page)
        .accessibilityElement()
        .accessibilityLabel(Text("Vue \(page + 1) sur \(count) : \(titles[page])"))
        .accessibilityIdentifier("daily-pager-\(id)-dots")
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                // Only a clearly horizontal movement: the vertical scroll of Home keeps working.
                guard abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }
                drag = value.translation.width
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.6
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { drag = 0 }
                guard horizontal, abs(value.translation.width) > 44 else { return }
                go(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func go(by delta: Int) {
        guard count > 1 else { return }
        let next = (page + delta + count) % count
        direction = delta > 0 ? 1 : -1
        Haptics.tap()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.86)) {
            model.updateSettings { $0.dailyCardPages[id] = next }
        }
    }
}

/// Seven bars, one a day (today last), with the goal as a line when there is one.
struct DailyWeekBars: View {
    let values: [Double]
    var goal: Double?
    let colorHex: String
    var height: CGFloat = 56

    var body: some View {
        let top = max(values.max() ?? 0, goal ?? 0, 1)
        let symbols = DateMath.calendar.veryShortWeekdaySymbols
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(hex: colorHex).opacity(index == values.count - 1 ? 1 : 0.45))
                            .frame(height: max(3, height * value / top))
                            .frame(maxWidth: .infinity)
                    }
                }
                if let goal, goal > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(height: 1)
                        .offset(y: -height * goal / top)
                }
            }
            .frame(height: height, alignment: .bottom)
            HStack(spacing: 5) {
                ForEach(0..<values.count, id: \.self) { index in
                    let day = DateMath.calendar.date(byAdding: .day, value: index - (values.count - 1), to: Date()) ?? Date()
                    Text(symbols[DateMath.calendar.component(.weekday, from: day) - 1])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
