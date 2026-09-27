import Foundation

/// The data a widget needs besides its design, loaded once per timeline.
struct WidgetPayload: Hashable {
    var settings = AppSettings()
    var content = ContentState()
    var weather: WeatherResult = .needsLocation
    var crypto: CryptoResult = .unavailable(nil)
    var events: EventsResult = .ready([])
}

enum PayloadLoader {
    /// Loads only what the design's kind needs, so a clock widget never touches the network.
    static func load(for design: WidgetDesign, allowNetwork: Bool, now: Date = Date()) async -> WidgetPayload {
        var payload = WidgetPayload()
        let store = SharedStore.shared
        payload.settings = store.settings
        switch design.kind {
        case .tasks, .habits, .focus, .hydration, .moneyFlow:
            payload.content = store.content
        case .weather:
            payload.weather = await WeatherService.load(allowNetwork: allowNetwork, now: now)
        case .crypto:
            payload.crypto = await CryptoService.load(coinID: design.options.coinID, allowNetwork: allowNetwork, now: now)
        case .upNext:
            payload.events = CalendarService.upcoming(from: now)
        case .clock, .calendar, .worldClock, .progress, .countdown, .yearDots, .note:
            break
        }
        return payload
    }
}

/// Example data used only for the system widget gallery and placeholders, never on the Home Screen.
enum SamplePayload {
    static func make(for kind: WidgetKind, now: Date = Date()) -> WidgetPayload {
        var payload = WidgetPayload()
        switch kind {
        case .tasks:
            payload.content.tasks = [
                TaskItem(title: "Appeler le garage"),
                TaskItem(title: "Envoyer la facture"),
                TaskItem(title: "Courir 5 km", isDone: true, completedAt: now),
                TaskItem(title: "Lire 20 pages"),
            ]
        case .habits:
            let week = DateMath.week(containing: now).map(DateMath.dayKey)
            payload.content.habits = [
                Habit(name: "Méditer", symbol: "brain.head.profile", colorHex: "8C6CFF", completedDays: Array(week.prefix(4))),
                Habit(name: "Sport", symbol: "figure.run", colorHex: "FF6B57", completedDays: [week[0], week[2]]),
                Habit(name: "Lecture", symbol: "book.fill", colorHex: "2F8F7A", completedDays: Array(week.prefix(3))),
            ]
        case .hydration:
            payload.content.hydration.add(5, on: now)
        case .focus:
            payload.content.focus = FocusSession(startDate: now, endDate: now.addingTimeInterval(18 * 60), lastDurationMinutes: 25)
        case .moneyFlow:
            payload.content.money = MoneyState(
                items: [
                    MoneyItem(name: "Salaire", amount: 3_600, period: .month, isIncome: true),
                    MoneyItem(name: "Loyer", amount: 1_250, period: .month, isIncome: false),
                    MoneyItem(name: "Épicerie", amount: 110, period: .week, isIncome: false),
                ],
                startDate: DateMath.calendar.date(byAdding: .day, value: -12, to: now) ?? now
            )
        case .weather:
            let hours = (0..<8).map { offset in
                HourForecast(date: now.addingTimeInterval(Double(offset) * 3600), temperature: 17 + Double(offset % 3), code: offset < 4 ? 1 : 3, isDay: true)
            }
            let days = (0..<6).map { offset in
                DayForecast(date: DateMath.calendar.date(byAdding: .day, value: offset, to: now) ?? now, code: [1, 3, 61, 0, 2, 80][offset], high: 19 + Double(offset % 3), low: 9 + Double(offset % 2))
            }
            payload.weather = .ready(WeatherSnapshot(
                locationName: "Montréal", latitude: 45.5, longitude: -73.57, fetchedAt: now,
                temperature: 18, apparentTemperature: 17, code: 1, isDay: true, windSpeed: 12,
                high: 20, low: 10, hourly: hours, daily: days
            ))
        case .crypto:
            let base = 64_000.0
            let line = (0..<56).map { index in base + sin(Double(index) / 5) * 1_400 + Double(index) * 35 }
            payload.crypto = .ready(CoinSnapshot(
                id: "bitcoin", symbol: "BTC", name: "Bitcoin", currency: "USD",
                price: line.last ?? base, change24h: 2.4, sparkline: line, fetchedAt: now
            ))
        case .upNext:
            payload.events = .ready([
                EventSnapshot(id: "1", title: "Réunion d'équipe", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(5_400), isAllDay: false, colorHex: "3366FF"),
                EventSnapshot(id: "2", title: "Dentiste", start: now.addingTimeInterval(4 * 3_600), end: now.addingTimeInterval(5 * 3_600), isAllDay: false, colorHex: "FF6B57"),
                EventSnapshot(id: "3", title: "Dîner avec Léa", start: now.addingTimeInterval(8 * 3_600), end: now.addingTimeInterval(10 * 3_600), isAllDay: false, colorHex: "2F8F7A"),
            ])
        default:
            break
        }
        return payload
    }
}
