import XCTest
@testable import Tessera

/// Market widgets: the change with its sign and period, prices reread as often as iOS allows, their
/// reading time shown, and caches written by earlier versions still read.
final class LivePricesTests: XCTestCase {
    private let french = Locale(identifier: "fr_CA")
    private let now = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 14, minute: 5)) ?? Date()

    /// French puts a (narrow) no-break space before « % »: compare with plain spaces.
    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    // MARK: Change

    func testChangeSignFollowsTheRoundedFigure() {
        XCTAssertEqual(plain(PriceChange.percent(1.45, locale: french)), "+1,45 %")
        XCTAssertEqual(plain(PriceChange.percent(-0.32, locale: french)), "−0,32 %")
        XCTAssertEqual(PriceChange.percent(1.45, locale: Locale(identifier: "en_US")), "+1.45%")
        // Too small to show: no sign, no color, no arrow, never « −0,00 % ».
        XCTAssertEqual(plain(PriceChange.percent(0.004, locale: french)), "0,00 %")
        XCTAssertEqual(plain(PriceChange.percent(-0.004, locale: french)), "0,00 %")
        XCTAssertNil(PriceChange.trend(0.004))
        XCTAssertNil(PriceChange.trend(-0.004))
        XCTAssertNil(PriceChange.trend(.nan))
        XCTAssertNil(PriceChange.trend(.infinity))
        XCTAssertEqual(PriceChange.trend(1.45), true)
        XCTAssertEqual(PriceChange.trend(-0.32), false)
        XCTAssertEqual(PriceChange.arrow(1.45), "▲")
        XCTAssertEqual(PriceChange.arrow(-0.32), "▼")
        XCTAssertEqual(PriceChange.arrow(0), "")
        XCTAssertEqual(PriceChange.colorHex(0), "8A94A6")
    }

    func testChangeTextCarriesItsPeriod() {
        let day = PriceChange.Period.day24h.label
        let session = PriceChange.Period.session.label
        XCTAssertEqual(plain(PriceChange.text(1.45, .day24h, locale: french)), "▲ +1,45 % · \(day)")
        XCTAssertEqual(plain(PriceChange.text(-0.32, .session, locale: french)), "▼ −0,32 % · \(session)")
        XCTAssertEqual(plain(PriceChange.text(-0.32, .session, arrow: false, locale: french)), "−0,32 % · \(session)")
        XCTAssertEqual(plain(PriceChange.text(0, .day24h, locale: french)), "0,00 % · \(day)")
        XCTAssertEqual(plain(PriceChange.text(1.2, .session, amount: "+245 $", locale: french)), "▲ +245 $ (+1,20 %) · \(session)")
        XCTAssertNotEqual(day, session)
    }

    // MARK: Refresh

    func testPricesAreReusedOnlyWhileFresh() {
        XCTAssertEqual(LivePrices.reloadInterval, 15 * 60)
        XCTAssertLessThan(LivePrices.cacheLifetime, LivePrices.reloadInterval, "Each reload must read a new price")
        XCTAssertTrue(LivePrices.isFresh(now.addingTimeInterval(-4 * 60), now: now))
        XCTAssertFalse(LivePrices.isFresh(now.addingTimeInterval(-6 * 60), now: now))
        XCTAssertFalse(LivePrices.isFresh(nil, now: now))
        XCTAssertFalse(LivePrices.isFresh(now.addingTimeInterval(60), now: now), "A clock turned back never keeps a price")
        XCTAssertTrue(LivePrices.isOld(now.addingTimeInterval(-31 * 60), now: now))
        XCTAssertFalse(LivePrices.isOld(now.addingTimeInterval(-10 * 60), now: now))
        XCTAssertEqual(LivePrices.oldest([nil, now, now.addingTimeInterval(-60)]), now.addingTimeInterval(-60))
        XCTAssertNil(LivePrices.oldest([nil]))
    }

    func testPriceWidgetsAreTheOnesFollowed() {
        for kind in [WidgetKind.crypto, .portfolio, .allocation, .topMover, .watchlist, .marketOverview, .companyStock] {
            XCTAssertTrue(LivePrices.follows(kind), "\(kind)")
        }
        for kind in [WidgetKind.companySnapshot, .companyRevenue, .budgetLeft, .netWorth, .clock] {
            XCTAssertFalse(LivePrices.follows(kind), "\(kind)")
        }
    }

    func testPriceTimeNamesTheDayWhenItIsNotToday() {
        let clock = PriceClock(now: now, uses24Hour: true)
        XCTAssertEqual(clock.time(now), Fmt.time(now, uses24Hour: true))
        let friday = now.addingTimeInterval(-2 * 86_400)
        XCTAssertTrue(clock.time(friday).hasSuffix(Fmt.time(friday, uses24Hour: true)))
        XCTAssertNotEqual(clock.time(friday), Fmt.time(friday, uses24Hour: true))
        let written = clock.time(now)
        XCTAssertEqual(clock.asOf(now), tr("Cours de \(written)"))
    }

    // MARK: Data

    func testCachesFromEarlierVersionsDecode() throws {
        let markets = #"{"quotes":{"bitcoin":{"id":"bitcoin","symbol":"BTC","name":"Bitcoin","price":64000,"change24h":2.4}},"currency":"usd","quotesFetchedAt":1760000000,"stocks":{"AAPL":{"symbol":"AAPL","price":190,"changePercent":-0.5,"fetchedAt":1760000000}}}"#
        let cache = try decoder().decode(MarketCache.self, from: Data(markets.utf8))
        XCTAssertEqual(cache.quotes["bitcoin"]?.change24h, 2.4)
        XCTAssertNil(cache.quotes["bitcoin"]?.fetchedAt)
        XCTAssertNil(cache.stocks["AAPL"]?.quotedAt)
        XCTAssertEqual(cache.stocks["AAPL"]?.priceTime, Date(timeIntervalSince1970: 1_760_000_000))

        let crypto = #"{"coins":{"bitcoin-usd":{"id":"bitcoin","symbol":"BTC","name":"Bitcoin","currency":"USD","price":64000,"change24h":-1.2,"sparkline":[1,2],"fetchedAt":1760000000}}}"#
        let coins = try decoder().decode(CryptoCache.self, from: Data(crypto.utf8))
        XCTAssertEqual(coins.coins["bitcoin-usd"]?.change24h, -1.2)

        // The new fields survive saving.
        let quote = CoinQuote(id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 1, change24h: 1, fetchedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoded = try decoder().decode(CoinQuote.self, from: encoder.encode(quote))
        XCTAssertEqual(decoded.fetchedAt?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 1)
    }

    func testFinnhubQuoteGivesTheChangeSinceTheClose() throws {
        let full = #"{"c":190.5,"d":-0.6,"dp":-0.3141,"h":192,"l":189,"o":191,"pc":191.1,"t":1760126400}"#
        let quote = try XCTUnwrap(JSONDecoder().decode(FinnhubQuote.self, from: Data(full.utf8)).stockQuote("AAPL", fetchedAt: now))
        XCTAssertEqual(quote.changePercent, -0.3141, accuracy: 0.0001)
        XCTAssertEqual(quote.quotedAt, Date(timeIntervalSince1970: 1_760_126_400))
        XCTAssertEqual(quote.priceTime, Date(timeIntervalSince1970: 1_760_126_400))

        let noPercent = #"{"c":110,"dp":null,"pc":100,"t":0}"#
        let computed = try XCTUnwrap(JSONDecoder().decode(FinnhubQuote.self, from: Data(noPercent.utf8)).stockQuote("X", fetchedAt: now))
        XCTAssertEqual(computed.changePercent, 10, accuracy: 0.0001)
        XCTAssertNil(computed.quotedAt)
        XCTAssertEqual(computed.priceTime, now)

        let unknown = #"{"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}"#
        XCTAssertNil(try JSONDecoder().decode(FinnhubQuote.self, from: Data(unknown.utf8)).stockQuote("NOPE", fetchedAt: now))
    }

    func testPortfolioDayChange() {
        var state = PortfolioState()
        state.holdings = [
            Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 1, costBasis: 50_000),
            Holding(kind: .cash, name: "Cash", symbol: "USD", quantity: 1_000, costBasis: 1_000),
        ]
        let prices = PriceBook(prices: ["bitcoin": 60_000], changes: ["bitcoin": 10])
        let positions = PortfolioMath.positions(state, prices: prices)
        let summary = PortfolioMath.summary(positions)
        XCTAssertTrue(summary.hasDayChange)
        // 60 000 was 54 545,45 a day ago: +5 454,55 on 55 545,45 before the move.
        XCTAssertEqual(summary.dayChange, 60_000 - 60_000 / 1.1, accuracy: 0.01)
        XCTAssertEqual(summary.dayChangePercent ?? 0, (60_000 - 60_000 / 1.1) / (61_000 - (60_000 - 60_000 / 1.1)) * 100, accuracy: 0.0001)
        XCTAssertEqual(PortfolioMath.period(positions), .day24h)

        state.holdings.append(Holding(kind: .etf, name: "XEQT", symbol: "XEQT", quantity: 10, costBasis: 300))
        let mixed = PortfolioMath.positions(state, prices: PriceBook(prices: ["bitcoin": 60_000, "XEQT": 32], changes: ["bitcoin": 10, "XEQT": -0.32]))
        XCTAssertEqual(PortfolioMath.period(mixed), .session)

        let manual = PortfolioMath.summary(PortfolioMath.positions(state, prices: PriceBook()))
        XCTAssertFalse(manual.hasDayChange)
        XCTAssertNil(manual.dayChangePercent)

        // A change of −100 % (bad data) never divides by zero.
        let broken = PortfolioMath.summary(PortfolioMath.positions(state, prices: PriceBook(prices: ["bitcoin": 0], changes: ["bitcoin": -100])))
        XCTAssertTrue(broken.dayChange.isFinite)
    }

    // MARK: Widgets

    func testMarketWidgetsShowTheChangeAndTheTime() {
        let clock = PriceClock(now: now, uses24Hour: true)
        var data = DomainData()
        data.quotes = [
            CoinQuote(id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 64_210, change24h: 1.45, fetchedAt: now),
            CoinQuote(id: "ethereum", symbol: "ETH", name: "Ethereum", price: 3_180, change24h: -0.32, fetchedAt: now.addingTimeInterval(-60)),
        ]
        let watchlist = MoneyTiles.watchlist(data, currency: "USD", clock: clock)
        XCTAssertEqual(watchlist.caption, "BTC · \(PriceChange.text(1.45, .day24h))")
        XCTAssertEqual(watchlist.trend, true)
        XCTAssertEqual(watchlist.rows.map(\.detail), [PriceChange.text(1.45, .day24h, arrow: false), PriceChange.text(-0.32, .day24h, arrow: false)])
        XCTAssertEqual(watchlist.footnote, "\(clock.asOf(now.addingTimeInterval(-60))) · CoinGecko", "The oldest price sets the time")
        let small = MoneyTiles.watchlist(data, currency: "USD", clock: clock, isSmall: true)
        XCTAssertEqual(small.rows.map(\.value), [PriceChange.percent(1.45), PriceChange.percent(-0.32)])

        // Quotes from an older cache have no time: the source alone, never a made-up time.
        data.quotes = data.quotes.map { quote in
            var old = quote
            old.fetchedAt = nil
            return old
        }
        XCTAssertEqual(MoneyTiles.watchlist(data, currency: "USD", clock: clock).footnote, tr("Cours : CoinGecko"))

        data.global = MarketGlobal(totalMarketCap: 2e12, change24h: -1.8, bitcoinDominance: 54, ethereumDominance: 12, fetchedAt: now)
        let market = MoneyTiles.market(data, currency: "USD", clock: clock, isLarge: false)
        XCTAssertEqual(market.trend, false)
        XCTAssertEqual(market.footnote, "\(clock.asOf(now)) · CoinGecko")
        XCTAssertTrue(MoneyTiles.market(data, currency: "USD", clock: clock, isLarge: true).footnote?.hasSuffix(MoneyTiles.disclaimer) ?? false)
    }

    func testPortfolioWidgetsShowTheDayMove() {
        let clock = PriceClock(now: now, uses24Hour: true)
        var data = DomainData()
        data.portfolio.holdings = [
            Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 1, costBasis: 50_000),
            Holding(kind: .etf, name: "XEQT", symbol: "XEQT", quantity: 10, costBasis: 300),
        ]
        data.prices = PriceBook(prices: ["bitcoin": 60_000, "XEQT": 32], changes: ["bitcoin": 0.5, "XEQT": -4], fetchedAt: now)
        let portfolio = MoneyTiles.portfolio(data, currency: "USD", clock: clock, isLarge: false)
        XCTAssertTrue(portfolio.caption?.hasPrefix("▲") ?? false)
        XCTAssertTrue(portfolio.caption?.hasSuffix(" · \(PriceChange.Period.session.label)") ?? false, "Stocks inside: the market's day")
        XCTAssertEqual(portfolio.trend, true)
        XCTAssertEqual(portfolio.footnote, clock.asOf(now))
        XCTAssertEqual(portfolio.rows.first?.detail, PriceChange.text(0.5, .day24h, arrow: false))

        let mover = MoneyTiles.topMover(data, currency: "USD", clock: clock)
        XCTAssertEqual(mover.value, PriceChange.percent(-4))
        XCTAssertEqual(mover.trend, false)
        XCTAssertEqual(mover.symbol, "arrow.down.right")
        XCTAssertEqual(mover.caption, "XEQT · \(PriceChange.Period.session.label)")

        // Manual prices only: no day move, the total gain as before, the disclaimer alone.
        data.prices = PriceBook()
        let manual = MoneyTiles.portfolio(data, currency: "USD", clock: clock, isLarge: false)
        XCTAssertEqual(manual.footnote, MoneyTiles.disclaimer)
        XCTAssertNil(manual.detail)
    }

    func testStockWidgetShowsTheMoveSinceTheClose() {
        let clock = PriceClock(now: now, uses24Hour: true)
        let closed = now.addingTimeInterval(-2 * 86_400)
        var data = DomainData()
        data.following.followed = [CompanyRef(cik: 1, ticker: "TCK", name: "Ticker Inc.")]
        data.stocks = ["TCK": StockQuote(symbol: "TCK", price: 100, changePercent: -0.32, fetchedAt: now, quotedAt: closed)]
        let tile = BusinessTiles.stock(data, clock: clock, isLarge: false)
        XCTAssertEqual(tile.caption, "TCK · \(PriceChange.text(-0.32, .session))")
        XCTAssertEqual(tile.trend, false)
        XCTAssertEqual(tile.footnote, "\(clock.asOf(closed)) · Finnhub", "The time of the price, not of the reading")
    }

    // MARK: Finances

    func testNetWorthSaysTheRealPeriod() {
        var state = BudgetState()
        state.accounts = [Account(name: "Compte", balance: 1_000)]
        let calendar = DateMath.calendar
        let threeDays = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let amount = Fmt.signedMoney(100, currency: "USD", decimals: 0)

        state.netWorthHistory = [ValuePoint(date: now, value: 1_000)]
        XCTAssertEqual(MoneyTiles.netWorth(state, now: now, currency: "USD").caption, tr("actifs moins dettes"))
        XCTAssertNil(MoneyTiles.netWorth(state, now: now, currency: "USD").trend)

        state.netWorthHistory = [ValuePoint(date: threeDays, value: 900), ValuePoint(date: now, value: 1_000)]
        let day = Fmt.format(threeDays, template: "dMMM")
        let since = tr("Depuis le \(day)")
        XCTAssertEqual(MoneyTiles.netWorth(state, now: now, currency: "USD").caption, "\(since) · \(amount)")
        XCTAssertEqual(MoneyTiles.netWorth(state, now: now, currency: "USD").trend, true)

        let month = calendar.date(byAdding: .day, value: -29, to: now) ?? now
        state.netWorthHistory = [ValuePoint(date: month, value: 900), ValuePoint(date: now, value: 1_000)]
        XCTAssertEqual(MoneyTiles.netWorth(state, now: now, currency: "USD").caption, tr("\(amount) sur 30 jours"))
    }

    func testSpendingComparesWithLastMonthOnlyWhenItHasData() {
        let calendar = DateMath.calendar
        let thisMonth = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12)) ?? now
        let lastMonth = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12)) ?? now
        let before = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12)) ?? now
        var state = BudgetState()
        state.expenses = [Expense(amount: 300, date: thisMonth)]
        XCTAssertNil(MoneyTiles.monthComparison(state, now: now, currency: "USD"), "No spending last month: nothing to compare")

        state.expenses.append(Expense(amount: 100, date: lastMonth))
        XCTAssertNil(MoneyTiles.monthComparison(state, now: now, currency: "USD"), "Noted from the middle of last month: not a full month")

        state.expenses.append(Expense(amount: 50, date: before))
        let difference = TF.money(200, "USD")
        XCTAssertEqual(MoneyTiles.monthComparison(state, now: now, currency: "USD"), tr("\(difference) de plus que le mois dernier à la même date"))
    }
}
