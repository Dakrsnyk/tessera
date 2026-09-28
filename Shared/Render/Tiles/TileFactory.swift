import Foundation
import WidgetKit

/// Builds the tile of every mini-app widget from the payload, at the entry's date.
enum TileFactory {
    static func make(_ context: RenderContext) -> Tile {
        let kind = context.design.kind
        switch kind.category {
        case .time: return TimeTiles.make(context)
        case .weather: return WeatherTiles.make(context)
        case .productivity, .wellbeing: return ProductivityTiles.make(context)
        case .nutrition: return NutritionTiles.make(context)
        case .fitness: return FitnessTiles.make(context)
        case .finance, .investing: return MoneyTiles.make(context)
        case .business, .markets: return BusinessTiles.make(context)
        case .student: return StudentTiles.make(context)
        case .travel: return TravelTiles.make(context)
        case .car: return CarTiles.make(context)
        case .dashboards: return DashboardTiles.make(context)
        }
    }

    static func placeholder(_ kind: WidgetKind) -> Tile {
        Tile(title: kind.title, symbol: kind.symbol)
    }
}

/// Formatting shortcuts shared by the tile builders.
enum TF {
    static func int(_ value: Double) -> String {
        Fmt.number(Int(value.rounded()))
    }

    static func decimal(_ value: Double, _ digits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Fmt.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "1,2" / "0,08" / "150": up to 4 decimals, without trailing zeros.
    static func quantity(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Fmt.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func money(_ value: Double, _ currency: String, decimals: Int = 0) -> String {
        Fmt.money(value, currency: currency, decimals: decimals)
    }

    static func days(_ count: Int) -> String {
        abs(count) > 1 ? "jours" : "jour"
    }

    /// "aujourd'hui", "demain", "dans 3 jours", "hier", "il y a 4 jours"
    static func relativeDay(_ date: Date, from now: Date) -> String {
        let days = DateMath.daysBetween(now, date)
        switch days {
        case 0: return "aujourd'hui"
        case 1: return "demain"
        case -1: return "hier"
        case 2...: return "dans \(days) jours"
        default: return "il y a \(-days) jours"
        }
    }

    /// "Auj." / "Demain" / "3 j" / "En retard", for narrow rows.
    static func shortRelativeDay(_ date: Date, from now: Date) -> String {
        let days = DateMath.daysBetween(now, date)
        switch days {
        case 0: return "Auj."
        case 1: return "Demain"
        case 2...: return "\(days) j"
        default: return "En retard"
        }
    }

    /// "dans 2 h 10" / "dans 12 min" / "dans 3 jours"
    static func relativeTime(_ date: Date, from now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "maintenant" }
        if seconds < 3600 { return "dans \(max(1, Int(seconds / 60))) min" }
        // Non-breaking spaces keep "4 h 18" on one line.
        if seconds < 86_400 { return "dans \(Fmt.hours(seconds / 3600))".replacingOccurrences(of: " ", with: "\u{00A0}") }
        return relativeDay(date, from: now)
    }

    static func time(_ date: Date, _ context: RenderContext, zone: TimeZone = .current) -> String {
        Fmt.time(date, uses24Hour: context.settings.uses24HourClock, timeZone: zone)
    }

    static func weekdayLetters() -> [String] {
        DateMath.weekdaySymbols()
    }

    /// Index of today in a Monday-first week.
    static func todayIndex(_ now: Date) -> Int {
        FitnessMath.isoWeekday(now) - 1
    }

    static func shortName(_ name: String, words: Int = 2) -> String {
        name.split(separator: " ").prefix(words).joined(separator: " ")
    }

    static func weather(_ payload: WidgetPayload) -> WeatherSnapshot? {
        switch payload.weather {
        case let .ready(snapshot): return snapshot
        case let .unavailable(snapshot): return snapshot
        case .needsLocation: return nil
        }
    }

    static func compass(_ degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 45).rounded()) % 8
        return names[index]
    }

    static func uvLevel(_ uv: Double) -> String {
        switch uv {
        case ..<3: return "faible"
        case 3..<6: return "modéré"
        case 6..<8: return "élevé"
        case 8..<11: return "très élevé"
        default: return "extrême"
        }
    }
}
