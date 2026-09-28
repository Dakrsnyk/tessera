import Foundation

/// Formatting helpers shared by the app and the widgets. The interface is French,
/// so dates and numbers are always formatted with a French locale.
enum Fmt {
    static let locale = Locale(identifier: "fr_CA")

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        cal.timeZone = .current
        return cal
    }()

    static func format(_ date: Date, template: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func time(_ date: Date, uses24Hour: Bool, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = uses24Hour ? locale : Locale(identifier: "en_US")
        formatter.timeZone = timeZone
        formatter.dateFormat = uses24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    static func meridiem(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = timeZone
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }

    /// "samedi 27 septembre"
    static func longDay(_ date: Date) -> String {
        firstOfMonth(format(date, template: "EEEEdMMMM"), date).capitalizedFirst
    }

    /// "sam. 27 sept."
    static func shortDay(_ date: Date) -> String {
        firstOfMonth(format(date, template: "EEEdMMM"), date).capitalizedFirst
    }

    /// French writes the first day of a month "1er".
    private static func firstOfMonth(_ text: String, _ date: Date) -> String {
        guard DateMath.calendar.component(.day, from: date) == 1 else { return text }
        return text.replacingOccurrences(of: " 1 ", with: " 1er ")
    }

    static func weekday(_ date: Date) -> String {
        format(date, template: "EEEE").capitalizedFirst
    }

    static func month(_ date: Date) -> String {
        format(date, template: "MMMM").capitalizedFirst
    }

    static func monthYear(_ date: Date) -> String {
        format(date, template: "MMMMyyyy").capitalizedFirst
    }

    static func money(_ value: Double, currency: String, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func signedMoney(_ value: Double, currency: String, decimals: Int = 2) -> String {
        let sign = value < 0 ? "−" : "+"
        return sign + money(abs(value), currency: currency, decimals: decimals)
    }

    /// Compact prices for crypto: 64 210 $ / 0,5123 $
    static func price(_ value: Double, currency: String) -> String {
        let decimals: Int
        switch value {
        case 1_000...: decimals = 0
        case 1..<1_000: decimals = 2
        default: decimals = 4
        }
        return money(value, currency: currency, decimals: decimals)
    }

    static func percent(_ fraction: Double, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: fraction)) ?? "\(Int(fraction * 100)) %"
    }

    static func signedPercent(_ value: Double) -> String {
        let sign = value < 0 ? "−" : "+"
        return sign + String(format: "%.1f", abs(value)).replacingOccurrences(of: ".", with: ",") + " %"
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func temperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        "\(Int(unit.convert(celsius).rounded()))°"
    }

    static func plural(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(number(count)) \(abs(count) > 1 ? plural : singular)"
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
