import Foundation

enum MoneyTiles {
    static let disclaimer = tr("À titre informatif, pas un conseil financier.")

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let data = context.payload.domains
        let currency = context.settings.currencyCode
        let target = context.options.targetID
        let clock = PriceClock(now: now, uses24Hour: context.settings.uses24HourClock)
        switch context.design.kind {
        case .budgetLeft: return budgetLeft(data.budget, now: now, currency: currency, knowsBudget: data.knows(.monthlyBudget))
        case .spendingByCategory: return byCategory(data.budget, now: now, currency: currency)
        case .billsUpcoming: return bills(data.budget, now: now, currency: currency)
        case .savingsGoal: return savings(data.budget, target: target, now: now, currency: currency)
        case .netWorth: return netWorth(data.budget, now: now, currency: currency)
        case .subscriptions: return subscriptions(data.budget, currency: currency)
        case .quickExpense: return quickExpense(data.budget, now: now, currency: currency)
        case .portfolio: return portfolio(data, currency: currency, clock: clock, isLarge: context.isLarge)
        case .allocation: return allocation(data, currency: currency)
        case .topMover: return topMover(data, currency: currency, clock: clock, isLarge: context.isLarge)
        case .watchlist: return watchlist(data, currency: context.settings.cryptoCurrency.uppercased(), clock: clock, isSmall: context.isSmall)
        case .marketOverview: return market(data, currency: context.settings.cryptoCurrency.uppercased(), clock: clock, isLarge: context.isLarge)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    // MARK: Budget

    static func budgetLeft(_ state: BudgetState, now: Date, currency: String, knowsBudget: Bool = true) -> Tile {
        let spent = BudgetMath.spentThisMonth(state, at: now)
        guard knowsBudget else {
            // No budget given: what was spent, never a remainder of a made-up budget.
            var tile = Tile(title: tr("Dépenses du mois"), symbol: "creditcard")
            tile.value = TF.money(spent, currency)
            tile.caption = tr("dépensés ce mois-ci")
            tile.detail = tr("Budget mensuel à définir dans Ardane")
            tile.rows = BudgetMath.byCategory(state, in: BudgetMath.monthInterval(now), now: now).prefix(4).map { item in
                TileRow(id: item.name, title: item.name, value: TF.money(item.amount, currency), colorHex: item.colorHex)
            }
            tile.shortValue = TF.money(spent, currency)
            tile.inline = tr("Dépensé \(TF.money(spent, currency))")
            return tile
        }
        let remaining = BudgetMath.remaining(state, at: now)
        let budget = max(1, state.monthlyBudget)
        var tile = Tile(title: tr("Reste du mois"), symbol: "creditcard")
        tile.value = TF.money(remaining, currency)
        tile.trend = remaining < 0 ? false : nil
        tile.caption = remaining >= 0 ? tr("soit \(TF.money(BudgetMath.perDayLeft(state, at: now), currency)) par jour") : tr("au-dessus du budget")
        tile.detail = tr("Dépensé : \(TF.money(spent, currency)) sur \(TF.money(budget, currency))")
        tile.visual = .bar(spent / budget)
        tile.rows = BudgetMath.byCategory(state, in: BudgetMath.monthInterval(now), now: now).prefix(4).map { item in
            TileRow(id: item.name, title: item.name, value: TF.money(item.amount, currency), colorHex: item.colorHex)
        }
        tile.gauge = max(0, 1 - spent / budget)
        tile.shortValue = TF.money(remaining, currency)
        tile.inline = tr("Reste \(TF.money(remaining, currency))")
        return tile
    }

    static func byCategory(_ state: BudgetState, now: Date, currency: String) -> Tile {
        let items = BudgetMath.byCategory(state, in: BudgetMath.monthInterval(now), now: now)
        guard !items.isEmpty else { return .empty(tr("Dépenses"), symbol: "chart.bar.doc.horizontal", message: tr("Note tes dépenses dans Ardane, espace Budget.")) }
        let total = items.reduce(0) { $0 + $1.amount }
        var tile = Tile(title: tr("Dépenses du mois"), symbol: "chart.bar.doc.horizontal")
        tile.value = TF.money(total, currency)
        tile.caption = tr("\(Fmt.month(now)) · \(items.count) catégories")
        tile.detail = monthComparison(state, now: now, currency: currency)
        tile.visual = .segments(items.prefix(6).map { TileSegment(label: $0.name, value: $0.amount, colorHex: $0.colorHex) })
        tile.rows = items.prefix(6).map { item -> TileRow in
            let limit = item.category?.monthlyLimit ?? 0
            return TileRow(
                id: item.name, title: item.name,
                value: TF.money(item.amount, currency),
                detail: limit > 0 ? tr("sur \(TF.money(limit, currency))") : nil,
                colorHex: item.colorHex,
                progress: limit > 0 ? item.amount / limit : nil
            )
        }
        tile.inline = tr("\(TF.money(total, currency)) ce mois-ci")
        return tile
    }

    static func bills(_ state: BudgetState, now: Date, currency: String) -> Tile {
        let upcoming = BudgetMath.upcomingBills(state, at: now, within: 31)
        guard let next = upcoming.first else { return .empty(tr("Factures"), symbol: "doc.text", message: tr("Ajoute tes factures dans Ardane, espace Budget.")) }
        let total = upcoming.reduce(0) { $0 + $1.bill.amount }
        var tile = Tile(title: tr("Factures à venir"), symbol: "doc.text")
        tile.value = TF.money(next.bill.amount, currency, decimals: 2)
        tile.caption = "\(next.bill.name) · \(TF.relativeDay(next.due, from: now))"
        tile.detail = tr("30 prochains jours : \(TF.money(total, currency))")
        tile.rows = upcoming.prefix(6).map { item in
            TileRow(id: item.bill.id.uuidString, title: item.bill.name, value: TF.money(item.bill.amount, currency, decimals: 2), detail: item.days <= 7 ? TF.relativeDay(item.due, from: now).capitalizedFirst : Fmt.shortDay(item.due), symbol: item.bill.symbol, isHighlighted: item.days <= 2)
        }
        tile.compactRows = true
        tile.inline = "\(next.bill.name) \(TF.relativeDay(next.due, from: now))"
        return tile
    }

    static func savings(_ state: BudgetState, target: String?, now: Date, currency: String) -> Tile {
        guard let goal = state.goals.first(where: { $0.id.uuidString == target }) ?? state.goals.first else {
            return .empty(tr("Épargne"), symbol: "banknote", message: tr("Crée un objectif d'épargne dans Ardane, espace Budget."))
        }
        var tile = Tile(title: goal.name, symbol: "banknote")
        tile.value = Fmt.percent(goal.progress)
        tile.caption = tr("\(TF.money(goal.saved, currency)) sur \(TF.money(goal.target, currency))")
        let left = max(0, goal.target - goal.saved)
        if let deadline = goal.deadline, left > 0 {
            let months = max(1, DateMath.calendar.dateComponents([.month], from: now, to: deadline).month ?? 1)
            tile.detail = tr("\(TF.money(left / Double(months), currency)) par mois jusqu'au \(Fmt.format(deadline, template: "dMMMMyyyy"))")
        } else {
            tile.detail = left == 0 ? tr("Objectif atteint") : tr("Reste \(TF.money(left, currency))")
        }
        tile.visual = .ring(goal.progress)
        tile.rows = state.goals.prefix(4).map { item in
            TileRow(id: item.id.uuidString, title: item.name, value: Fmt.percent(item.progress), progress: item.progress)
        }
        tile.gauge = goal.progress
        tile.shortValue = Fmt.percent(goal.progress)
        tile.inline = "\(goal.name) · \(Fmt.percent(goal.progress))"
        return tile
    }

    static func netWorth(_ state: BudgetState, now: Date, currency: String) -> Tile {
        guard !state.accounts.isEmpty else { return .empty(tr("Valeur nette"), symbol: "building.columns", message: tr("Ajoute tes comptes et tes dettes dans Ardane, espace Budget.")) }
        let worth = BudgetMath.netWorth(state)
        var tile = Tile(title: tr("Valeur nette"), symbol: "building.columns")
        tile.value = TF.money(worth, currency)
        let history = state.netWorthHistory.map(\.value)
        if let evolution = netWorthEvolution(state, worth: worth, now: now, currency: currency) {
            tile.caption = evolution.text
            tile.trend = evolution.trend
        } else {
            tile.caption = tr("actifs moins dettes")
        }
        let assets = state.accounts.filter { !$0.isLiability }.reduce(0) { $0 + $1.balance }
        let debts = state.accounts.filter(\.isLiability).reduce(0) { $0 + $1.balance }
        tile.detail = tr("Actifs \(TF.money(assets, currency)) · Dettes \(TF.money(debts, currency))")
        if history.count >= 2 { tile.visual = .line(Array(history.suffix(60))) }
        tile.inline = tr("Valeur nette \(TF.money(worth, currency))")
        return tile
    }

    /// The month's spending against last month's up to the same day (« 45 $ de plus que le mois dernier
    /// à la même date »). Only when expenses were already noted when last month began: a month noted
    /// from its middle on, or holding only the bills, would make the comparison lie.
    static func monthComparison(_ state: BudgetState, now: Date, currency: String) -> String? {
        let monthStart = BudgetMath.monthInterval(now).start
        guard let lastMonth = DateMath.calendar.date(byAdding: .month, value: -1, to: monthStart),
              let firstDayEnd = DateMath.calendar.date(byAdding: .day, value: 1, to: lastMonth),
              state.expenses.contains(where: { $0.date < firstDayEnd }) else { return nil }
        let comparison = BudgetMath.monthToDate(state, at: now)
        let difference = comparison.current - comparison.previous
        guard comparison.previous > 0, abs(difference) >= 1 else { return nil }
        let amount = TF.money(abs(difference), currency)
        return difference > 0 ? tr("\(amount) de plus que le mois dernier à la même date") : tr("\(amount) de moins que le mois dernier à la même date")
    }

    /// The net worth's move since the oldest value of the last 31 days. « sur 30 jours » only when the
    /// history goes back that far; a younger history gives its first day; nothing before a day has passed.
    static func netWorthEvolution(_ state: BudgetState, worth: Double, now: Date, currency: String) -> (text: String, trend: Bool?)? {
        guard let first = state.netWorthHistory.first(where: { now.timeIntervalSince($0.date) <= 31 * 86_400 }),
              !DateMath.isSameDay(first.date, now), first.date < now else { return nil }
        let change = worth - first.value
        let amount = Fmt.signedMoney(change, currency: currency, decimals: 0)
        let trend: Bool? = abs(change) < 0.5 ? nil : change > 0
        if now.timeIntervalSince(first.date) >= 27 * 86_400 {
            return (tr("\(amount) sur 30 jours"), trend)
        }
        let day = Fmt.format(first.date, template: "dMMM")
        let since = tr("Depuis le \(day)")
        return ("\(since) · \(amount)", trend)
    }

    static func subscriptions(_ state: BudgetState, currency: String) -> Tile {
        let subs = state.bills.filter(\.isSubscription)
        guard !subs.isEmpty else { return .empty(tr("Abonnements"), symbol: "repeat.circle", message: tr("Ajoute tes abonnements dans Ardane, espace Budget.")) }
        let monthly = BudgetMath.subscriptionsMonthly(state)
        var tile = Tile(title: tr("Abonnements"), symbol: "repeat.circle")
        tile.value = TF.money(monthly, currency, decimals: 2)
        tile.unit = "/mois"
        tile.caption = tr("\(Fmt.plural(subs.count, tr("abonnement"), tr("abonnements"))) · \(TF.money(monthly * 12, currency))/an")
        tile.rows = subs.sorted { $0.monthlyCost > $1.monthlyCost }.prefix(6).map { bill in
            TileRow(id: bill.id.uuidString, title: bill.name, value: TF.money(bill.monthlyCost, currency, decimals: 2), symbol: bill.symbol)
        }
        tile.inline = tr("Abonnements \(TF.money(monthly, currency))/mois")
        return tile
    }

    static func quickExpense(_ state: BudgetState, now: Date, currency: String) -> Tile {
        let today = BudgetMath.spentToday(state, at: now)
        guard !state.quickExpenses.isEmpty else {
            return .empty(tr("Dépense rapide"), symbol: "cart.badge.plus", message: tr("Crée tes dépenses habituelles (café, bus…) dans Ardane, espace Budget."))
        }
        var tile = Tile(title: tr("Dépense rapide"), symbol: "cart.badge.plus")
        tile.value = TF.money(today, currency, decimals: 2)
        tile.caption = tr("dépensé aujourd'hui")
        tile.buttons = state.quickExpenses.prefix(3).map { quick in
            TileButton(title: quick.name, symbol: quick.symbol, action: .quickExpense(quick.id.uuidString))
        }
        tile.rows = state.quickExpenses.prefix(4).map { quick in
            TileRow(id: quick.id.uuidString, title: quick.name, value: TF.money(quick.amount, currency, decimals: 2), symbol: "plus.circle.fill", action: .quickExpense(quick.id.uuidString))
        }
        tile.detail = tr("Reste du mois : \(TF.money(BudgetMath.remaining(state, at: now), currency))")
        return tile
    }

    // MARK: Investing

    /// The small print of a widget showing prices: when they were read (« Cours de 14:05 ») and where
    /// from, then the disclaimer where there is room for it (a medium widget keeps two short lines).
    static func priceNote(_ date: Date?, source: String? = nil, clock: PriceClock, isLarge: Bool) -> String {
        var parts = [date.map(clock.asOf), source].compactMap { $0 }
        if isLarge || date == nil { parts.append(disclaimer) }
        return parts.joined(separator: " · ")
    }

    static func portfolio(_ data: DomainData, currency: String, clock: PriceClock = PriceClock(), isLarge: Bool = true) -> Tile {
        let positions = PortfolioMath.positions(data.portfolio, prices: data.prices)
        guard !positions.isEmpty else { return .empty(tr("Portefeuille"), symbol: "chart.line.uptrend.xyaxis", message: tr("Ajoute tes placements dans Ardane, espace Placements.")) }
        let summary = PortfolioMath.summary(positions)
        var tile = Tile(title: tr("Portefeuille"), symbol: "chart.line.uptrend.xyaxis")
        tile.value = TF.money(summary.value, currency)
        let percent = summary.gainPercent.map { " (\(Fmt.signedPercent($0 * 100)))" } ?? ""
        let total = tr("\(Fmt.signedMoney(summary.gain, currency: currency, decimals: 0))\(percent) au total")
        if let dayPercent = summary.dayChangePercent {
            // The day's move first, as the prices go; the total gain below it.
            let amount = Fmt.signedMoney(summary.dayChange, currency: currency, decimals: 0)
            tile.caption = PriceChange.text(dayPercent, PortfolioMath.period(positions), amount: amount)
            tile.detail = total
            tile.trend = PriceChange.trend(dayPercent)
        } else {
            tile.caption = total
            tile.trend = summary.gain >= 0
        }
        let history = data.portfolio.history.map(\.value)
        if history.count >= 2 { tile.visual = .line(Array(history.suffix(60))) }
        tile.rows = positions.sorted { $0.value > $1.value }.prefix(5).map { position in
            TileRow(
                id: position.holding.id.uuidString,
                title: position.holding.name,
                value: TF.money(position.value, currency),
                detail: position.change24h.map { PriceChange.text($0, position.period, arrow: false) },
                colorHex: position.holding.kind.colorHex
            )
        }
        tile.footnote = priceNote(data.prices.fetchedAt, clock: clock, isLarge: isLarge)
        tile.inline = tr("Portefeuille \(TF.money(summary.value, currency))")
        return tile
    }

    static func allocation(_ data: DomainData, currency: String) -> Tile {
        let positions = PortfolioMath.positions(data.portfolio, prices: data.prices)
        let parts = PortfolioMath.allocation(positions)
        let total = parts.reduce(0) { $0 + $1.value }
        guard let largest = parts.max(by: { $0.value < $1.value }), total > 0 else {
            return .empty(tr("Répartition"), symbol: "chart.pie", message: tr("Ajoute tes placements dans Ardane, espace Placements."))
        }
        var tile = Tile(title: tr("Répartition"), symbol: "chart.pie")
        tile.value = Fmt.percent(largest.value / total)
        tile.caption = tr("en \(largest.kind.title.lowercased()) · total \(TF.money(total, currency))")
        tile.visual = .segments(parts.map { TileSegment(label: $0.kind.title, value: $0.value, colorHex: $0.kind.colorHex) })
        tile.footnote = disclaimer
        return tile
    }

    static func topMover(_ data: DomainData, currency: String, clock: PriceClock = PriceClock(), isLarge: Bool = true) -> Tile {
        let positions = PortfolioMath.positions(data.portfolio, prices: data.prices)
        guard let mover = PortfolioMath.topMover(positions), let change = mover.change24h else {
            return .empty(tr("Plus forte variation"), symbol: "arrow.up.arrow.down", message: tr("Les variations apparaissent pour les placements cotés en direct."))
        }
        let trend = PriceChange.trend(change)
        var tile = Tile(title: tr("Plus forte variation"), symbol: trend == false ? "arrow.down.right" : "arrow.up.right")
        tile.value = PriceChange.percent(change)
        tile.trend = trend
        tile.caption = "\(mover.holding.name) · \(mover.period.label)"
        tile.detail = tr("Ta position : \(TF.money(mover.value, currency))")
        tile.footnote = priceNote(data.prices.fetchedAt, clock: clock, isLarge: isLarge)
        return tile
    }

    static func watchlist(_ data: DomainData, currency: String, clock: PriceClock = PriceClock(), isSmall: Bool = false) -> Tile {
        guard !data.quotes.isEmpty else {
            return .empty(tr("Liste de suivi"), symbol: "list.star", message: tr("Les cours s'affichent dès que la connexion est disponible."), emptySymbol: "wifi.slash")
        }
        var tile = Tile(title: tr("Liste de suivi"), symbol: "list.star")
        let first = data.quotes[0]
        tile.value = Fmt.price(first.price, currency: currency)
        tile.caption = "\(first.symbol) · \(PriceChange.text(first.change24h, .day24h))"
        tile.trend = PriceChange.trend(first.change24h)
        tile.rows = data.quotes.prefix(6).map { quote in
            // A small widget shows one line per coin, without room for both: the change, which tells how it goes.
            TileRow(
                id: quote.id,
                title: quote.symbol,
                value: isSmall ? PriceChange.percent(quote.change24h) : Fmt.price(quote.price, currency: currency),
                detail: PriceChange.text(quote.change24h, .day24h, arrow: false),
                colorHex: PriceChange.colorHex(quote.change24h)
            )
        }
        tile.compactRows = true
        if let fetched = LivePrices.oldest(data.quotes.map(\.fetchedAt)) {
            tile.footnote = "\(clock.asOf(fetched)) · CoinGecko"
        } else {
            tile.footnote = tr("Cours : CoinGecko")
        }
        tile.inline = "\(first.symbol) \(Fmt.price(first.price, currency: currency)) \(PriceChange.percent(first.change24h))"
        return tile
    }

    static func market(_ data: DomainData, currency: String, clock: PriceClock = PriceClock(), isLarge: Bool = true) -> Tile {
        guard let global = data.global else {
            return .empty(tr("Marché crypto"), symbol: "globe.americas", message: tr("Les données du marché s'affichent dès que la connexion est disponible."), emptySymbol: "wifi.slash")
        }
        var tile = Tile(title: tr("Marché crypto"), symbol: "globe.americas")
        tile.value = BigNumber.compact(global.totalMarketCap, currency: currency)
        let arrow = PriceChange.arrow(global.change24h)
        let move = [arrow, PriceChange.percent(global.change24h)].filter { !$0.isEmpty }.joined(separator: " ")
        tile.caption = tr("capitalisation · \(move) sur 24 h")
        tile.trend = PriceChange.trend(global.change24h)
        var rows = [
            TileRow(id: "btc", title: tr("Dominance BTC"), value: Fmt.percent(global.bitcoinDominance / 100, decimals: 1), progress: global.bitcoinDominance / 100),
            TileRow(id: "eth", title: tr("Dominance ETH"), value: Fmt.percent(global.ethereumDominance / 100, decimals: 1), progress: global.ethereumDominance / 100),
        ]
        for quote in data.quotes.prefix(3) {
            rows.append(TileRow(id: quote.id, title: quote.symbol, value: Fmt.price(quote.price, currency: currency), detail: PriceChange.text(quote.change24h, .day24h, arrow: false)))
        }
        tile.rows = rows
        tile.footnote = priceNote(global.fetchedAt, source: "CoinGecko", clock: clock, isLarge: isLarge)
        tile.inline = tr("Marché \(PriceChange.percent(global.change24h))")
        return tile
    }
}
