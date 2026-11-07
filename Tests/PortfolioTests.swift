import XCTest
@testable import Ardane

/// Placements: gains and cost, the price used when no live price is known, empty positions, and the saved state.
final class PortfolioTests: XCTestCase {
    private func positions(_ holdings: [Holding], _ prices: PriceBook = PriceBook()) -> [PortfolioMath.Position] {
        var state = PortfolioState()
        state.holdings = holdings
        return PortfolioMath.positions(state, prices: prices)
    }

    func testGainIsTheLivePriceAgainstWhatWasPaid() throws {
        let stock = Holding(kind: .stock, name: "Apple", symbol: "AAPL", quantity: 10, costBasis: 1_000)
        let found = positions([stock], PriceBook(prices: ["AAPL": 120]))
        let position = try XCTUnwrap(found.first)
        XCTAssertEqual(position.price, 120)
        XCTAssertEqual(position.value, 1_200)
        XCTAssertEqual(position.gain, 200)
        let summary = PortfolioMath.summary(found)
        XCTAssertEqual(summary.value, 1_200)
        XCTAssertEqual(summary.cost, 1_000)
        XCTAssertEqual(summary.gain, 200)
        XCTAssertEqual(try XCTUnwrap(summary.gainPercent), 0.2, accuracy: 0.0001)
    }

    func testALossIsNegative() throws {
        let stock = Holding(kind: .stock, name: "Apple", symbol: "AAPL", quantity: 10, costBasis: 1_000)
        let summary = PortfolioMath.summary(positions([stock], PriceBook(prices: ["AAPL": 80])))
        XCTAssertEqual(summary.gain, -200)
        XCTAssertEqual(try XCTUnwrap(summary.gainPercent), -0.2, accuracy: 0.0001)
    }

    func testWithoutALivePriceTheManualPriceThenTheCostAreUsedAndNoMoveIsMadeUp() throws {
        let manual = Holding(kind: .stock, name: "Privée", symbol: "PRIV", quantity: 4, costBasis: 100, manualPrice: 30)
        let unknown = Holding(kind: .stock, name: "Inconnue", symbol: "NOPE", quantity: 5, costBasis: 100)
        let found = positions([manual, unknown])
        XCTAssertEqual(found[0].price, 30, "The manual price when no live price is known")
        XCTAssertEqual(found[0].value, 120)
        XCTAssertEqual(found[1].price, 20, "Without any price, the cost per unit: neither gain nor loss is invented")
        XCTAssertEqual(found[1].gain, 0)
        let summary = PortfolioMath.summary(found)
        XCTAssertFalse(summary.hasDayChange, "No live change: the day's move says nothing")
        XCTAssertNil(summary.dayChangePercent)
    }

    func testAnEmptyPositionNeverDividesByZero() throws {
        let none = Holding(kind: .stock, name: "Vendue", symbol: "OLD", quantity: 0, costBasis: 0)
        let found = positions([none])
        let position = try XCTUnwrap(found.first)
        XCTAssertEqual(position.price, 0)
        XCTAssertEqual(position.value, 0)
        XCTAssertEqual(position.gain, 0)
        XCTAssertTrue(position.price.isFinite && position.value.isFinite && position.gain.isFinite)
        let summary = PortfolioMath.summary(found)
        XCTAssertNil(summary.gainPercent, "No percentage without a cost")
        XCTAssertTrue(PortfolioMath.allocation(found).isEmpty, "A position worth nothing is not drawn")

        let soldWithCost = Holding(kind: .stock, name: "Vendue", symbol: "OLD", quantity: 0, costBasis: 50)
        XCTAssertEqual(positions([soldWithCost]).first?.gain, -50)
    }

    func testCashCountsAtItsFaceValueAndNeverAsAGain() {
        let cash = Holding(kind: .cash, name: "Compte", symbol: "CAD", quantity: 500, costBasis: 0)
        let stock = Holding(kind: .stock, name: "Apple", symbol: "AAPL", quantity: 10, costBasis: 1_000)
        let summary = PortfolioMath.summary(positions([cash, stock], PriceBook(prices: ["AAPL": 100])))
        XCTAssertEqual(summary.value, 1_500)
        XCTAssertEqual(summary.cost, 1_500, "Cash is worth what it holds: it adds no gain")
        XCTAssertEqual(summary.gain, 0)
    }

    func testAllocationListsOnlyWhatIsHeldBiggestKindsByValue() {
        let found = positions([
            Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 1, costBasis: 100),
            Holding(kind: .stock, name: "Apple", symbol: "AAPL", quantity: 10, costBasis: 100),
        ], PriceBook(prices: ["bitcoin": 300, "AAPL": 10]))
        let allocation = PortfolioMath.allocation(found)
        XCTAssertEqual(Set(allocation.map { $0.kind }), [.stock, .crypto])
        XCTAssertEqual(allocation.first { $0.kind == .crypto }?.value, 300)
        XCTAssertEqual(allocation.first { $0.kind == .stock }?.value, 100)
    }

    func testThePortfolioIsTheSameAfterSavingAndReading() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SharedStore(directory: directory)
        var state = PortfolioState()
        state.holdings = [Holding(kind: .etf, name: "XEQT", symbol: "XEQT", quantity: 12.5, costBasis: 375.25, manualPrice: 31),
                          Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 0.0042, costBasis: 250)]
        state.watchlist = ["bitcoin", "dogecoin"]
        state.history = [ValuePoint(date: Date(timeIntervalSince1970: 1_700_000_000), value: 1_234.5)]
        store.save(state)
        XCTAssertEqual(SharedStore(directory: directory).state(PortfolioState.self), state, "A new launch reads the same portfolio")
        XCTAssertEqual(store.state(PortfolioState.self), state)
    }

    func testAnOlderOrDamagedPortfolioStillOpens() throws {
        let decoder = JSONDecoder()
        let empty = try decoder.decode(PortfolioState.self, from: Data("{}".utf8))
        XCTAssertTrue(empty.holdings.isEmpty)
        XCTAssertEqual(empty.watchlist, ["bitcoin", "ethereum", "solana"], "The default watchlist of a state saved before it existed")
        let onlyHoldings = #"{"holdings":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"stock","name":"Apple","symbol":"AAPL","quantity":2,"costBasis":300}]}"#
        let older = try decoder.decode(PortfolioState.self, from: Data(onlyHoldings.utf8))
        XCTAssertEqual(older.holdings.count, 1)
        XCTAssertNil(older.holdings[0].manualPrice)
        XCTAssertEqual(older.watchlist.count, 3)
        let damaged = try decoder.decode(PortfolioState.self, from: Data(#"{"holdings":"oops","watchlist":7}"#.utf8))
        XCTAssertTrue(damaged.holdings.isEmpty, "A field that cannot be read does not lose the whole portfolio")
        XCTAssertEqual(damaged.watchlist.count, 3)
    }
}
