import Foundation

struct WorldCity: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
}

enum WorldCities {
    static let all: [WorldCity] = [
        WorldCity(id: "America/Toronto", name: "Toronto", country: "Canada"),
        WorldCity(id: "America/Montreal", name: "Montréal", country: "Canada"),
        WorldCity(id: "America/Vancouver", name: "Vancouver", country: "Canada"),
        WorldCity(id: "America/Halifax", name: "Halifax", country: "Canada"),
        WorldCity(id: "America/New_York", name: "New York", country: "États-Unis"),
        WorldCity(id: "America/Chicago", name: "Chicago", country: "États-Unis"),
        WorldCity(id: "America/Denver", name: "Denver", country: "États-Unis"),
        WorldCity(id: "America/Los_Angeles", name: "Los Angeles", country: "États-Unis"),
        WorldCity(id: "America/Mexico_City", name: "Mexico", country: "Mexique"),
        WorldCity(id: "America/Sao_Paulo", name: "São Paulo", country: "Brésil"),
        WorldCity(id: "America/Argentina/Buenos_Aires", name: "Buenos Aires", country: "Argentine"),
        WorldCity(id: "Pacific/Honolulu", name: "Honolulu", country: "États-Unis"),
        WorldCity(id: "Europe/London", name: "Londres", country: "Royaume-Uni"),
        WorldCity(id: "Europe/Paris", name: "Paris", country: "France"),
        WorldCity(id: "Europe/Brussels", name: "Bruxelles", country: "Belgique"),
        WorldCity(id: "Europe/Zurich", name: "Zurich", country: "Suisse"),
        WorldCity(id: "Europe/Madrid", name: "Madrid", country: "Espagne"),
        WorldCity(id: "Europe/Lisbon", name: "Lisbonne", country: "Portugal"),
        WorldCity(id: "Europe/Rome", name: "Rome", country: "Italie"),
        WorldCity(id: "Europe/Berlin", name: "Berlin", country: "Allemagne"),
        WorldCity(id: "Europe/Athens", name: "Athènes", country: "Grèce"),
        WorldCity(id: "Europe/Istanbul", name: "Istanbul", country: "Turquie"),
        WorldCity(id: "Europe/Moscow", name: "Moscou", country: "Russie"),
        WorldCity(id: "Africa/Casablanca", name: "Casablanca", country: "Maroc"),
        WorldCity(id: "Africa/Algiers", name: "Alger", country: "Algérie"),
        WorldCity(id: "Africa/Tunis", name: "Tunis", country: "Tunisie"),
        WorldCity(id: "Africa/Dakar", name: "Dakar", country: "Sénégal"),
        WorldCity(id: "Africa/Abidjan", name: "Abidjan", country: "Côte d'Ivoire"),
        WorldCity(id: "Africa/Cairo", name: "Le Caire", country: "Égypte"),
        WorldCity(id: "Africa/Johannesburg", name: "Johannesburg", country: "Afrique du Sud"),
        WorldCity(id: "Asia/Dubai", name: "Dubaï", country: "Émirats arabes unis"),
        WorldCity(id: "Asia/Kolkata", name: "Mumbai", country: "Inde"),
        WorldCity(id: "Asia/Bangkok", name: "Bangkok", country: "Thaïlande"),
        WorldCity(id: "Asia/Singapore", name: "Singapour", country: "Singapour"),
        WorldCity(id: "Asia/Hong_Kong", name: "Hong Kong", country: "Chine"),
        WorldCity(id: "Asia/Shanghai", name: "Shanghai", country: "Chine"),
        WorldCity(id: "Asia/Seoul", name: "Séoul", country: "Corée du Sud"),
        WorldCity(id: "Asia/Tokyo", name: "Tokyo", country: "Japon"),
        WorldCity(id: "Australia/Sydney", name: "Sydney", country: "Australie"),
        WorldCity(id: "Pacific/Auckland", name: "Auckland", country: "Nouvelle-Zélande"),
        WorldCity(id: "Indian/Reunion", name: "La Réunion", country: "France"),
        WorldCity(id: "America/Martinique", name: "Martinique", country: "France"),
    ]

    static func name(for identifier: String) -> String {
        if let city = all.first(where: { $0.id == identifier }) { return city.name }
        return identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }

    /// "+6 h", "−3,5 h", "Même heure"
    static func offsetText(for zone: TimeZone, at date: Date) -> String {
        let delta = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard delta != 0 else { return "Même heure" }
        let hours = Double(delta) / 3600
        let sign = hours < 0 ? "−" : "+"
        let value = abs(hours)
        let text = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        return "\(sign)\(text) h"
    }

    /// "Demain" / "Hier" when the city's calendar day differs from the local one.
    static func dayShift(for zone: TimeZone, at date: Date) -> String? {
        var local = Fmt.calendar
        local.timeZone = .current
        var remote = Fmt.calendar
        remote.timeZone = zone
        let localDay = local.dateComponents([.year, .month, .day], from: date)
        let remoteDay = remote.dateComponents([.year, .month, .day], from: date)
        guard localDay != remoteDay,
              let l = local.date(from: localDay), let r = local.date(from: remoteDay) else { return nil }
        return r > l ? "Demain" : "Hier"
    }

    static func isDaytime(in zone: TimeZone, at date: Date) -> Bool {
        var cal = Fmt.calendar
        cal.timeZone = zone
        let hour = cal.component(.hour, from: date)
        return (7..<19).contains(hour)
    }
}
