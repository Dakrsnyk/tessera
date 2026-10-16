import XCTest
@testable import Tessera

/// Business: sales in another currency than the app's, converted at the ECB rate of their own day (the
/// business day before on weekends and holidays), rounded to the cent, their original amount kept; never
/// guessed without a rate, and a file imported twice still adds nothing.
final class CurrencyConversionTests: XCTestCase {
    /// Noon on a day of January 2026 (Friday the 2nd, Saturday the 3rd, Monday the 5th).
    private func january(_ day: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: 12))!
    }

    /// One USD in CAD, as Frankfurter gives it: no rate on the weekend.
    private let history = FXHistory(home: "CAD", rates: ["USD": ["2026-01-02": 1.3733, "2026-01-05": 1.3792]])

    private let csv = """
    Date,Description,Amount,Currency
    2026-01-02,Atelier,100.00,USD
    2026-01-03,Affiche,19.99,usd
    2026-01-05,Encre,-12.50,USD
    2026-01-05,Vente locale,40.00,CAD
    """

    // MARK: Rates

    func testAWeekendTakesTheRateOfTheBusinessDayBefore() {
        XCTAssertEqual(history.rate("USD", on: "2026-01-05")?.value, 1.3792)
        XCTAssertEqual(history.rate("USD", on: "2026-01-03")?.day, "2026-01-02", "Saturday: Friday's rate")
        XCTAssertEqual(history.rate("usd", on: "2026-01-04")?.value, 1.3733, "Sunday: Friday's rate")
        XCTAssertNil(history.rate("USD", on: "2026-01-20"), "Never a rate older than a week")
        XCTAssertNil(history.rate("USD", on: "2025-12-31"), "No rate before the first one")
        XCTAssertNil(history.rate("EUR", on: "2026-01-02"))
        XCTAssertEqual(FXHistory.dayBefore("2026-03-01"), "2026-02-28")
        XCTAssertEqual(FXHistory.dayBefore("2026-01-01"), "2025-12-31")
    }

    func testAmountsAreRoundedToTheCent() throws {
        let converted = try XCTUnwrap(CurrencyConversion.convert(19.99, "usd", on: january(3), with: history))
        XCTAssertEqual(converted.amount, 27.45, accuracy: 0.000_1, "19,99 × 1,3733 = 27,452267")
        XCTAssertEqual(converted.original, ForeignAmount(amount: 19.99, currency: "USD", rate: 1.3733, rateDay: "2026-01-02"))
        XCTAssertEqual(CurrencyConversion.rounded(-12.345_6, in: "CAD"), -12.35, accuracy: 0.000_1)
        XCTAssertEqual(CurrencyConversion.rounded(1_234.56, in: "JPY"), 1_235, "No cents in yen")
        let home = try XCTUnwrap(CurrencyConversion.convert(40, "CAD", on: january(5), with: history))
        XCTAssertEqual(home.amount, 40)
        XCTAssertNil(home.original, "Already in the app's currency: nothing to keep")
    }

    // MARK: Files

    func testAFileIsConvertedLineByLineAtTheRateOfItsDay() throws {
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.foreignCurrencies(home: "cad"), ["USD"])
        let converted = batch.converted(with: history)
        XCTAssertTrue(converted.unconverted.isEmpty)
        XCTAssertEqual(converted.sales.count, 3)
        XCTAssertEqual(converted.sales[0].amount, 137.33, accuracy: 0.000_1)
        XCTAssertEqual(converted.sales[1].amount, 27.45, accuracy: 0.000_1, "Saturday at Friday's rate")
        XCTAssertEqual(converted.sales[1].original?.amount, 19.99)
        XCTAssertEqual(converted.sales[1].original?.currency, "USD")
        XCTAssertEqual(converted.sales[2].amount, 40, "A line in the app's currency stays as it is")
        XCTAssertNil(converted.sales[2].original)
        XCTAssertEqual(converted.expenses.first?.amount ?? 0, 17.24, accuracy: 0.000_1, "12,50 × 1,3792")
        XCTAssertEqual(converted.expenses.first?.original?.rateDay, "2026-01-05")
        XCTAssertEqual(converted.convertedCurrencies, ["USD"])
        XCTAssertEqual(converted.rateDays, "2026-01-02"..."2026-01-05")
        XCTAssertEqual(converted.sales.map(\.externalID), batch.sales.map(\.externalID), "Same ids as before the conversion")

        var state = BusinessState()
        XCTAssertEqual(state.merge(converted).added, 4)
        let again = state.merge(try BusinessCSV.parse(csv).converted(with: history))
        XCTAssertEqual(again.added, 0, "The same file again adds nothing")
        XCTAssertEqual(again.unchanged, 4)
        XCTAssertEqual(converted.converted(with: history), converted, "Never converted twice")
    }

    func testWithoutARateNothingIsGuessed() throws {
        let batch = try BusinessCSV.parse(csv)
        let offline = FXHistory(home: "CAD", unavailable: ["USD": .unreachable])
        let converted = batch.converted(with: offline)
        XCTAssertEqual(converted.unconverted, ["USD"])
        XCTAssertEqual(converted.sales.map(\.amount), [100, 19.99, 40], "Left as they came, to be imported only if chosen")
        XCTAssertTrue(converted.sales.allSatisfy { $0.original == nil })

        let tooOld = FXHistory(home: "CAD", rates: ["USD": ["2025-12-01": 1.39]])
        XCTAssertEqual(batch.converted(with: tooOld).unconverted, ["USD"], "A rate a month old isn't the rate of the day")
    }

    func testOnlyTheCurrenciesWithoutARateStayAsTheyCame() throws {
        let batch = try BusinessCSV.parse(csv + "\n2026-01-05,Souk,50.00,AED")
        var rates = history
        rates.unavailable = ["AED": .unsupported]
        let converted = batch.converted(with: rates)
        XCTAssertEqual(converted.unconverted, ["AED"])
        XCTAssertEqual(converted.sales.map(\.amount), [137.33, 27.45, 40, 50], "USD converted all the same, AED as it came")
        XCTAssertNil(converted.sales[3].original)

        let code = "AED"
        let message = CurrencyConversion.problemMessage(for: converted.unconverted, unavailable: rates.unavailable)
        XCTAssertTrue(message.contains(tr("La BCE ne publie pas de taux pour \(code).")))
        XCTAssertFalse(message.contains(tr("Impossible d'obtenir les taux de la BCE. Vérifie ta connexion, puis réessaie.")),
                       "Trying again won't help")
    }

    func testTheMessageSaysWhyARateIsMissing() throws {
        let code = "USD"
        let offline = CurrencyConversion.problemMessage(for: [code], unavailable: [code: .unreachable])
        XCTAssertTrue(offline.contains(tr("Non converti (taux indisponible) : \(code).")))
        XCTAssertTrue(offline.contains(tr("Impossible d'obtenir les taux de la BCE. Vérifie ta connexion, puis réessaie.")))

        // Rates for USD, but none for a day two months after the last one (a date to come, or misread).
        let later = try BusinessCSV.parse("Date,Amount,Currency\n2026-03-02,10.00,USD").converted(with: history)
        XCTAssertEqual(later.unconverted, ["USD"])
        let message = CurrencyConversion.problemMessage(for: later.unconverted, unavailable: history.unavailable)
        XCTAssertTrue(message.contains(tr("Aucun taux de la BCE pour la date de certaines opérations : date à venir, ou mal lue.")))
        XCTAssertFalse(message.contains(tr("Impossible d'obtenir les taux de la BCE. Vérifie ta connexion, puis réessaie.")))
    }

    func testImportingWithoutConversionNeverUndoesAConversion() throws {
        var state = BusinessState()
        state.merge(try BusinessCSV.parse(csv).converted(with: history))
        let offline = FXHistory(home: "CAD", unavailable: ["USD": .unreachable])
        let result = state.merge(try BusinessCSV.parse(csv).converted(with: offline))
        XCTAssertEqual(result.unchanged, 4, "The same file without its rates changes nothing")
        XCTAssertEqual(state.sales.map(\.amount), [137.33, 27.45, 40])
        XCTAssertEqual(state.sales[0].original?.amount, 100)
        XCTAssertEqual(state.expenses.first?.amount ?? 0, 17.24, accuracy: 0.000_1)
        XCTAssertEqual(state.expenses.first?.original?.currency, "USD")
        XCTAssertEqual(state.merge(try BusinessCSV.parse(csv)).updated, 3, "Not left unconverted for lack of a rate: updated as it comes")
    }

    // MARK: Stripe

    func testStripeConvertsEachTransactionAndItsFees() {
        let transactions = [
            StripeTransactions.Transaction(id: "txn_1", amount: 10_000, fee: 320, created: january(2).timeIntervalSince1970,
                                           currency: "usd", type: "charge", description: "Atelier"),
            StripeTransactions.Transaction(id: "txn_2", amount: 1_999, fee: 88, created: january(3).timeIntervalSince1970,
                                           currency: "usd", type: "payment", description: nil),
            StripeTransactions.Transaction(id: "txn_3", amount: 4_000, fee: 0, created: january(5).timeIntervalSince1970,
                                           currency: "cad", type: "charge", description: "Vente locale"),
        ]
        let batch = StripeTransactions.batch(from: transactions, history: history)
        XCTAssertTrue(batch.unconverted.isEmpty)
        XCTAssertEqual(batch.sales.map(\.amount), [137.33, 27.45, 40])
        XCTAssertEqual(batch.sales[0].original?.amount, 100)
        XCTAssertNil(batch.sales[2].original)
        let fees = batch.expenses.sorted { $0.date < $1.date }
        XCTAssertEqual(fees.map(\.externalID), ["fees-2026-01-02", "fees-2026-01-03"], "Still one cost a day, same ids")
        XCTAssertEqual(fees[0].amount, 4.39, accuracy: 0.000_1, "3,20 × 1,3733")
        XCTAssertEqual(fees[1].amount, 1.21, accuracy: 0.000_1, "0,88 × 1,3733")
        XCTAssertEqual(fees[0].original?.amount ?? 0, 3.2, accuracy: 0.000_1)

        let missing = StripeTransactions.batch(from: transactions, history: FXHistory(home: "CAD"))
        XCTAssertEqual(missing.unconverted, ["USD"], "No rate: the sync must stop and say so")
        let asIs = StripeTransactions.batch(from: transactions)
        XCTAssertTrue(asIs.unconverted.isEmpty)
        XCTAssertEqual(asIs.sales.map(\.amount), [100, 19.99, 40], "Without conversion: as Stripe gives them")

        var state = BusinessState()
        state.merge(batch)
        XCTAssertEqual(state.merge(StripeTransactions.batch(from: transactions, history: history)).added, 0, "A second sync adds nothing")
    }

    func testASyncWithoutConversionNeverUndoesAConversion() {
        let transactions = [
            StripeTransactions.Transaction(id: "txn_1", amount: 10_000, fee: 320, created: january(2).timeIntervalSince1970,
                                           currency: "usd", type: "charge", description: "Atelier"),
        ]
        var state = BusinessState()
        state.merge(StripeTransactions.batch(from: transactions, history: history))
        let asIs = StripeTransactions.batch(from: transactions, history: FXHistory(home: "CAD"))
        XCTAssertEqual(asIs.unconverted, ["USD"])
        XCTAssertEqual(state.merge(asIs).unchanged, 2, "The sale and the day's fees stay converted")
        XCTAssertEqual(state.sales.first?.amount, 137.33)
        XCTAssertEqual(state.sales.first?.original?.amount, 100)
        XCTAssertEqual(state.expenses.first?.amount ?? 0, 4.39, accuracy: 0.000_1)
        XCTAssertEqual(state.expenses.first?.original?.currency, "USD")
    }

    // MARK: Data saved before

    func testEntriesSavedBeforeTheConversionStillRead() throws {
        let json = """
        {"sales":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"amount":10,"orders":1,"newCustomers":0,"visitors":0,"note":"","source":"stripe","externalID":"txn_1"}],
         "expenses":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"amount":2,"label":"Frais Stripe","source":"stripe","externalID":"fees-2001-01-01"}],
         "connections":{"stripe":{"keyHint":"…a1B2","isTestMode":false,"connectedAt":0}}}
        """
        let state = try JSONDecoder().decode(BusinessState.self, from: Data(json.utf8))
        XCTAssertEqual(state.sales.first?.amount, 10)
        XCTAssertNil(state.sales.first?.original)
        XCTAssertEqual(state.expenses.first?.amount, 2)
        XCTAssertNil(state.expenses.first?.original)
        XCTAssertEqual(state.connections.stripe?.keyHint, "…a1B2")
        XCTAssertNil(state.connections.stripe?.unconvertedCurrencies)
        XCTAssertNil(state.connections.stripe?.keptCurrencies)

        var sale = SalesEntry(date: january(2), amount: 137.33, source: BusinessSource.csv.rawValue, externalID: "a")
        sale.original = ForeignAmount(amount: 100, currency: "USD", rate: 1.3733, rateDay: "2026-01-02")
        let read = try JSONDecoder().decode(SalesEntry.self, from: JSONEncoder().encode(sale))
        XCTAssertEqual(read, sale, "The original amount is kept when saved")
    }
}
