import SwiftUI

/// A « Mon Quotidien » card with several views: swiping left or right slides to the next or previous
/// one, dots under the card show where the person is, and the view chosen stays for the next launch.
/// The slide follows the finger but stays inside the card (clipped): Home itself never moves
/// sideways. Only a mostly horizontal drag slides the card; taps and the vertical scroll of Home are
/// untouched. VoiceOver offers « Vue suivante » / « Vue précédente ».
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
    /// How far the finger moved the pages (points), while it is down.
    @State private var drag: CGFloat = 0
    /// While a slide settles: -1 or 1 page, in fractions of the card's width (animated).
    @State private var shift: CGFloat = 0
    /// The direction of the drag once it is known: horizontal (the card's) or vertical (Home's).
    @State private var isHorizontal: Bool?
    private let gap: CGFloat = 16

    private var count: Int { titles.count }
    private var saved: Int { min(max(0, model.settings.dailyCardPages[id] ?? 0), count - 1) }
    private var page: Int { position ?? saved }

    var body: some View {
        VStack(spacing: 7) {
            // Every page, invisible, gives the card the height of its tallest view; the page on
            // screen and its neighbours are drawn on top, side by side, moved by the finger. Their
            // places come from the card's own width (visualEffect: no extra layout pass on Home).
            ZStack(alignment: .top) {
                ForEach(0..<count, id: \.self) { index in
                    content(index)
                }
            }
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    ForEach(slots, id: \.index) { slot in
                        let offset = slot.place
                        content(slot.index)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .visualEffect { [drag, shift, gap] view, proxy in
                                view.offset(x: drag + (CGFloat(offset) + shift) * (proxy.size.width + gap))
                            }
                            .allowsHitTesting(offset == 0)
                    }
                }
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

    /// The views drawn: the one on screen (place 0) and the ones it slides to (-1 before, 1 after).
    private var slots: [(index: Int, place: Int)] {
        guard count > 1 else { return [(page, 0)] }
        let next = (page + 1) % count, previous = (page - 1 + count) % count
        if count == 2 { return [(page, 0), (next, drag + shift * 100 > 0 ? -1 : 1)] }
        return [(previous, -1), (page, 0), (next, 1)]
    }

    /// Follows the finger once the drag is clearly horizontal; a vertical one is left to Home.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard count > 1, shift == 0 else { return }
                let dx = value.translation.width, dy = value.translation.height
                if isHorizontal == nil, max(abs(dx), abs(dy)) > 8 {
                    isHorizontal = abs(dx) > abs(dy) * 1.2
                }
                if isHorizontal == true { drag = dx }
            }
            .onEnded { value in
                defer { isHorizontal = nil }
                guard isHorizontal == true, count > 1 else { return }
                let dx = value.translation.width
                let flung = value.predictedEndTranslation.width
                if abs(dx) > 60 || abs(flung) > 160 {
                    go(by: (abs(flung) > abs(dx) ? flung : dx) < 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { drag = 0 }
                }
            }
    }

    /// Slides to the next or previous view from where the finger left it, then makes it the page.
    private func go(by delta: Int) {
        guard count > 1 else { return }
        let next = (page + delta + count) % count
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.88)
        withAnimation(animation) {
            shift = CGFloat(-delta)
            drag = 0
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                position = next
                shift = 0
            }
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
