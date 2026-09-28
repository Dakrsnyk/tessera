import Foundation

enum TravelTiles {
    static let hint = "Ajoute ton voyage dans Tessera, espace Voyage."

    static func make(_ context: RenderContext) -> Tile {
        let data = context.payload.domains
        let now = context.date
        switch context.design.kind {
        case .tripCountdown: return countdown(data.travel, now: now)
        case .flight: return flight(data.travel, context: context)
        case .hotel: return hotel(data.travel, context: context)
        case .destinationWeather: return destinationWeather(data, context: context)
        case .localTime: return localTime(data.travel, context: context)
        case .currency: return currency(data, context: context)
        case .tripProgress: return progress(data.travel, now: now)
        case .nextActivity: return nextActivity(data.travel, context: context)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    static func countdown(_ state: TravelState, now: Date) -> Tile {
        guard let trip = TravelMath.currentTrip(state, at: now) else {
            return .empty("Voyage", symbol: "airplane.departure", message: hint)
        }
        var tile = Tile(title: trip.destination, symbol: "airplane.departure")
        if TravelMath.isOngoing(trip, at: now) {
            let position = TravelMath.tripDay(trip, at: now)
            tile.value = "Jour \(position.day)"
            tile.caption = "sur \(position.total) · bon voyage !"
            tile.visual = .bar(Double(position.day) / Double(position.total))
            tile.gauge = Double(position.day) / Double(position.total)
            tile.shortValue = "J\(position.day)"
            tile.inline = "\(trip.destination) · jour \(position.day)/\(position.total)"
        } else {
            let days = DateMath.daysBetween(now, trip.start)
            tile.value = days == 0 ? "Aujourd'hui" : Fmt.number(days)
            tile.unit = days == 0 ? nil : TF.days(days)
            tile.caption = days == 0 ? "c'est le départ !" : "avant \(trip.destination)"
            tile.detail = "Du \(Fmt.format(trip.start, template: "dMMM")) au \(Fmt.format(trip.end, template: "dMMM"))"
            tile.visual = .ring(max(0.02, 1 - Double(days) / 60))
            tile.gauge = max(0, 1 - Double(days) / 60)
            tile.shortValue = Fmt.number(days)
            tile.inline = "\(trip.destination) dans \(days) j"
        }
        return tile
    }

    static func flight(_ state: TravelState, context: RenderContext) -> Tile {
        let now = context.date
        guard let flight = TravelMath.nextFlight(state, at: now) else {
            return .empty("Vol", symbol: "airplane", message: "Ajoute ton vol dans Tessera, espace Voyage.")
        }
        var tile = Tile(title: "Vol \(flight.number)", symbol: "airplane")
        let seconds = flight.departure.timeIntervalSince(now)
        if seconds > 0 && seconds < 12 * 3600 {
            tile.timer = now...flight.departure
        } else {
            tile.value = TF.time(flight.departure, context)
        }
        tile.caption = "\(flight.from) → \(flight.to) · \(Fmt.shortDay(flight.departure))"
        var parts: [String] = []
        if !flight.terminal.isEmpty { parts.append("Terminal \(flight.terminal)") }
        if !flight.gate.isEmpty { parts.append("Porte \(flight.gate)") }
        if !flight.seat.isEmpty { parts.append("Siège \(flight.seat)") }
        tile.detail = parts.isEmpty ? TF.relativeTime(flight.departure, from: now) : parts.joined(separator: " · ")
        var rows = [TileRow(id: "dep", title: "Départ", value: TF.time(flight.departure, context), detail: flight.from, symbol: "airplane.departure")]
        if let arrival = flight.arrival {
            rows.append(TileRow(id: "arr", title: "Arrivée", value: TF.time(arrival, context), detail: flight.to, symbol: "airplane.arrival"))
        }
        if !flight.gate.isEmpty { rows.append(TileRow(id: "gate", title: "Porte", value: flight.gate, symbol: "door.left.hand.open")) }
        if !flight.seat.isEmpty { rows.append(TileRow(id: "seat", title: "Siège", value: flight.seat, symbol: "carseat.right")) }
        tile.rows = rows
        tile.shortValue = TF.time(flight.departure, context)
        tile.inline = "\(flight.number) · \(TF.time(flight.departure, context))"
        return tile
    }

    static func hotel(_ state: TravelState, context: RenderContext) -> Tile {
        let now = context.date
        guard let stay = TravelMath.currentStay(state, at: now) else {
            return .empty("Hôtel", symbol: "bed.double.fill", message: "Ajoute ton hébergement dans Tessera, espace Voyage.")
        }
        var tile = Tile(title: "Hôtel", symbol: "bed.double.fill")
        tile.value = stay.name
        tile.caption = stay.address.isEmpty ? nil : stay.address
        if stay.checkIn > now {
            tile.detail = "Arrivée \(Fmt.shortDay(stay.checkIn)) à \(TF.time(stay.checkIn, context))"
        } else {
            tile.detail = "Départ \(Fmt.shortDay(stay.checkOut)) à \(TF.time(stay.checkOut, context))"
        }
        var rows = [
            TileRow(id: "in", title: "Arrivée", value: Fmt.shortDay(stay.checkIn), symbol: "key.fill"),
            TileRow(id: "out", title: "Départ", value: Fmt.shortDay(stay.checkOut), symbol: "suitcase.rolling.fill"),
        ]
        if !stay.confirmation.isEmpty {
            rows.append(TileRow(id: "conf", title: "Réservation", value: stay.confirmation, symbol: "number"))
        }
        tile.rows = rows
        tile.inline = stay.name
        return tile
    }

    static func destinationWeather(_ data: DomainData, context: RenderContext) -> Tile {
        let now = context.date
        let unit = context.settings.temperatureUnit
        guard let trip = TravelMath.currentTrip(data.travel, at: now) else {
            return .empty("Météo à destination", symbol: "cloud.sun.rain", message: hint)
        }
        guard let weather = data.tripWeather else {
            let message = trip.location == nil ? "Choisis la ville de destination dans l'espace Voyage." : "La météo s'affiche dès que la connexion est disponible."
            return .empty(trip.destination, symbol: "cloud.sun.rain", message: message)
        }
        var tile = Tile(title: trip.destination, symbol: WeatherCode.symbol(weather.code, isDay: weather.isDay))
        tile.value = Fmt.temperature(weather.temperature, unit: unit)
        tile.caption = WeatherCode.description(weather.code)
        let tripDays = weather.daily.filter { $0.date >= DateMath.startOfDay(trip.start) && $0.date <= trip.end }
        let shown = tripDays.isEmpty ? Array(weather.daily.prefix(5)) : Array(tripDays.prefix(6))
        tile.detail = tripDays.isEmpty ? "Maintenant sur place · prévisions du séjour 7 jours avant" : "Prévisions pendant ton séjour"
        tile.rows = shown.map { day in
            TileRow(id: DateMath.dayKey(day.date), title: Fmt.format(day.date, template: "EEEd").capitalizedFirst, value: "\(Fmt.temperature(day.high, unit: unit)) / \(Fmt.temperature(day.low, unit: unit))", symbol: WeatherCode.symbol(day.code))
        }
        tile.footnote = "Open-Meteo.com"
        tile.inline = "\(trip.destination) \(Fmt.temperature(weather.temperature, unit: unit))"
        return tile
    }

    static func localTime(_ state: TravelState, context: RenderContext) -> Tile {
        let now = context.date
        guard let trip = TravelMath.currentTrip(state, at: now) else {
            return .empty("Heure sur place", symbol: "clock.arrow.2.circlepath", message: hint)
        }
        let zone = trip.timeZone
        let offset = TravelMath.offsetHours(zone, at: now)
        var tile = Tile(title: trip.destination, symbol: "clock.arrow.2.circlepath")
        tile.value = TF.time(now, context, zone: zone)
        let hours = offset.rounded() == offset ? "\(Int(offset))" : TF.decimal(offset, 1)
        tile.caption = offset == 0 ? "même heure qu'ici" : "\(offset > 0 ? "+" : "")\(hours) h par rapport à ici"
        tile.detail = Fmt.format(now, template: "EEEEdMMMM", timeZone: zone).capitalizedFirst
        tile.inline = "\(trip.destination) \(TF.time(now, context, zone: zone))"
        tile.shortValue = TF.time(now, context, zone: zone)
        return tile
    }

    static func currency(_ data: DomainData, context: RenderContext) -> Tile {
        let now = context.date
        let home = context.settings.currencyCode
        let foreign = TravelMath.currentTrip(data.travel, at: now)?.currencyCode ?? (home == "EUR" ? "USD" : "EUR")
        guard foreign != home else {
            return .empty("Devise", symbol: "coloncurrencysign.circle", message: "Ta destination utilise ta devise : rien à convertir.")
        }
        guard let rates = data.fx, rates.base == home, let rate = rates.rates[foreign] else {
            return .empty("Devise", symbol: "coloncurrencysign.circle", message: "Les taux de change s'affichent dès que la connexion est disponible.", emptySymbol: "wifi.slash")
        }
        let amount = data.travel.sampleAmount
        var tile = Tile(title: "\(home) → \(foreign)", symbol: "coloncurrencysign.circle")
        tile.value = Fmt.money(amount * rate, currency: foreign)
        tile.caption = "pour \(Fmt.money(amount, currency: home))"
        tile.rows = [
            TileRow(id: "one", title: "1 \(home)", value: "\(TF.decimal(rate, 4)) \(foreign)", symbol: "arrow.right"),
            TileRow(id: "back", title: "1 \(foreign)", value: "\(TF.decimal(1 / rate, 4)) \(home)", symbol: "arrow.left"),
            TileRow(id: "ten", title: Fmt.money(10, currency: foreign), value: Fmt.money(10 / rate, currency: home), symbol: "equal"),
        ]
        tile.detail = "1 \(home) = \(TF.decimal(rate, 4)) \(foreign)"
        tile.footnote = "Taux de référence BCE du \(rates.day) · Frankfurter"
        tile.inline = "1 \(home) = \(TF.decimal(rate, 3)) \(foreign)"
        return tile
    }

    static func progress(_ state: TravelState, now: Date) -> Tile {
        guard let trip = TravelMath.currentTrip(state, at: now) else {
            return .empty("Voyage", symbol: "map", message: hint)
        }
        var tile = Tile(title: trip.destination, symbol: "map")
        if TravelMath.isOngoing(trip, at: now) {
            let position = TravelMath.tripDay(trip, at: now)
            let left = position.total - position.day
            tile.value = "\(position.day)/\(position.total)"
            tile.unit = "jours"
            tile.caption = left == 0 ? "dernier jour" : "\(left) \(TF.days(left)) restants"
            tile.visual = .ring(Double(position.day) / Double(position.total))
            tile.gauge = Double(position.day) / Double(position.total)
            tile.shortValue = "\(position.day)/\(position.total)"
        } else {
            let days = DateMath.daysBetween(now, trip.start)
            let length = TravelMath.tripDay(trip, at: trip.end).total
            tile.value = Fmt.number(length)
            tile.unit = "jours"
            tile.caption = "de voyage, départ \(TF.relativeDay(trip.start, from: now))"
            tile.visual = .ring(0)
            tile.gauge = 0
            tile.shortValue = "J-\(days)"
        }
        tile.inline = "\(trip.destination) · \(tile.value)"
        return tile
    }

    static func nextActivity(_ state: TravelState, context: RenderContext) -> Tile {
        let now = context.date
        guard let activity = TravelMath.nextActivity(state, at: now) else {
            return .empty("Prochaine activité", symbol: "mappin.and.ellipse", message: "Planifie tes activités dans Tessera, espace Voyage.")
        }
        var tile = Tile(title: "Prochaine activité", symbol: "mappin.and.ellipse")
        tile.value = activity.title
        let zone = TravelMath.currentTrip(state, at: now)?.timeZone ?? .current
        tile.caption = "\(TF.relativeDay(activity.date, from: now).capitalizedFirst) à \(TF.time(activity.date, context, zone: zone))"
        tile.detail = activity.place.isEmpty ? nil : activity.place
        let later = state.activities.filter { $0.date > activity.date }.sorted { $0.date < $1.date }
        tile.rows = later.prefix(4).map { item in
            TileRow(id: item.id.uuidString, title: item.title, value: Fmt.shortDay(item.date), detail: item.place.isEmpty ? nil : item.place, symbol: "mappin")
        }
        tile.inline = "\(activity.title) · \(TF.time(activity.date, context, zone: zone))"
        return tile
    }
}
