import SwiftUI

/// A « Mon Quotidien » card with several views: swiping left or right shows the next or previous
/// one, dots under the card show where the person is, and the view chosen stays for the next launch.
/// Home stays still: the card never follows the finger nor bounces at its ends; a clearly horizontal
/// swipe changes the view, anything else is a tap on the card or the vertical scroll of Home.
/// VoiceOver offers « Vue suivante » / « Vue précédente ».
struct DailyPager<Content: View>: View {
    /// The card's key in the settings (`AppSettings.dailyCardPages`).
    let id: String
    let titles: [String]
    let accentHex: String
    @ViewBuilder let content: (Int) -> Content
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page on screen.
    @State private var position: Int?
    /// The direction of the last change, for the transition.
    @State private var forward = true

    private var count: Int { titles.count }
    private var saved: Int { min(max(0, model.settings.dailyCardPages[id] ?? 0), count - 1) }
    private var page: Int { position ?? saved }

    var body: some View {
        VStack(spacing: 7) {
            // Every page, invisible, gives the card the height of its tallest view; the page on
            // screen is drawn on top. Only a clearly sideways swipe changes it, so the card never
            // drags Home along nor fights its vertical scroll, and taps on the card still work.
            ZStack(alignment: .top) {
                ForEach(0..<count, id: \.self) { index in
                    content(index)
                }
            }
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .top) {
                content(page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity))
            }
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(swipe)
            .accessibilityIdentifier("daily-pager-\(id)")
            dots
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(tr("Vue suivante"))) { go(by: 1) }
        .accessibilityAction(named: Text(tr("Vue précédente"))) { go(by: -1) }
        .onChange(of: position) { _, new in
            guard let new, new != model.settings.dailyCardPages[id] ?? 0 else { return }
            Haptics.tap()
            model.updateSettings { $0.dailyCardPages[id] = new }
        }
        .onChange(of: model.settings.dailyCardPages[id]) { _, value in
            let target = min(max(0, value ?? 0), count - 1)
            if page != target { position = target }
        }
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
        .accessibilityLabel(Text(tr("Vue \(page + 1) sur \(count) : \(titles[page])")))
        .accessibilityIdentifier("daily-pager-\(id)-dots")
    }

    /// A swipe counts only when it is long and mostly horizontal.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard count > 1, abs(dx) > 50, abs(dx) > abs(dy) * 1.8 else { return }
                go(by: dx < 0 ? 1 : -1)
            }
    }

    private func go(by delta: Int) {
        guard count > 1 else { return }
        let next = (page + delta + count) % count
        forward = delta > 0
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.86)) {
            position = next
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
