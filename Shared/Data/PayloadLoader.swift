import Foundation

/// The data a widget needs besides its design, loaded once per timeline.
struct WidgetPayload: Hashable {
    var settings = AppSettings()
    var content = ContentState()
    var weather: WeatherResult = .needsLocation
    var crypto: CryptoResult = .unavailable(nil)
    var events: EventsResult = .ready([])
    var domains = DomainData()
}

enum PayloadLoader {
    /// Loads only what the design's kind needs, so a clock widget never touches the network.
    static func load(for design: WidgetDesign, allowNetwork: Bool, now: Date = Date()) async -> WidgetPayload {
        var payload = WidgetPayload()
        let store = SharedStore.shared
        payload.settings = store.settings
        // A combined widget loads what each of its widgets needs.
        let needs = design.dataNeeds
        let parts = design.partDesigns
        if needs.contains(.content) {
            payload.content = store.content
        }
        if needs.contains(.weather) {
            payload.weather = await WeatherService.load(allowNetwork: allowNetwork, now: now)
        }
        if needs.contains(.crypto) {
            let coinID = (parts.first { DataNeeds.needs(for: $0.kind).contains(.crypto) } ?? design).options.coinID
            payload.crypto = await CryptoService.load(coinID: coinID, allowNetwork: allowNetwork, now: now)
        }
        if needs.contains(.events) {
            payload.events = CalendarService.upcoming(from: now)
        }
        let companies = parts.first { DataNeeds.needs(for: $0.kind).contains(.companies) } ?? design
        await loadDomains(for: companies, needs: needs, into: &payload, allowNetwork: allowNetwork, now: now)
        return payload
    }
}

/// Example data used only for the system widget gallery and placeholders, never on the Home Screen.
enum SamplePayload {
    /// Example data matching a design (for instance the right coin for a crypto widget).
    static func make(for design: WidgetDesign, now: Date = Date()) -> WidgetPayload {
        guard design.isCombo, let lead = design.partDesigns.first else {
            return make(for: design.kind, coinID: design.options.coinID, now: now)
        }
        // A combined widget: the sample of its first widget, completed with what each other widget shows.
        var payload = make(for: lead.kind, coinID: lead.options.coinID, now: now)
        var hasDomains = !ownSamples.contains(lead.kind)
        for part in design.partDesigns.dropFirst() {
            let other = make(for: part.kind, coinID: part.options.coinID, now: now)
            if case .ready = other.weather { payload.weather = other.weather }
            if case let .ready(events) = other.events, !events.isEmpty { payload.events = other.events }
            if case .ready = other.crypto { payload.crypto = other.crypto }
            if !hasDomains, !ownSamples.contains(part.kind) {
                payload.domains = other.domains
                hasDomains = true
            }
            if payload.content.tasks.isEmpty { payload.content.tasks = other.content.tasks }
            if payload.content.habits.isEmpty { payload.content.habits = other.content.habits }
            if payload.content.hydration == HydrationState() { payload.content.hydration = other.content.hydration }
            if payload.content.focus == FocusSession() { payload.content.focus = other.content.focus }
            if payload.content.money == MoneyState() { payload.content.money = other.content.money }
        }
        return payload
    }

    /// Kinds with a sample of their own below; every other kind gets the full sample data of the spaces.
    private static let ownSamples: Set<WidgetKind> = [.tasks, .habits, .hydration, .focus, .moneyFlow, .weather, .crypto, .upNext]

    static func make(for kind: WidgetKind, coinID: String = "bitcoin", now: Date = Date()) -> WidgetPayload {
        var payload = WidgetPayload()
        switch kind {
        case .tasks:
            payload.content.tasks = [
                TaskItem(title: tr("Appeler le garage")),
                TaskItem(title: tr("Envoyer la facture")),
                TaskItem(title: tr("Courir 5 km"), isDone: true, completedAt: now),
                TaskItem(title: tr("Lire 20 pages")),
            ]
        case .habits:
            // Today and the days before it, never days still ahead.
            let recent = (0..<7).map { offset in
                DateMath.dayKey(DateMath.calendar.date(byAdding: .day, value: -offset, to: now) ?? now)
            }
            payload.content.habits = [
                Habit(name: tr("Méditer"), symbol: "brain.head.profile", colorHex: "8C6CFF", completedDays: Array(recent.prefix(4))),
                Habit(name: tr("Sport"), symbol: "figure.run", colorHex: "FF6B57", completedDays: [recent[0], recent[2]]),
                Habit(name: tr("Lecture"), symbol: "book.fill", colorHex: "2F8F7A", completedDays: Array(recent.prefix(3))),
            ]
        case .hydration:
            payload.content.hydration.add(5, on: now)
        case .focus:
            payload.content.focus = FocusSession(startDate: now, endDate: now.addingTimeInterval(18 * 60), lastDurationMinutes: 25)
        case .moneyFlow:
            payload.content.money = MoneyState(
                items: [
                    MoneyItem(name: tr("Salaire"), amount: 3_600, period: .month, isIncome: true),
                    MoneyItem(name: tr("Loyer"), amount: 1_250, period: .month, isIncome: false),
                    MoneyItem(name: tr("Épicerie"), amount: 110, period: .week, isIncome: false),
                ],
                startDate: DateMath.calendar.date(byAdding: .day, value: -12, to: now) ?? now
            )
        case .weather:
            payload.weather = .ready(SampleData.weather(now: now))
        case .crypto:
            let coin = CryptoService.info(coinID)
            let base: Double = samplePrices[coin.id] ?? 100
            let line: [Double] = (0..<56).map { (index: Int) -> Double in
                let step = Double(index)
                let wave = sin(step / 5) * 0.022
                let drift = step * 0.00055
                return base * (1 + wave + drift)
            }
            payload.crypto = .ready(CoinSnapshot(
                id: coin.id, symbol: coin.symbol, name: coin.name, currency: "USD",
                price: line.last ?? base, change24h: 2.4, sparkline: line, fetchedAt: now
            ))
        case .upNext:
            payload.events = .ready([
                EventSnapshot(id: "1", title: tr("Réunion d'équipe"), start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(5_400), isAllDay: false, colorHex: "3366FF"),
                EventSnapshot(id: "2", title: tr("Dentiste"), start: now.addingTimeInterval(4 * 3_600), end: now.addingTimeInterval(5 * 3_600), isAllDay: false, colorHex: "FF6B57"),
                EventSnapshot(id: "3", title: tr("Dîner avec Léa"), start: now.addingTimeInterval(8 * 3_600), end: now.addingTimeInterval(10 * 3_600), isAllDay: false, colorHex: "2F8F7A"),
            ])
        default:
            SampleData.fill(&payload, for: kind, now: now)
        }
        return payload
    }

    private static let samplePrices: [String: Double] = [
        "bitcoin": 64_000, "ethereum": 3_200, "solana": 150, "ripple": 0.55,
        "cardano": 0.45, "dogecoin": 0.12, "litecoin": 70, "polkadot": 6,
    ]
}
