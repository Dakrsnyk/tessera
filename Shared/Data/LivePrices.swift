import Foundation

/// How often the widgets that show market prices follow them.
enum LivePrices {
    /// Each timeline asks for a new frame this often. iOS gives a widget about 40 to 70 reloads a day:
    /// asking every 15 minutes uses all it allows, and iOS spaces them out when the budget runs low.
    static let reloadInterval: TimeInterval = 15 * 60

    /// A price read this recently is reused, so widgets reloading together share one request. Shorter
    /// than `reloadInterval`, so every reload reads a new price instead of showing the last one again.
    static let cacheLifetime: TimeInterval = 5 * 60

    /// The kinds whose figures move with market prices.
    static let kinds: Set<WidgetKind> = [.crypto, .portfolio, .allocation, .topMover, .watchlist, .marketOverview, .companyStock]

    static func follows(_ kind: WidgetKind) -> Bool {
        kinds.contains(kind)
    }

    /// True when a price read at `date` can be shown again without asking for a new one. A date
    /// ahead of `now` (the clock was turned back) is never fresh.
    static func isFresh(_ date: Date?, now: Date) -> Bool {
        guard let date else { return false }
        let age = now.timeIntervalSince(date)
        return age >= 0 && age < cacheLifetime
    }

    /// True when a price is older than two reloads: the widget then says when it was read, even small.
    static func isOld(_ date: Date, now: Date) -> Bool {
        now.timeIntervalSince(date) > 2 * reloadInterval
    }

    /// The oldest of several reading times, the one a widget must own up to.
    static func oldest(_ dates: [Date?]) -> Date? {
        dates.compactMap { $0 }.min()
    }
}

/// A price move as every market widget writes it: signed, rounded as shown, with its period
/// (« ▲ +1,45 % · 24 h »). The arrow and the sign carry the direction when iOS removes the colors
/// (Clear and Tinted Home Screens).
enum PriceChange {
    enum Period: Hashable {
        /// Crypto: the last 24 hours, on a market that never closes.
        case day24h
        /// Stocks and ETFs: since the previous close.
        case session

        var label: String {
            switch self {
            case .day24h: tr("24 h")
            // The same word as « 1 jour »: « day », « Tag », « día »… fit both.
            case .session: tr("jour")
            }
        }
    }

    /// The change rounded to the two decimals shown, so the sign and the color never contradict the figure.
    static func rounded(_ percent: Double) -> Double {
        guard percent.isFinite else { return 0 }
        return (percent * 100).rounded() / 100
    }

    /// true = up (green), false = down (red), nil = unchanged once rounded (no color, no arrow).
    static func trend(_ percent: Double) -> Bool? {
        let value = rounded(percent)
        if value > 0 { return true }
        if value < 0 { return false }
        return nil
    }

    /// « +1,45 % », « −0,32 % », « 0,00 % ».
    static func percent(_ percent: Double, locale: Locale = Fmt.locale) -> String {
        let value = rounded(percent)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let digits = formatter.string(from: NSNumber(value: abs(value) / 100)) ?? "\(abs(value)) %"
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return sign + digits
    }

    /// « ▲ » up, « ▼ » down, nothing when unchanged.
    static func arrow(_ percent: Double) -> String {
        switch trend(percent) {
        case .some(true): "▲"
        case .some(false): "▼"
        case .none: ""
        }
    }

    /// « ▲ +1,45 % · 24 h », or with an amount « ▲ +245 $ (+1,20 %) · jour ».
    static func text(_ percent: Double, _ period: Period, amount: String? = nil, arrow showsArrow: Bool = true, locale: Locale = Fmt.locale) -> String {
        let figure = self.percent(percent, locale: locale)
        let core = amount.map { "\($0) (\(figure))" } ?? figure
        let mark = showsArrow ? arrow(percent) : ""
        let move = mark.isEmpty ? core : "\(mark) \(core)"
        return "\(move) · \(period.label)"
    }

    /// The dot of a line in a list: green up, red down, gray unchanged.
    static func colorHex(_ percent: Double) -> String {
        switch trend(percent) {
        case .some(true): "1E9E57"
        case .some(false): "D6364B"
        case .none: "8A94A6"
        }
    }
}

/// When a widget is drawn and how it writes times, to date the prices it shows.
struct PriceClock {
    var now = Date()
    var uses24Hour = true

    /// « 14:05 » today, « ven. 16:00 » earlier this week, « 9 oct. 16:00 » before.
    func time(_ date: Date) -> String {
        let hour = Fmt.time(date, uses24Hour: uses24Hour)
        if DateMath.isSameDay(date, now) { return hour }
        let day = now.timeIntervalSince(date) < 6 * 86_400 ? Fmt.format(date, template: "EEE") : Fmt.format(date, template: "dMMM")
        return "\(day) \(hour)"
    }

    /// « Cours de 14:05 ».
    func asOf(_ date: Date) -> String {
        let written = time(date)
        return tr("Cours de \(written)")
    }
}
