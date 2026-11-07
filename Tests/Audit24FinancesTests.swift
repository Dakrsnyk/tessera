import XCTest
@testable import Ardane

/// Audit 24.C-D: one regression test per finding corrected in Finances, Placements, Business, Travel, Car and Life.
final class Audit24FinancesTests: XCTestCase {
    private func moment(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: M-02 bill of the 31st

    func testABillOfThe31stKeepsItsDayAfterAShortMonth() {
        let monthly = Bill(name: "Loyer", amount: 900, anchorDate: moment(2026, 1, 31), period: .monthly)
        XCTAssertEqual(monthly.nextDue(after: moment(2026, 2, 10)), DateMath.startOfDay(moment(2026, 2, 28)))
        XCTAssertEqual(monthly.nextDue(after: moment(2026, 3, 5)), DateMath.startOfDay(moment(2026, 3, 31)), "Not the 28th")
        XCTAssertEqual(monthly.nextDue(after: moment(2026, 4, 1)), DateMath.startOfDay(moment(2026, 4, 30)))
        XCTAssertEqual(monthly.nextDue(after: moment(2026, 5, 1)), DateMath.startOfDay(moment(2026, 5, 31)))
        // A bill due today is due today.
        XCTAssertEqual(monthly.nextDue(after: moment(2026, 3, 31, 18)), DateMath.startOfDay(moment(2026, 3, 31)))
        let yearly = Bill(name: "Assurance", amount: 600, anchorDate: moment(2024, 2, 29), period: .yearly)
        XCTAssertEqual(yearly.nextDue(after: moment(2026, 3, 1)), DateMath.startOfDay(moment(2027, 2, 28)))
        XCTAssertEqual(yearly.nextDue(after: moment(2027, 3, 1)), DateMath.startOfDay(moment(2028, 2, 29)))
        // The upcoming list and the payments counted agree on the day.
        var state = BudgetState()
        state.bills = [monthly]
        XCTAssertEqual(BudgetMath.upcomingBills(state, at: moment(2026, 3, 5)).first?.due, DateMath.startOfDay(moment(2026, 3, 31)))
    }

    // MARK: M-01 trip budget text

    func testTheTripBudgetIsReadWithTheLocaleThatWroteIt() {
        let locales = ["en_US", "de_DE", "es_ES", "it_IT", "pt_BR", "ja_JP", "fr_CA"].map(Locale.init(identifier:))
        for locale in locales {
            let text = TripBudgetText.format(2_500, locale: locale)
            XCTAssertEqual(TripBudgetText.parse(text, locale: locale), 2_500, "\(locale.identifier): \(text)")
            let cents = TripBudgetText.format(1_234.56, locale: locale)
            XCTAssertEqual(TripBudgetText.parse(cents, locale: locale) ?? 0, 1_234.56, accuracy: 0.0001, "\(locale.identifier): \(cents)")
        }
        XCTAssertEqual(TripBudgetText.parse("2,500.50", locale: Locale(identifier: "en_US")), 2_500.5)
        XCTAssertEqual(TripBudgetText.parse("2.500,50", locale: Locale(identifier: "de_DE")), 2_500.5)
        XCTAssertEqual(TripBudgetText.parse("2 500,50", locale: Locale(identifier: "fr_CA")), 2_500.5)
        XCTAssertNil(TripBudgetText.parse("abc", locale: Locale(identifier: "en_US")), "Not a number: nothing is read")
    }

    // MARK: M-04 budget not given

    func testWithoutABudgetTheQuickExpenseTileShowsWhatWasSpentNotARemainder() {
        var state = BudgetState()
        let now = moment(2026, 9, 15)
        state.quickExpenses = [QuickExpense(name: "Café", amount: 4)]
        state.add(Expense(amount: 50, categoryID: BudgetState.fixedID(1), date: moment(2026, 9, 10)))
        let unknown = MoneyTiles.quickExpense(state, now: now, currency: "CAD", knowsBudget: false)
        let known = MoneyTiles.quickExpense(state, now: now, currency: "CAD", knowsBudget: true)
        XCTAssertEqual(unknown.detail?.contains(TF.money(1_950, "CAD")), false, "The default 2 000 is not a real budget")
        XCTAssertEqual(unknown.detail?.contains(TF.money(50, "CAD")), true)
        XCTAssertEqual(known.detail?.contains(TF.money(1_950, "CAD")), true, "A budget the person gave: unchanged")
    }

    // MARK: M-05, M-16, M-17 portfolio

    func testAPriceInAnotherCurrencyIsConvertedOrLeftOut() throws {
        let rates = FXRates(base: "CAD", rates: ["USD": 0.8], day: "2026-11-06", fetchedAt: moment(2026, 11, 6))
        var book = PriceBook()
        XCTAssertTrue(MarketService.add(price: 60_000, change: 2, for: "bitcoin", quotedIn: "usd", to: &book, home: "CAD", rates: rates))
        XCTAssertEqual(try XCTUnwrap(book.prices["bitcoin"]), 75_000, accuracy: 0.001, "60 000 USD at 0.8 USD per CAD")
        let holding = Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 0.01, costBasis: 1_000)
        var state = PortfolioState()
        state.holdings = [holding]
        let position = try XCTUnwrap(PortfolioMath.positions(state, prices: book).first)
        XCTAssertEqual(position.value, 750, accuracy: 0.001)
        XCTAssertEqual(position.gain, -250, accuracy: 0.001)
        // The same currency needs no rate; another one without a rate is never shown as if it were the home one.
        var same = PriceBook()
        XCTAssertTrue(MarketService.add(price: 10, change: 0, for: "AAPL", quotedIn: "USD", to: &same, home: "USD", rates: nil))
        var none = PriceBook()
        XCTAssertFalse(MarketService.add(price: 60_000, change: 2, for: "bitcoin", quotedIn: "usd", to: &none, home: "CAD", rates: nil))
        XCTAssertTrue(none.prices.isEmpty && none.changes.isEmpty)
    }

    func testAZeroPriceIsNotAPriceAndAPositionWithoutOneIsMarked() throws {
        var state = PortfolioState()
        state.holdings = [
            Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 1, costBasis: 500),
            Holding(kind: .stock, name: "Privée", symbol: "PRIV", quantity: 4, costBasis: 100, manualPrice: 30),
            Holding(kind: .stock, name: "Sans prix", symbol: "NOPE", quantity: 5, costBasis: 100),
            Holding(kind: .stock, name: "Vendue", symbol: "OLD", quantity: 0, costBasis: 0),
        ]
        var book = PriceBook()
        XCTAssertFalse(MarketService.add(price: 0, change: 0, for: "bitcoin", quotedIn: "USD", to: &book, home: "USD", rates: nil))
        let positions = PortfolioMath.positions(state, prices: PriceBook(prices: ["bitcoin": 0]))
        XCTAssertEqual(positions.map(\.isEstimated), [true, false, true, false])
        XCTAssertEqual(positions[0].value, 500, "A price of zero is not used: the cost, flagged")
        let summary = PortfolioMath.summary(positions)
        XCTAssertEqual(summary.estimatedCount, 2)
        XCTAssertEqual(positions[0].gain + positions[2].gain, 0, "The estimated positions add no gain")
    }

    // MARK: M-06 Stripe pages

    private func stripePage(_ ids: ClosedRange<Int>, hasMore: Bool) -> StripeTransactions.Page {
        StripeTransactions.Page(data: ids.map {
            StripeTransactions.Transaction(id: "txn_\($0)", amount: 1_000, fee: 0, created: 1_000_000 - Double($0), currency: "cad", type: "charge", description: nil)
        }, hasMore: hasMore)
    }

    func testAPartialStripeReadDoesNotMoveTheSyncDateForward() async throws {
        var calls = 0
        let partial = try await StripeSync.fetchAll(maxPages: 3) { _ in
            calls += 1
            return self.stripePage(1...100, hasMore: true)
        }
        XCTAssertEqual(calls, 3)
        XCTAssertFalse(partial.isComplete, "The limit was reached with more to read")
        XCTAssertEqual(partial.transactions.count, 300)
        let previous = moment(2026, 1, 1)
        XCTAssertEqual(StripeSync.nextSyncedUntil(previous: previous, newest: moment(2026, 11, 1), isComplete: partial.isComplete), previous, "Not moved: the older ones are asked again")
        XCTAssertNil(StripeSync.nextSyncedUntil(previous: nil, newest: moment(2026, 11, 1), isComplete: false))

        var pages = 0
        let complete = try await StripeSync.fetchAll(maxPages: 3) { _ in
            pages += 1
            return self.stripePage(1...10, hasMore: pages < 2)
        }
        XCTAssertTrue(complete.isComplete)
        XCTAssertEqual(complete.transactions.count, 20)
        XCTAssertEqual(StripeSync.nextSyncedUntil(previous: previous, newest: moment(2026, 11, 1), isComplete: true), moment(2026, 11, 1))
        XCTAssertEqual(StripeSync.nextSyncedUntil(previous: moment(2026, 12, 1), newest: moment(2026, 11, 1), isComplete: true), moment(2026, 12, 1))
    }

    // MARK: M-08 no purge

    func testAddingAnOperationNeverDeletesOldOnes() {
        var state = BudgetState()
        let now = moment(2026, 9, 15)
        state.add(Expense(amount: 10, categoryID: BudgetState.fixedID(1), date: now.addingTimeInterval(-450 * 86_400)))
        state.addIncome(IncomeEntry(amount: 100, label: "Salaire", date: now.addingTimeInterval(-900 * 86_400)))
        state.add(Expense(amount: 20, categoryID: BudgetState.fixedID(1), date: now))
        state.addIncome(IncomeEntry(amount: 100, label: "Salaire", date: now))
        XCTAssertEqual(state.expenses.count, 2, "A 450-day-old expense stays")
        XCTAssertEqual(state.incomes.count, 2, "A 900-day-old income stays")
    }

    // MARK: M-15 growth period

    func testThePreviousPeriodNeverSpillsIntoTheCurrentOne() {
        let previous = BusinessMath.previousInterval(.month, containing: moment(2026, 3, 31, 12))
        XCTAssertLessThanOrEqual(previous.end, moment(2026, 3, 1, 0), "February's window stops where March starts")
        XCTAssertFalse(previous.contains(moment(2026, 3, 2)))
    }

    // MARK: M-19 trip deletion

    func testDeletingATripDeletesItsFlightsStaysAndActivities() {
        var state = TravelState()
        let paris = Trip(destination: "Paris", start: moment(2026, 12, 10), end: moment(2026, 12, 17))
        let rome = Trip(destination: "Rome", start: moment(2027, 3, 1), end: moment(2027, 3, 8))
        state.trips = [paris, rome]
        state.flights = [Flight(number: "AC1", from: "YUL", to: "CDG", departure: moment(2026, 12, 10, 18)),
                         Flight(number: "AC2", from: "YUL", to: "FCO", departure: moment(2027, 3, 1, 18))]
        state.stays = [Stay(name: "Hôtel Paris", checkIn: moment(2026, 12, 10), checkOut: moment(2026, 12, 17)),
                       Stay(name: "Hôtel Rome", checkIn: moment(2027, 3, 1), checkOut: moment(2027, 3, 8))]
        state.activities = [TripActivity(title: "Louvre", date: moment(2026, 12, 12, 10)), TripActivity(title: "Colisée", date: moment(2027, 3, 3, 10))]
        state.deleteTrip(paris.id)
        XCTAssertEqual(state.flights.map(\.number), ["AC2"])
        XCTAssertEqual(state.stays.map(\.name), ["Hôtel Rome"])
        XCTAssertEqual(state.activities.map(\.title), ["Colisée"])
        XCTAssertEqual(TravelMath.nextFlight(state, at: moment(2026, 12, 1))?.number, "AC2", "No more flight of a deleted trip")
    }
}
