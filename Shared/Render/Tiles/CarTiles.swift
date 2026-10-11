import Foundation

enum CarTiles {
    static let hint = tr("Ajoute ta voiture et tes pleins dans Ardane, espace Auto.")

    static func make(_ context: RenderContext) -> Tile {
        let state = context.payload.domains.car
        let now = context.date
        let currency = context.settings.currencyCode
        switch context.design.kind {
        case .carCost: return cost(state, now: now, currency: currency)
        case .nextService: return service(state, now: now)
        case .mileage: return mileage(state, now: now)
        case .fuelStats: return fuel(state, now: now, currency: currency)
        case .carDeadlines: return deadlines(state, now: now)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    static func cost(_ state: CarState, now: Date, currency: String) -> Tile {
        let cost = CarMath.monthlyCost(state, at: now)
        guard cost.total > 0 else { return .empty(tr("Coût de la voiture"), symbol: "car.side", message: hint) }
        var tile = Tile(title: state.name, symbol: "car.side")
        tile.value = TF.money(cost.total, currency)
        tile.unit = "/mois"
        tile.caption = tr("coût estimé, tout compris")
        if let perKm = CarMath.fuelCostPerKm(state) {
            tile.detail = tr("Carburant : \(TF.money(perKm, currency, decimals: 2))/km")
        }
        tile.rows = [
            TileRow(id: "fixed", title: tr("Assurance, prêt, stationnement"), value: TF.money(cost.fixed, currency), symbol: "doc.text", progress: cost.fixed / cost.total),
            TileRow(id: "fuel", title: tr("Carburant"), value: TF.money(cost.fuel, currency), symbol: "fuelpump", progress: cost.fuel / cost.total),
            TileRow(id: "maintenance", title: tr("Entretien"), value: TF.money(cost.maintenance, currency), symbol: "wrench.and.screwdriver", progress: cost.maintenance / cost.total),
        ]
        tile.visual = .segments([
            TileSegment(label: tr("Fixes"), value: cost.fixed, colorHex: "3366FF"),
            TileSegment(label: tr("Carburant"), value: cost.fuel, colorHex: "F2A33A"),
            TileSegment(label: tr("Entretien"), value: cost.maintenance, colorHex: "1E9E75"),
        ])
        tile.inline = tr("Voiture \(TF.money(cost.total, currency))/mois")
        return tile
    }

    static func service(_ state: CarState, now: Date) -> Tile {
        let statuses = CarMath.serviceStatus(state, at: now)
        guard let first = statuses.first else {
            return .empty(tr("Entretien"), symbol: "wrench.and.screwdriver", message: tr("Ajoute tes entretiens (vidange, pneus…) dans Ardane, espace Auto."))
        }
        var tile = Tile(title: first.item.name, symbol: "wrench.and.screwdriver")
        if let km = first.kmLeft {
            tile.value = km >= 0 ? TF.int(km) : tr("En retard")
            tile.unit = km >= 0 ? tr("km") : nil
            tile.trend = km < 0 ? false : nil
        } else if let days = first.daysLeft {
            tile.value = days >= 0 ? Fmt.number(days) : tr("En retard")
            tile.unit = days >= 0 ? TF.days(days) : nil
            tile.trend = days < 0 ? false : nil
        } else {
            tile.value = "—"
        }
        if let days = first.daysLeft, first.kmLeft != nil {
            tile.caption = days >= 0 ? tr("ou \(Fmt.plural(days, tr("jour"), tr("jours")))") : tr("date dépassée")
        } else {
            tile.caption = tr("avant le prochain entretien")
        }
        tile.visual = .bar(min(1, first.used))
        tile.rows = statuses.dropFirst().prefix(4).map { status -> TileRow in
            let left = status.kmLeft.map { tr("\(TF.int($0)) km") } ?? status.daysLeft.map { "\($0) j" } ?? "—"
            return TileRow(id: status.item.id.uuidString, title: status.item.name, value: left, progress: min(1, status.used))
        }
        tile.gauge = min(1, first.used)
        tile.inline = "\(first.item.name) : \(tile.value) \(tile.unit ?? "")"
        return tile
    }

    static func mileage(_ state: CarState, now: Date) -> Tile {
        guard let odometer = CarMath.odometer(state) else { return .empty(tr("Kilométrage"), symbol: "gauge.with.dots.needle.33percent", message: hint) }
        var tile = Tile(title: state.name, symbol: "gauge.with.dots.needle.33percent")
        tile.value = TF.int(odometer)
        tile.unit = tr("km")
        if let month = CarMath.kmThisMonth(state, at: now) {
            tile.caption = tr("\(TF.int(month)) km en \(Fmt.month(now).lowercased())")
        } else {
            tile.caption = tr("au compteur")
        }
        var rows: [TileRow] = []
        if let month = CarMath.kmThisMonth(state, at: now) {
            rows.append(TileRow(id: "month", title: tr("Ce mois-ci"), value: tr("\(TF.int(month)) km"), symbol: "calendar"))
        }
        if let service = CarMath.serviceStatus(state, at: now).first, let left = service.kmLeft {
            rows.append(TileRow(id: "service", title: service.item.name, value: tr("dans \(TF.int(left)) km"), symbol: "wrench.and.screwdriver"))
        }
        if let consumption = CarMath.consumption(state) {
            rows.append(TileRow(id: "fuel", title: tr("Consommation"), value: "\(TF.decimal(consumption, 1)) L/100", symbol: "fuelpump"))
        }
        tile.rows = rows
        tile.inline = tr("\(TF.int(odometer)) km")
        return tile
    }

    static func fuel(_ state: CarState, now: Date, currency: String) -> Tile {
        guard !state.fills.isEmpty else { return .empty(tr("Carburant"), symbol: "fuelpump", message: tr("Note tes pleins dans Ardane, espace Auto.")) }
        var tile = Tile(title: tr("Carburant"), symbol: "fuelpump")
        if let consumption = CarMath.consumption(state) {
            tile.value = TF.decimal(consumption, 1)
            tile.unit = tr("L/100 km")
        } else {
            tile.value = "—"
            tile.unit = tr("L/100 km")
        }
        if let price = CarMath.lastPricePerLiter(state) {
            tile.caption = tr("dernier plein à \(TF.money(price, currency, decimals: 3))/L")
        }
        if let perKm = CarMath.fuelCostPerKm(state) {
            tile.detail = tr("\(TF.money(perKm * 100, currency, decimals: 2)) aux 100 km")
        }
        let month = BudgetMath.monthInterval(now)
        tile.rows = [TileRow(id: "month", title: tr("Ce mois-ci"), value: TF.money(CarMath.fuelSpent(state, in: month), currency), symbol: "calendar")]
        tile.rows += state.fills.sorted { $0.date > $1.date }.prefix(3).map { fill in
            TileRow(id: fill.id.uuidString, title: Fmt.shortDay(fill.date), value: TF.money(fill.total, currency, decimals: 2), detail: "\(TF.decimal(fill.liters, 1)) L", symbol: "fuelpump.fill")
        }
        let summary = "\(tile.value) \(tile.unit ?? "")"
        tile.inline = summary
        return tile
    }

    static func deadlines(_ state: CarState, now: Date) -> Tile {
        let upcoming = CarMath.upcomingDeadlines(state, at: now)
        guard let next = upcoming.first else {
            return .empty(tr("Échéances auto"), symbol: "calendar.badge.exclamationmark", message: tr("Ajoute l'assurance, l'immatriculation ou les pneus dans Ardane, espace Auto."))
        }
        let days = DateMath.daysBetween(now, next.date)
        var tile = Tile(title: tr("Échéances auto"), symbol: "calendar.badge.exclamationmark")
        tile.value = days == 0 ? tr("Aujourd'hui") : Fmt.number(days)
        tile.unit = days == 0 ? nil : TF.days(days)
        tile.caption = next.title
        tile.rows = upcoming.prefix(5).map { item -> TileRow in
            let left = DateMath.daysBetween(now, item.date)
            return TileRow(id: item.id.uuidString, title: item.title, value: "\(left) j", detail: Fmt.firstOfMonth(Fmt.format(item.date, template: "dMMMMyyyy"), item.date), symbol: item.symbol, isHighlighted: left <= 14)
        }
        tile.compactRows = true
        tile.inline = tr("\(next.title) dans \(days) j")
        return tile
    }
}
