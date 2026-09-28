import Foundation

enum BusinessTiles {
    static let hint = "Note tes ventes dans Tessera, espace Mon entreprise."

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let data = context.payload.domains
        let currency = context.settings.currencyCode
        switch context.design.kind {
        case .revenueGoal: return goal(data.business, now: now, currency: currency)
        case .revenueTrend: return trend(data.business, now: now, currency: currency)
        case .profit: return profit(data.business, now: now, currency: currency)
        case .businessKPIs: return kpis(data.business, now: now, currency: currency)
        case .mrr: return mrr(data.business, currency: currency)
        case .revenueToday: return today(data.business, now: now, currency: currency)
        case .businessDashboard: return dashboard(data.business, now: now, currency: currency)
        case .companySnapshot: return company(data)
        case .companyRevenue: return quarterly(data)
        case .companyStock: return stock(data)
        case .companyCompare: return compare(data)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    // MARK: Business

    static func goal(_ state: BusinessState, now: Date, currency: String) -> Tile {
        let revenue = BusinessMath.revenue(state, .month, at: now)
        let goal = max(1, state.monthlyGoal)
        let progress = revenue / goal
        let daysLeft = BudgetMath.daysLeftInMonth(now)
        var tile = Tile(title: "Objectif du mois", symbol: "target")
        tile.value = TF.money(revenue, currency)
        tile.caption = "sur \(TF.money(goal, currency)) · \(Fmt.percent(progress))"
        let missing = goal - revenue
        tile.detail = missing > 0 ? "\(TF.money(missing / Double(daysLeft), currency)) par jour sur \(daysLeft) \(TF.days(daysLeft))" : "Objectif dépassé"
        tile.visual = .ring(progress)
        tile.gauge = progress
        tile.shortValue = Fmt.percent(progress)
        tile.inline = "CA \(TF.money(revenue, currency)) · \(Fmt.percent(progress))"
        return tile
    }

    static func trend(_ state: BusinessState, now: Date, currency: String) -> Tile {
        guard !state.sales.isEmpty else { return .empty("Ventes", symbol: "chart.xyaxis.line", message: hint) }
        let days = BusinessMath.dailyRevenue(state, days: 30, until: now)
        let month = BusinessMath.revenue(state, .month, at: now)
        let week = BusinessMath.revenue(state, .week, at: now)
        var tile = Tile(title: "Ventes sur 30 jours", symbol: "chart.xyaxis.line")
        tile.value = TF.money(days.reduce(0, +), currency)
        var caption = "Semaine \(TF.money(week, currency)) · mois \(TF.money(month, currency))"
        if let growth = BusinessMath.growth(state, .month, at: now) {
            caption += " (\(Fmt.signedPercent(growth * 100)))"
            tile.trend = growth >= 0
        }
        tile.caption = caption
        tile.visual = .bars(days, labels: [], highlight: days.count - 1)
        let year = BusinessMath.revenue(state, .year, at: now)
        tile.detail = "Année : \(TF.money(year, currency))"
        tile.inline = "30 j : \(TF.money(days.reduce(0, +), currency))"
        return tile
    }

    static func profit(_ state: BusinessState, now: Date, currency: String) -> Tile {
        let result = BusinessMath.profit(state, month: now)
        var tile = Tile(title: "Bénéfice du mois", symbol: "banknote.fill")
        tile.value = TF.money(result.profit, currency)
        tile.trend = result.profit >= 0
        tile.caption = result.margin.map { "marge \(Fmt.percent($0))" } ?? "pas encore de ventes ce mois-ci"
        tile.rows = [
            TileRow(id: "rev", title: "Chiffre d'affaires", value: TF.money(result.revenue, currency), symbol: "arrow.down.circle"),
            TileRow(id: "cost", title: "Dépenses", value: TF.money(result.costs, currency), symbol: "arrow.up.circle"),
        ]
        tile.inline = "Bénéfice \(TF.money(result.profit, currency))"
        return tile
    }

    static func kpis(_ state: BusinessState, now: Date, currency: String) -> Tile {
        let k = BusinessMath.kpis(state, month: now)
        var tile = Tile(title: "Indicateurs du mois", symbol: "square.grid.2x2")
        tile.value = Fmt.number(k.orders)
        tile.unit = "commandes"
        tile.caption = k.averageBasket.map { "panier moyen \(TF.money($0, currency, decimals: 2))" } ?? "aucune commande ce mois-ci"
        tile.rows = [
            TileRow(id: "orders", title: "Commandes", value: Fmt.number(k.orders), symbol: "bag"),
            TileRow(id: "basket", title: "Panier moyen", value: k.averageBasket.map { TF.money($0, currency) } ?? "—", symbol: "cart"),
            TileRow(id: "customers", title: "Nouveaux clients", value: Fmt.number(k.newCustomers), symbol: "person.badge.plus"),
            TileRow(id: "conversion", title: "Conversion", value: k.conversion.map { Fmt.percent($0, decimals: 1) } ?? "—", symbol: "arrow.triangle.turn.up.right.diamond"),
        ]
        tile.compactRows = true
        tile.inline = "\(k.orders) commandes ce mois-ci"
        return tile
    }

    static func mrr(_ state: BusinessState, currency: String) -> Tile {
        guard let recurring = BusinessMath.recurring(state) else {
            return .empty("MRR", symbol: "arrow.triangle.2.circlepath", message: "Ajoute ton revenu récurrent mensuel dans Tessera, espace Mon entreprise.")
        }
        var tile = Tile(title: "Revenu récurrent", symbol: "arrow.triangle.2.circlepath")
        tile.value = TF.money(recurring.mrr, currency)
        tile.unit = "MRR"
        tile.caption = "ARR \(TF.money(recurring.arr, currency)) · \(Fmt.number(recurring.subscribers)) abonnés"
        if let growth = recurring.growth {
            tile.detail = "\(Fmt.signedPercent(growth * 100)) sur un mois"
            tile.trend = growth >= 0
        }
        let history = state.subscriptions.sorted { $0.month < $1.month }.suffix(12)
        tile.visual = .bars(history.map(\.mrr), labels: history.map { Fmt.format($0.month, template: "MMM") }, highlight: history.count - 1)
        tile.inline = "MRR \(TF.money(recurring.mrr, currency))"
        return tile
    }

    static func today(_ state: BusinessState, now: Date, currency: String) -> Tile {
        let values = BusinessMath.todayVersusLastWeek(state, at: now)
        var tile = Tile(title: "Ventes du jour", symbol: "cart")
        tile.value = TF.money(values.today, currency)
        let weekday = Fmt.weekday(now).lowercased()
        tile.caption = "contre \(TF.money(values.lastWeek, currency)) \(weekday) dernier, même heure"
        if let change = Stats.change(from: values.lastWeek, to: values.today) {
            tile.detail = Fmt.signedPercent(change * 100)
            tile.trend = change >= 0
        }
        let orders = BusinessMath.sales(state, in: BusinessMath.interval(.day, containing: now)).reduce(0) { $0 + $1.orders }
        tile.rows = [TileRow(id: "orders", title: "Commandes", value: Fmt.number(orders), symbol: "bag")]
        tile.inline = "Aujourd'hui \(TF.money(values.today, currency))"
        return tile
    }

    static func dashboard(_ state: BusinessState, now: Date, currency: String) -> Tile {
        guard !state.sales.isEmpty else { return .empty(state.name, symbol: "rectangle.3.group", message: hint) }
        let month = BusinessMath.revenue(state, .month, at: now)
        let progress = month / max(1, state.monthlyGoal)
        let result = BusinessMath.profit(state, month: now)
        let k = BusinessMath.kpis(state, month: now)
        var tile = Tile(title: state.name, symbol: "rectangle.3.group")
        tile.value = TF.money(month, currency)
        tile.caption = "ce mois-ci · \(Fmt.percent(progress)) de l'objectif"
        var rows = [
            TileRow(id: "today", title: "Aujourd'hui", value: TF.money(BusinessMath.revenue(state, .day, at: now), currency), symbol: "sun.max"),
            TileRow(id: "week", title: "Cette semaine", value: TF.money(BusinessMath.revenue(state, .week, at: now), currency), symbol: "calendar"),
            TileRow(id: "profit", title: "Bénéfice", value: TF.money(result.profit, currency), detail: result.margin.map { "marge \(Fmt.percent($0))" }, symbol: "banknote"),
            TileRow(id: "orders", title: "Commandes", value: Fmt.number(k.orders), detail: k.averageBasket.map { "panier \(TF.money($0, currency))" }, symbol: "bag"),
        ]
        if let recurring = BusinessMath.recurring(state) {
            rows.append(TileRow(id: "mrr", title: "MRR", value: TF.money(recurring.mrr, currency), symbol: "arrow.triangle.2.circlepath"))
        }
        tile.rows = rows
        tile.visual = .bars(BusinessMath.dailyRevenue(state, days: 14, until: now), labels: [], highlight: 13)
        return tile
    }

    // MARK: Companies (SEC EDGAR)

    static let source = "Source : états financiers déposés à la SEC (EDGAR)"
    static let offline = "Les chiffres officiels s'affichent dès que la connexion est disponible."

    static func company(_ data: DomainData) -> Tile {
        guard let company = data.companies.first, let revenue = company.latestRevenue else {
            return .empty("Fiche entreprise", symbol: "building.2", message: offline, emptySymbol: "wifi.slash")
        }
        var tile = Tile(title: company.ref.name, symbol: "building.2")
        tile.value = BigNumber.compact(revenue.value)
        tile.caption = "revenus \(revenue.label) · \(company.ref.ticker)"
        var rows: [TileRow] = []
        if let income = company.latestNetIncome {
            rows.append(TileRow(id: "income", title: "Bénéfice net", value: BigNumber.compact(income.value), detail: income.label, symbol: "banknote"))
        }
        if let margin = company.netMargin {
            rows.append(TileRow(id: "margin", title: "Marge nette", value: Fmt.percent(margin, decimals: 1), symbol: "percent"))
        }
        if let growth = company.revenueGrowth {
            rows.append(TileRow(id: "growth", title: "Croissance", value: Fmt.signedPercent(growth * 100), symbol: "arrow.up.right"))
            tile.detail = "\(Fmt.signedPercent(growth * 100)) sur un an"
            tile.trend = growth >= 0
        }
        tile.rows = rows
        tile.visual = .bars(company.annualRevenue.map(\.value), labels: company.annualRevenue.map { String($0.label.suffix(2)) }, highlight: company.annualRevenue.count - 1)
        tile.footnote = source
        tile.inline = "\(company.ref.ticker) \(BigNumber.compact(revenue.value))"
        return tile
    }

    static func quarterly(_ data: DomainData) -> Tile {
        guard let company = data.companies.first, let last = company.quarterlyRevenue.last else {
            return .empty("Revenus trimestriels", symbol: "chart.bar.fill", message: offline, emptySymbol: "wifi.slash")
        }
        let quarters = company.quarterlyRevenue
        var tile = Tile(title: company.ref.name, symbol: "chart.bar.fill")
        tile.value = BigNumber.compact(last.value)
        tile.caption = "revenus \(last.label)"
        if quarters.count >= 5 {
            let yearAgo = quarters[quarters.count - 5]
            if let change = Stats.change(from: yearAgo.value, to: last.value) {
                tile.detail = "\(Fmt.signedPercent(change * 100)) sur un an (\(yearAgo.label))"
                tile.trend = change >= 0
            }
        }
        tile.visual = .bars(quarters.map(\.value), labels: quarters.map { String($0.label.prefix(2)) }, highlight: quarters.count - 1)
        tile.footnote = source
        return tile
    }

    static func stock(_ data: DomainData) -> Tile {
        guard let company = data.companies.first ?? data.following.followed.first.map({ ref in
            CompanyFinancials(ref: ref, annualRevenue: [], quarterlyRevenue: [], annualNetIncome: [], sharesOutstanding: nil, fetchedAt: Date())
        }) else {
            return .empty("Action", symbol: "chart.line.uptrend.xyaxis.circle", message: "Suis une entreprise dans Tessera, espace Sociétés cotées.")
        }
        var tile = Tile(title: company.ref.name, symbol: "chart.line.uptrend.xyaxis.circle")
        if let quote = data.stocks[company.ref.ticker] {
            tile.value = Fmt.money(quote.price, currency: "USD", decimals: 2)
            tile.caption = "\(company.ref.ticker) · \(Fmt.signedPercent(quote.changePercent)) aujourd'hui"
            tile.trend = quote.changePercent >= 0
            if let shares = company.sharesOutstanding {
                tile.detail = "Capitalisation ≈ \(BigNumber.compact(quote.price * shares))"
            }
            tile.footnote = "Cours : Finnhub · \(MoneyTiles.disclaimer)"
        } else {
            tile.value = company.ref.ticker
            tile.caption = "Cours non disponible pour le moment"
            tile.detail = company.latestRevenue.map { "Revenus \($0.label) : \(BigNumber.compact($0.value))" }
            tile.footnote = source
        }
        tile.inline = "\(company.ref.ticker) \(tile.value)"
        return tile
    }

    static func compare(_ data: DomainData) -> Tile {
        let companies = data.companies.filter { $0.latestRevenue != nil }
        guard !companies.isEmpty else {
            return .empty("Comparateur", symbol: "chart.bar.doc.horizontal", message: offline, emptySymbol: "wifi.slash")
        }
        let top = companies.compactMap { $0.latestRevenue?.value }.max() ?? 1
        var tile = Tile(title: "Revenus annuels", symbol: "chart.bar.doc.horizontal")
        tile.value = ""
        tile.caption = companies.map(\.ref.ticker).joined(separator: " · ")
        tile.rows = companies.map { company -> TileRow in
            let revenue = company.latestRevenue?.value ?? 0
            let growth = company.revenueGrowth.map { "\(Fmt.signedPercent($0 * 100)) sur un an" }
            return TileRow(id: company.ref.ticker, title: company.ref.name, value: BigNumber.compact(revenue), detail: growth, progress: revenue / max(1, top))
        }
        tile.footnote = source
        return tile
    }
}
