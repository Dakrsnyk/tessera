import Foundation

enum BusinessTiles {
    static let hint = tr("Note tes ventes dans Ardane, espace Mon entreprise.")

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let data = context.payload.domains
        let currency = context.settings.currencyCode
        switch context.design.kind {
        case .revenueGoal: return goal(data.business, now: now, currency: currency, knowsGoal: data.knows(.businessGoal), isSmall: context.isSmall, isLarge: context.isLarge)
        case .revenueTrend: return trend(data.business, now: now, currency: currency, isLarge: context.isLarge)
        case .profit: return profit(data.business, now: now, currency: currency, isLarge: context.isLarge)
        case .businessKPIs: return kpis(data.business, now: now, currency: currency, isLarge: context.isLarge)
        case .mrr: return mrr(data.business, currency: currency, isLarge: context.isLarge)
        case .revenueToday: return today(data.business, now: now, currency: currency, isSmall: context.isSmall, isLarge: context.isLarge)
        case .businessDashboard: return dashboard(data.business, now: now, currency: currency, isLarge: context.isLarge)
        case .companySnapshot: return company(data, isLarge: context.isLarge)
        case .companyRevenue: return quarterly(data, isLarge: context.isLarge)
        case .companyStock: return stock(data, clock: PriceClock(now: now, uses24Hour: context.settings.uses24HourClock), isLarge: context.isLarge)
        case .companyCompare: return compare(data, isSmall: context.isSmall, isLarge: context.isLarge)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    // MARK: Business

    /// The day-of-month numbers under a daily chart, oldest first, ending today (the chart thins them out itself).
    static func dayLabels(_ count: Int, until now: Date) -> [String] {
        (0..<count).map { index in
            let day = DateMath.calendar.date(byAdding: .day, value: index - (count - 1), to: now) ?? now
            return Fmt.format(day, template: "d")
        }
    }

    static func goal(_ state: BusinessState, now: Date, currency: String, knowsGoal: Bool = true, isSmall: Bool = false, isLarge: Bool = false) -> Tile {
        let revenue = BusinessMath.revenue(state, .month, at: now)
        guard knowsGoal else {
            var tile = Tile(title: tr("Chiffre du mois"), symbol: "target")
            tile.value = TF.money(revenue, currency)
            tile.caption = tr("ce mois-ci")
            tile.detail = tr("Objectif mensuel à définir dans Ardane")
            tile.shortValue = TF.money(revenue, currency)
            tile.inline = "CA \(TF.money(revenue, currency))"
            return tile
        }
        let goal = max(1, state.monthlyGoal)
        let progress = revenue / goal
        let daysLeft = BudgetMath.daysLeftInMonth(now)
        var tile = Tile(title: tr("Objectif du mois"), symbol: "target")
        tile.value = TF.money(revenue, currency)
        tile.caption = tr("sur \(TF.money(goal, currency)) · \(Fmt.percent(progress))")
        let missing = goal - revenue
        tile.detail = missing > 0 ? tr("\(TF.money(missing / Double(daysLeft), currency)) par jour sur \(daysLeft) \(TF.days(daysLeft))") : tr("Objectif dépassé")
        tile.visual = .ring(progress)
        // What is left to sell (or by how much the goal is beaten) and the days to do it; the daily pace joins on a large widget.
        if !isSmall {
            if missing > 0 {
                tile.rows.append(TileRow(id: "missing", title: tr("Reste à vendre"), value: TF.money(missing, currency), symbol: "flag", isSensitive: true))
                if isLarge { tile.rows.append(TileRow(id: "perday", title: tr("À vendre par jour"), value: TF.money(missing / Double(daysLeft), currency), symbol: "calendar", isSensitive: true)) }
                tile.rows.append(TileRow(id: "days", title: tr("Jours restants"), value: "\(daysLeft)", symbol: "clock"))
            } else {
                tile.rows.append(TileRow(id: "over", title: tr("Au-dessus de l'objectif"), value: "+" + TF.money(-missing, currency), symbol: "checkmark.circle", isSensitive: true))
            }
        }
        tile.gauge = progress
        tile.shortValue = Fmt.percent(progress)
        tile.inline = tr("CA \(TF.money(revenue, currency)) · \(Fmt.percent(progress))")
        return tile
    }

    static func trend(_ state: BusinessState, now: Date, currency: String, isLarge: Bool = false) -> Tile {
        guard !state.sales.isEmpty else { return .empty(tr("Ventes"), symbol: "chart.xyaxis.line", message: hint) }
        let days = BusinessMath.dailyRevenue(state, days: 30, until: now)
        let month = BusinessMath.revenue(state, .month, at: now)
        let week = BusinessMath.revenue(state, .week, at: now)
        var tile = Tile(title: tr("Ventes sur 30 jours"), symbol: "chart.xyaxis.line")
        tile.value = TF.money(days.reduce(0, +), currency)
        var caption = tr("Semaine \(TF.money(week, currency)) · mois \(TF.money(month, currency))")
        if let growth = BusinessMath.growth(state, .month, at: now) {
            caption += " (\(Fmt.signedPercent(growth * 100)))"
            tile.trend = growth >= 0
        }
        tile.caption = caption
        if MoneyTiles.varies(days) { tile.visual = .bars(days, labels: dayLabels(days.count, until: now), highlight: days.count - 1) }
        let year = BusinessMath.revenue(state, .year, at: now)
        tile.detail = tr("Année : \(TF.money(year, currency))")
        if isLarge, let best = days.max(), best > 0, let bestIndex = days.lastIndex(of: best) {
            let bestDay = DateMath.calendar.date(byAdding: .day, value: bestIndex - (days.count - 1), to: now) ?? now
            tile.rows = [
                TileRow(id: "average", title: tr("Moyenne par jour"), value: TF.money(days.reduce(0, +) / Double(days.count), currency), symbol: "chart.bar", isSensitive: true),
                TileRow(id: "best", title: tr("Meilleur jour"), value: TF.money(best, currency), detail: Fmt.format(bestDay, template: "dMMM"), symbol: "star", isSensitive: true),
            ]
        }
        tile.inline = "30 j : \(TF.money(days.reduce(0, +), currency))"
        return tile
    }

    static func profit(_ state: BusinessState, now: Date, currency: String, isLarge: Bool = false) -> Tile {
        let result = BusinessMath.profit(state, month: now)
        var tile = Tile(title: tr("Bénéfice du mois"), symbol: "banknote.fill")
        tile.value = TF.money(result.profit, currency)
        tile.trend = result.profit >= 0
        tile.caption = result.margin.map { tr("marge \(Fmt.percent($0))") } ?? tr("pas encore de ventes ce mois-ci")
        tile.rows = [
            TileRow(id: "rev", title: tr("Chiffre d'affaires"), value: TF.money(result.revenue, currency), symbol: "arrow.down.circle"),
            TileRow(id: "cost", title: tr("Dépenses"), value: TF.money(result.costs, currency), symbol: "arrow.up.circle"),
        ]
        // The margin as a bar: the share of the revenue that stays. Nothing to show without revenue or with a loss.
        if let margin = result.margin, margin > 0 {
            tile.visual = .bar(min(1, margin))
            if isLarge { tile.rows.append(TileRow(id: "margin", title: tr("Marge"), value: Fmt.percent(margin), symbol: "percent")) }
        }
        tile.inline = tr("Bénéfice \(TF.money(result.profit, currency))")
        return tile
    }

    static func kpis(_ state: BusinessState, now: Date, currency: String, isLarge: Bool = false) -> Tile {
        let k = BusinessMath.kpis(state, month: now)
        var tile = Tile(title: tr("Indicateurs du mois"), symbol: "square.grid.2x2")
        tile.value = Fmt.number(k.orders)
        tile.unit = tr("commandes")
        tile.caption = k.averageBasket.map { tr("panier moyen \(TF.money($0, currency, decimals: 2))") } ?? tr("aucune commande ce mois-ci")
        tile.rows = [
            TileRow(id: "orders", title: tr("Commandes"), value: Fmt.number(k.orders), symbol: "bag"),
            TileRow(id: "basket", title: tr("Panier moyen"), value: k.averageBasket.map { TF.money($0, currency) } ?? "—", symbol: "cart"),
            TileRow(id: "customers", title: tr("Nouveaux clients"), value: Fmt.number(k.newCustomers), symbol: "person.badge.plus"),
            TileRow(id: "conversion", title: tr("Conversion"), value: k.conversion.map { Fmt.percent($0, decimals: 1) } ?? "—", symbol: "arrow.triangle.turn.up.right.diamond"),
        ]
        if isLarge {
            let revenue = BusinessMath.revenue(state, .month, at: now)
            tile.rows.insert(TileRow(id: "rev", title: tr("Chiffre d'affaires"), value: TF.money(revenue, currency), symbol: "arrow.down.circle", isSensitive: true), at: 0)
        }
        tile.compactRows = true
        tile.inline = tr("\(k.orders) commandes ce mois-ci")
        return tile
    }

    static func mrr(_ state: BusinessState, currency: String, isLarge: Bool = false) -> Tile {
        guard let recurring = BusinessMath.recurring(state) else {
            return .empty("MRR", symbol: "arrow.triangle.2.circlepath", message: tr("Ajoute ton revenu récurrent mensuel dans Ardane, espace Mon entreprise."))
        }
        var tile = Tile(title: tr("Revenu récurrent"), symbol: "arrow.triangle.2.circlepath")
        tile.value = TF.money(recurring.mrr, currency)
        tile.unit = tr("MRR")
        tile.caption = tr("ARR \(TF.money(recurring.arr, currency)) · \(Fmt.number(recurring.subscribers)) abonnés")
        if let growth = recurring.growth {
            tile.detail = tr("\(Fmt.signedPercent(growth * 100)) sur un mois")
            tile.trend = growth >= 0
        }
        let history = state.subscriptions.sorted { $0.month < $1.month }.suffix(12)
        if history.count >= 2 {
            tile.visual = .bars(history.map(\.mrr), labels: history.map { Fmt.format($0.month, template: "MMM") }, highlight: history.count - 1)
        }
        if isLarge {
            if recurring.subscribers > 0 {
                tile.rows.append(TileRow(id: "arpu", title: tr("Revenu par abonné"), value: TF.money(recurring.mrr / Double(recurring.subscribers), currency, decimals: 2), symbol: "person", isSensitive: true))
            }
            if history.count >= 2, let last = history.last, let previous = history.dropLast().last {
                tile.rows.append(TileRow(id: "change", title: tr("Variation du mois"), value: Fmt.signedMoney(last.mrr - previous.mrr, currency: currency, decimals: 0), symbol: "arrow.up.right", isSensitive: true))
            }
        }
        tile.inline = "MRR \(TF.money(recurring.mrr, currency))"
        return tile
    }

    static func today(_ state: BusinessState, now: Date, currency: String, isSmall: Bool = false, isLarge: Bool = false) -> Tile {
        let values = BusinessMath.todayVersusLastWeek(state, at: now)
        var tile = Tile(title: tr("Ventes du jour"), symbol: "cart")
        tile.value = TF.money(values.today, currency)
        let weekday = Fmt.weekday(now).lowercased()
        tile.caption = tr("contre \(TF.money(values.lastWeek, currency)) \(weekday) dernier, même heure")
        if let change = Stats.change(from: values.lastWeek, to: values.today) {
            tile.detail = Fmt.signedPercent(change * 100)
            tile.trend = change >= 0
        }
        let orders = BusinessMath.sales(state, in: BusinessMath.interval(.day, containing: now)).reduce(0) { $0 + $1.orders }
        tile.rows = [TileRow(id: "orders", title: tr("Commandes"), value: Fmt.number(orders), symbol: "bag")]
        if isLarge, orders > 0 {
            tile.rows.append(TileRow(id: "basket", title: tr("Panier moyen"), value: TF.money(values.today / Double(orders), currency, decimals: 2), symbol: "cart", isSensitive: true))
        }
        // Today against the same time last week, side by side; nothing to compare when both are zero.
        if !isSmall, values.today > 0 || values.lastWeek > 0 {
            tile.visual = .bars([values.lastWeek, values.today], labels: [tr("Sem. dernière"), tr("Aujourd'hui")], highlight: 1)
        }
        tile.inline = tr("Aujourd'hui \(TF.money(values.today, currency))")
        return tile
    }

    static func dashboard(_ state: BusinessState, now: Date, currency: String, isLarge: Bool = false) -> Tile {
        guard !state.sales.isEmpty else { return .empty(state.name, symbol: "rectangle.3.group", message: hint) }
        let month = BusinessMath.revenue(state, .month, at: now)
        let progress = month / max(1, state.monthlyGoal)
        let result = BusinessMath.profit(state, month: now)
        let k = BusinessMath.kpis(state, month: now)
        var tile = Tile(title: state.name, symbol: "rectangle.3.group")
        tile.value = TF.money(month, currency)
        tile.caption = tr("ce mois-ci · \(Fmt.percent(progress)) de l'objectif")
        var rows = [
            TileRow(id: "today", title: tr("Aujourd'hui"), value: TF.money(BusinessMath.revenue(state, .day, at: now), currency), symbol: "sun.max"),
            TileRow(id: "week", title: tr("Cette semaine"), value: TF.money(BusinessMath.revenue(state, .week, at: now), currency), symbol: "calendar"),
            TileRow(id: "profit", title: tr("Bénéfice"), value: TF.money(result.profit, currency), detail: result.margin.map { tr("marge \(Fmt.percent($0))") }, symbol: "banknote"),
            TileRow(id: "orders", title: tr("Commandes"), value: Fmt.number(k.orders), detail: k.averageBasket.map { tr("panier \(TF.money($0, currency))") }, symbol: "bag"),
        ]
        if let recurring = BusinessMath.recurring(state) {
            rows.append(TileRow(id: "mrr", title: tr("MRR"), value: TF.money(recurring.mrr, currency), symbol: "arrow.triangle.2.circlepath"))
        }
        if isLarge {
            rows.append(TileRow(id: "year", title: tr("Cette année"), value: TF.money(BusinessMath.revenue(state, .year, at: now), currency), symbol: "calendar.badge.clock"))
        }
        tile.rows = rows
        let daily = BusinessMath.dailyRevenue(state, days: 14, until: now)
        if MoneyTiles.varies(daily) { tile.visual = .bars(daily, labels: dayLabels(14, until: now), highlight: 13) }
        return tile
    }

    // MARK: Companies (SEC EDGAR)

    static let source = tr("Source : états financiers déposés à la SEC (EDGAR)")
    static let offline = tr("Les chiffres officiels s'affichent dès que la connexion est disponible.")

    static func company(_ data: DomainData, isLarge: Bool = false) -> Tile {
        guard let company = data.companies.first, let revenue = company.latestRevenue else {
            return .empty(tr("Fiche entreprise"), symbol: "building.2", message: offline, emptySymbol: "wifi.slash")
        }
        var tile = Tile(title: company.ref.name, symbol: "building.2")
        tile.value = BigNumber.compact(revenue.value)
        tile.caption = tr("revenus \(revenue.label) · \(company.ref.ticker)")
        var rows: [TileRow] = []
        if let income = company.latestNetIncome {
            rows.append(TileRow(id: "income", title: tr("Bénéfice net"), value: BigNumber.compact(income.value), detail: income.label, symbol: "banknote"))
        }
        if let margin = company.netMargin {
            rows.append(TileRow(id: "margin", title: tr("Marge nette"), value: Fmt.percent(margin, decimals: 1), symbol: "percent"))
        }
        if let growth = company.revenueGrowth {
            rows.append(TileRow(id: "growth", title: tr("Croissance"), value: Fmt.signedPercent(growth * 100), symbol: "arrow.up.right"))
            tile.detail = tr("\(Fmt.signedPercent(growth * 100)) sur un an")
            tile.trend = growth >= 0
        }
        if isLarge, let shares = company.sharesOutstanding {
            rows.append(TileRow(id: "shares", title: tr("Actions en circulation"), value: BigNumber.compact(shares), symbol: "number"))
        }
        tile.rows = rows
        // A single year is one bar: no chart then.
        if company.annualRevenue.count >= 2 {
            tile.visual = .bars(company.annualRevenue.map(\.value), labels: company.annualRevenue.map { String($0.label.suffix(2)) }, highlight: company.annualRevenue.count - 1)
        }
        tile.footnote = source
        tile.inline = "\(company.ref.ticker) \(BigNumber.compact(revenue.value))"
        return tile
    }

    static func quarterly(_ data: DomainData, isLarge: Bool = false) -> Tile {
        guard let company = data.companies.first, let last = company.quarterlyRevenue.last else {
            return .empty(tr("Revenus trimestriels"), symbol: "chart.bar.fill", message: offline, emptySymbol: "wifi.slash")
        }
        let quarters = company.quarterlyRevenue
        var tile = Tile(title: company.ref.name, symbol: "chart.bar.fill")
        tile.value = BigNumber.compact(last.value)
        tile.caption = tr("revenus \(last.label)")
        if quarters.count >= 5 {
            let yearAgo = quarters[quarters.count - 5]
            if let change = Stats.change(from: yearAgo.value, to: last.value) {
                tile.detail = tr("\(Fmt.signedPercent(change * 100)) sur un an (\(yearAgo.label))")
                tile.trend = change >= 0
            }
        }
        // « T1 24 »: the quarter and its year, since a bare « T1 » repeats along the chart.
        let shown = quarters.suffix(isLarge ? 12 : 8)
        if shown.count >= 2 {
            tile.visual = .bars(shown.map(\.value), labels: shown.map { "\($0.label.prefix(2)) \($0.label.suffix(2))" }, highlight: shown.count - 1)
        }
        if isLarge {
            // The latest quarters with their move against the same quarter a year before.
            tile.rows = quarters.indices.reversed().prefix(6).map { index in
                let period = quarters[index]
                let change = index >= 4 ? Stats.change(from: quarters[index - 4].value, to: period.value) : nil
                return TileRow(id: period.label, title: period.label, value: BigNumber.compact(period.value), detail: change.map { Fmt.signedPercent($0 * 100) })
            }
        }
        tile.footnote = source
        return tile
    }

    static func stock(_ data: DomainData, clock: PriceClock = PriceClock(), isLarge: Bool = false) -> Tile {
        guard let company = data.companies.first ?? data.following.followed.first.map({ ref in
            CompanyFinancials(ref: ref, annualRevenue: [], quarterlyRevenue: [], annualNetIncome: [], sharesOutstanding: nil, fetchedAt: Date())
        }) else {
            return .empty(tr("Action"), symbol: "chart.line.uptrend.xyaxis.circle", message: tr("Suis une entreprise dans Ardane, espace Sociétés cotées."))
        }
        var tile = Tile(title: company.ref.name, symbol: "chart.line.uptrend.xyaxis.circle")
        if let quote = data.stocks[company.ref.ticker] {
            tile.value = Fmt.money(quote.price, currency: "USD", decimals: 2)
            // Since the previous close, which is the last session's move while the market is shut.
            tile.caption = "\(company.ref.ticker) · \(PriceChange.text(quote.changePercent, .session))"
            tile.trend = PriceChange.trend(quote.changePercent)
            if let shares = company.sharesOutstanding {
                tile.detail = tr("Capitalisation ≈ \(BigNumber.compact(quote.price * shares))")
            }
            if isLarge {
                if quote.changePercent > -100 {
                    let previous = quote.price / (1 + quote.changePercent / 100)
                    tile.rows.append(TileRow(id: "previous", title: tr("Clôture précédente"), value: Fmt.money(previous, currency: "USD", decimals: 2), symbol: "clock.arrow.circlepath"))
                }
                if let revenue = company.latestRevenue {
                    tile.rows.append(TileRow(id: "revenue", title: tr("Revenus \(revenue.label)"), value: BigNumber.compact(revenue.value), symbol: "chart.bar"))
                }
                if let income = company.latestNetIncome {
                    tile.rows.append(TileRow(id: "income", title: tr("Bénéfice net \(income.label)"), value: BigNumber.compact(income.value), symbol: "banknote"))
                }
            }
            tile.footnote = MoneyTiles.priceNote(quote.priceTime, source: "Finnhub", clock: clock, isLarge: isLarge)
            tile.inline = "\(company.ref.ticker) \(tile.value) \(PriceChange.percent(quote.changePercent))"
        } else {
            tile.value = company.ref.ticker
            tile.caption = tr("Cours non disponible pour le moment")
            tile.detail = company.latestRevenue.map { tr("Revenus \($0.label) : \(BigNumber.compact($0.value))") }
            tile.footnote = source
            tile.inline = "\(company.ref.ticker) \(tile.value)"
        }
        return tile
    }

    static func compare(_ data: DomainData, isSmall: Bool = false, isLarge: Bool = false) -> Tile {
        let companies = data.companies.filter { $0.latestRevenue != nil }
        guard !companies.isEmpty else {
            return .empty(tr("Comparateur"), symbol: "chart.bar.doc.horizontal", message: offline, emptySymbol: "wifi.slash")
        }
        let top = companies.compactMap { $0.latestRevenue?.value }.max() ?? 1
        var tile = Tile(title: tr("Revenus annuels"), symbol: "chart.bar.doc.horizontal")
        tile.value = ""
        tile.caption = companies.map(\.ref.ticker).joined(separator: " · ")
        // One line per company, the biggest first, with its own bar against the biggest; a lone company has nothing to be compared with.
        let compared = companies.count >= 2
        tile.rows = companies.sorted { ($0.latestRevenue?.value ?? 0) > ($1.latestRevenue?.value ?? 0) }.map { company -> TileRow in
            let revenue = company.latestRevenue?.value ?? 0
            var details = [company.revenueGrowth.map { tr("\(Fmt.signedPercent($0 * 100)) sur un an") }]
            if isLarge { details.append(company.netMargin.map { tr("marge \(Fmt.percent($0, decimals: 1))") }) }
            return TileRow(id: company.ref.ticker, title: isSmall ? company.ref.ticker : company.ref.name, value: BigNumber.compact(revenue),
                           detail: details.compactMap { $0 }.joined(separator: " · ").nonEmpty, progress: compared ? revenue / max(1, top) : nil)
        }
        tile.compactRows = true
        if !compared { tile.detail = tr("Suis une autre entreprise pour comparer.") }
        tile.footnote = source
        return tile
    }
}
