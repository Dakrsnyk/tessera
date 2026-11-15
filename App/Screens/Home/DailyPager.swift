import SwiftUI

/// Where a card is among the views of its pager: its header draws the dots from it (`DailyPagerDots`).
struct DailyPagerInfo: Equatable {
    let count: Int
    let page: Int
}

private struct DailyPagerInfoKey: EnvironmentKey {
    static let defaultValue: DailyPagerInfo? = nil
}

extension EnvironmentValues {
    /// The pager the card is a view of (nil outside a pager).
    var dailyPager: DailyPagerInfo? {
        get { self[DailyPagerInfoKey.self] }
        set { self[DailyPagerInfoKey.self] = newValue }
    }
}

/// The dots of a pager, at the right of the title in the card's header (the design): the view on screen is the long one,
/// in the action color. Only drawn: VoiceOver and the UI tests read the pager's own `daily-pager-*-dots` element.
struct DailyPagerDots: View {
    let info: DailyPagerInfo
    @Environment(\.appStyle) private var style

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<info.count, id: \.self) { index in
                Capsule()
                    .fill(index == info.page ? Color.accentColor : CristalPalette.of(style.id).dotColor)
                    .frame(width: index == info.page ? 14 : 5, height: 5)
            }
        }
        .animation(.snappy, value: info.page)
        .accessibilityHidden(true)
    }
}

/// A « Mon Quotidien » card with several views: swiping left or right slides to the next or previous
/// one, dots in the card's header show where the person is, and the view chosen stays for the next launch.
/// A native paging scroll the size of the card: the slide follows the finger and stays inside the
/// card, Home itself never moves sideways, taps and the vertical scroll of Home are untouched.
/// VoiceOver offers « Vue suivante » / « Vue précédente ».
struct DailyPager<Content: View>: View {
    /// The card's key in the settings (`AppSettings.dailyCardPages`).
    let id: String
    let titles: [String]
    @ViewBuilder let content: (Int) -> Content
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dailyEditing) private var editing
    @Environment(\.appStyle) private var style
    /// The page on screen, driven by the paging scroll.
    @State private var position: Int?

    private var count: Int { titles.count }
    private var saved: Int { min(max(0, model.settings.dailyCardPages[id] ?? 0), count - 1) }
    private var page: Int { position ?? saved }

    /// A view of the card, told where it is among the views (its header draws the dots).
    private func shown(_ index: Int) -> some View {
        content(index).environment(\.dailyPager, DailyPagerInfo(count: count, page: page))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Every page, invisible, gives the card the height of its tallest view; the paging
            // scroll on top, exactly the card's size, shows one page at a time.
            ZStack(alignment: .top) {
                ForEach(0..<count, id: \.self) { index in
                    shown(index)
                }
            }
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .top) {
                if editing {
                    // « Organiser… »: the card is moved, never swiped, so its view stays still and fills the card. The
                    // paging scroll of the card held for the menu stopped 40 points between two views (Builds 365 to 367).
                    shown(page)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(0..<count, id: \.self) { index in
                                shown(index)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .containerRelativeFrame(.horizontal)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    // A view chosen by the app (the one kept, VoiceOver) starts at the card's left edge, never half way.
                    .scrollPosition(id: $position, anchor: .leading)
                    .scrollDisabled(count < 2)
                    .accessibilityIdentifier("daily-pager-\(id)")
                }
            }
        }
        // One element for the dots drawn in the header: VoiceOver reads « Vue 1 sur 3 », the tests find it by its identifier.
        .overlay(alignment: .top) { dotsElement }
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
        // The view chosen last time, once the paging scroll is laid out.
        .onAppear { if position == nil { position = saved } }
    }

    private var dotsElement: some View {
        Color.clear
            .frame(height: 2)
            .accessibilityElement()
            .accessibilityLabel(Text(tr("Vue \(page + 1) sur \(count) : \(titles[page])")))
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
    @Environment(\.appStyle) private var style

    var body: some View {
        let top = max(values.max() ?? 0, goal ?? 0, 1)
        let symbols = DateMath.calendar.veryShortWeekdaySymbols
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(CristalPalette.of(style.id).category(colorHex).opacity(index == values.count - 1 ? 1 : 0.45))
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
