import Foundation

struct WorldCity: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
}

enum WorldCities {
    static let all: [WorldCity] = [
        WorldCity(id: "America/Toronto", name: tr("Toronto"), country: tr("Canada")),
        WorldCity(id: "America/Montreal", name: tr("Montréal"), country: tr("Canada")),
        WorldCity(id: "America/Vancouver", name: tr("Vancouver"), country: tr("Canada")),
        WorldCity(id: "America/Halifax", name: tr("Halifax"), country: tr("Canada")),
        WorldCity(id: "America/New_York", name: tr("New York"), country: tr("États-Unis")),
        WorldCity(id: "America/Chicago", name: tr("Chicago"), country: tr("États-Unis")),
        WorldCity(id: "America/Denver", name: tr("Denver"), country: tr("États-Unis")),
        WorldCity(id: "America/Los_Angeles", name: tr("Los Angeles"), country: tr("États-Unis")),
        WorldCity(id: "America/Mexico_City", name: tr("Mexico"), country: tr("Mexique")),
        WorldCity(id: "America/Sao_Paulo", name: tr("São Paulo"), country: tr("Brésil")),
        WorldCity(id: "America/Argentina/Buenos_Aires", name: tr("Buenos Aires"), country: tr("Argentine")),
        WorldCity(id: "Pacific/Honolulu", name: tr("Honolulu"), country: tr("États-Unis")),
        WorldCity(id: "Europe/London", name: tr("Londres"), country: tr("Royaume-Uni")),
        WorldCity(id: "Europe/Paris", name: tr("Paris"), country: tr("France")),
        WorldCity(id: "Europe/Brussels", name: tr("Bruxelles"), country: tr("Belgique")),
        WorldCity(id: "Europe/Zurich", name: tr("Zurich"), country: tr("Suisse")),
        WorldCity(id: "Europe/Madrid", name: tr("Madrid"), country: tr("Espagne")),
        WorldCity(id: "Europe/Lisbon", name: tr("Lisbonne"), country: tr("Portugal")),
        WorldCity(id: "Europe/Rome", name: tr("Rome"), country: tr("Italie")),
        WorldCity(id: "Europe/Berlin", name: tr("Berlin"), country: tr("Allemagne")),
        WorldCity(id: "Europe/Athens", name: tr("Athènes"), country: tr("Grèce")),
        WorldCity(id: "Europe/Istanbul", name: tr("Istanbul"), country: tr("Turquie")),
        WorldCity(id: "Europe/Moscow", name: tr("Moscou"), country: tr("Russie")),
        WorldCity(id: "Africa/Casablanca", name: tr("Casablanca"), country: tr("Maroc")),
        WorldCity(id: "Africa/Algiers", name: tr("Alger"), country: tr("Algérie")),
        WorldCity(id: "Africa/Tunis", name: tr("Tunis"), country: tr("Tunisie")),
        WorldCity(id: "Africa/Dakar", name: tr("Dakar"), country: tr("Sénégal")),
        WorldCity(id: "Africa/Abidjan", name: tr("Abidjan"), country: tr("Côte d'Ivoire")),
        WorldCity(id: "Africa/Cairo", name: tr("Le Caire"), country: tr("Égypte")),
        WorldCity(id: "Africa/Johannesburg", name: tr("Johannesburg"), country: tr("Afrique du Sud")),
        WorldCity(id: "Asia/Dubai", name: tr("Dubaï"), country: tr("Émirats arabes unis")),
        WorldCity(id: "Asia/Kolkata", name: tr("Mumbai"), country: tr("Inde")),
        WorldCity(id: "Asia/Bangkok", name: tr("Bangkok"), country: tr("Thaïlande")),
        WorldCity(id: "Asia/Singapore", name: tr("Singapour"), country: tr("Singapour")),
        WorldCity(id: "Asia/Hong_Kong", name: tr("Hong Kong"), country: tr("Chine")),
        WorldCity(id: "Asia/Shanghai", name: tr("Shanghai"), country: tr("Chine")),
        WorldCity(id: "Asia/Seoul", name: tr("Séoul"), country: tr("Corée du Sud")),
        WorldCity(id: "Asia/Tokyo", name: tr("Tokyo"), country: tr("Japon")),
        WorldCity(id: "Australia/Sydney", name: tr("Sydney"), country: tr("Australie")),
        WorldCity(id: "Pacific/Auckland", name: tr("Auckland"), country: tr("Nouvelle-Zélande")),
        WorldCity(id: "Indian/Reunion", name: tr("La Réunion"), country: tr("France")),
        WorldCity(id: "America/Martinique", name: tr("Martinique"), country: tr("France")),
    ]

    static func name(for identifier: String) -> String {
        if let city = all.first(where: { $0.id == identifier }) { return city.name }
        return identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }

    /// "+6 h", "−3,5 h", "Même heure"
    static func offsetText(for zone: TimeZone, at date: Date) -> String {
        let delta = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard delta != 0 else { return tr("Même heure") }
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
        return r > l ? tr("Demain") : tr("Hier")
    }

    static func isDaytime(in zone: TimeZone, at date: Date) -> Bool {
        var cal = Fmt.calendar
        cal.timeZone = zone
        let hour = cal.component(.hour, from: date)
        return (7..<19).contains(hour)
    }
}
