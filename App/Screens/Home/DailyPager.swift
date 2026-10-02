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
    /// The page on screen, driven by the paging view.
    @State private var position: Int?

    private var count: Int { titles.count }
    private var saved: Int { min(max(0, model.settings.dailyCardPages[id] ?? 0), count - 1) }
    private var page: Int { position ?? saved }

    private var selection: Binding<Int> {
        Binding(get: { page }, set: { position = $0 })
    }

    var body: some View {
        VStack(spacing: 7) {
            // Every page, invisible, gives the card the height of its tallest view; the paging view
            // on top shows one at a time. A page-style TabView tells a sideways swipe from Home's
            // vertical scroll, and taps on the card's buttons still work.
            ZStack(alignment: .top) {
                ForEach(0..<count, id: \.self) { index in
                    content(index)
                }
            }
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                TabView(selection: selection) {
                    ForEach(0..<count, id: \.self) { index in
                        content(index)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("daily-pager-\(id)")
            }
            dots
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Vue suivante")) { go(by: 1) }
        .accessibilityAction(named: Text("Vue précédente")) { go(by: -1) }
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
        .accessibilityLabel(Text("Vue \(page + 1) sur \(count) : \(titles[page])"))
        .accessibilityIdentifier("daily-pager-\(id)-dots")
    }

    private func go(by delta: Int) {
        guard count > 1 else { return }
        let next = (page + delta + count) % count
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
