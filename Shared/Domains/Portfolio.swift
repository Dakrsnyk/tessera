import Foundation

enum AssetKind: String, Codable, CaseIterable, Identifiable {
    case stock, etf, crypto, cash
    var id: String { rawValue }

    var title: String {
        switch self {
        case .stock: "Actions"
        case .etf: "ETF"
        case .crypto: "Crypto"
        case .cash: "Liquidités"
        }
    }

    var colorHex: String {
        switch self {
        case .stock: "3366FF"
        case .etf: "1E9E75"
        case .crypto: "F2A33A"
        case .cash: "8A94A6"
        }
    }
}

struct Holding: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: AssetKind
    var name: String
    /// Ticker for stocks and ETFs, CoinGecko id for crypto.
    var symbol: String
    var quantity: Double
    /// Total amount paid, in the portfolio currency.
    var costBasis: Double
    /// Used when no live price is available (stocks without a data key, or cash).
    var manualPrice: Double?
}

struct PortfolioState: Codable, Hashable {
    var holdings: [Holding] = []
    var watchlist: [String] = ["bitcoin", "ethereum", "solana"]
    var history: [ValuePoint] = []

    enum CodingKeys: String, CodingKey { case holdings, watchlist, history }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        holdings = c.value(.holdings, [])
        watchlist = c.value(.watchlist, ["bitcoin", "ethereum", "solana"])
        history = c.value(.history, [])
    }
}

/// Live prices known for the holdings, keyed by symbol.
struct PriceBook: Hashable {
    var prices: [String: Double] = [:]
    var changes: [String: Double] = [:]
}

enum PortfolioMath {
    struct Position: Hashable {
        let holding: Holding
        let price: Double
        let value: Double
        let gain: Double
        let change24h: Double?
    }

    static func positions(_ state: PortfolioState, prices: PriceBook) -> [Position] {
        state.holdings.map { holding in
            let price: Double
            if holding.kind == .cash {
                price = 1
            } else {
                price = prices.prices[holding.symbol] ?? holding.manualPrice ?? (holding.quantity > 0 ? holding.costBasis / holding.quantity : 0)
            }
            let value = holding.kind == .cash ? holding.quantity : price * holding.quantity
            return Position(holding: holding, price: price, value: value, gain: value - holding.costBasis, change24h: prices.changes[holding.symbol])
        }
    }

    struct Summary: Hashable {
        let value: Double
        let cost: Double
        let dayChange: Double
        var gain: Double { value - cost }
        var gainPercent: Double? { cost > 0 ? gain / cost : nil }
    }

    static func summary(_ positions: [Position]) -> Summary {
        let value = positions.reduce(0) { $0 + $1.value }
        let cost = positions.reduce(0) { $0 + ($1.holding.kind == .cash ? $1.value : $1.holding.costBasis) }
        let dayChange = positions.reduce(0.0) { total, position in
            guard let change = position.change24h else { return total }
            let previous = position.value / (1 + change / 100)
            return total + (position.value - previous)
        }
        return Summary(value: value, cost: cost, dayChange: dayChange)
    }

    static func allocation(_ positions: [Position]) -> [(kind: AssetKind, value: Double)] {
        AssetKind.allCases.compactMap { kind -> (kind: AssetKind, value: Double)? in
            let value = positions.filter { $0.holding.kind == kind }.reduce(0) { $0 + $1.value }
            return value > 0 ? (kind, value) : nil
        }
    }

    static func topMover(_ positions: [Position]) -> Position? {
        positions.filter { $0.change24h != nil }.max { abs($0.change24h ?? 0) < abs($1.change24h ?? 0) }
    }
}

/// Crypto market data beyond a single coin: several coins at once and the global market.
struct CoinQuote: Codable, Hashable {
    var id: String
    var symbol: String
    var name: String
    var price: Double
    var change24h: Double
}

struct MarketGlobal: Codable, Hashable {
    var totalMarketCap: Double
    var change24h: Double
    var bitcoinDominance: Double
    var ethereumDominance: Double
    var fetchedAt: Date
}

struct MarketCache: Codable {
    var quotes: [String: CoinQuote] = [:]
    var currency = "usd"
    var quotesFetchedAt: Date?
    var global: MarketGlobal?
    var stocks: [String: StockQuote] = [:]
}

struct StockQuote: Codable, Hashable {
    var symbol: String
    var price: Double
    var changePercent: Double
    var fetchedAt: Date
}

enum MarketService {
    static let refreshInterval: TimeInterval = 15 * 60

    static var cache: MarketCache {
        SharedStore.shared.read(MarketCache.self, from: .markets) ?? MarketCache()
    }

    /// Prices for a set of CoinGecko ids, from cache when fresh.
    static func coinQuotes(_ ids: [String], allowNetwork: Bool, now: Date = Date()) async -> [CoinQuote] {
        let wanted = Array(Set(ids)).sorted()
        guard !wanted.isEmpty else { return [] }
        var stored = cache
        let currency = SharedStore.shared.settings.cryptoCurrency
        let fresh = stored.currency == currency
            && (stored.quotesFetchedAt.map { now.timeIntervalSince($0) < refreshInterval } ?? false)
            && wanted.allSatisfy { stored.quotes[$0] != nil }
        if !fresh, allowNetwork, let fetched = try? await fetchQuotes(wanted, currency: currency) {
            if stored.currency != currency { stored.quotes = [:] }
            for quote in fetched { stored.quotes[quote.id] = quote }
            stored.currency = currency
            stored.quotesFetchedAt = now
            SharedStore.shared.write(stored, to: .markets)
        }
        return ids.compactMap { stored.quotes[$0] }
    }

    static func global(allowNetwork: Bool, now: Date = Date()) async -> MarketGlobal? {
        var stored = cache
        if let global = stored.global, now.timeIntervalSince(global.fetchedAt) < refreshInterval { return global }
        guard allowNetwork, let fetched = try? await fetchGlobal(now: now) else { return stored.global }
        stored.global = fetched
        SharedStore.shared.write(stored, to: .markets)
        return fetched
    }

    /// Stock quotes need a Finnhub key (FINNHUB_API_KEY). Without it, stocks use their manual price.
    static var stockKey: String? {
        (Bundle.main.object(forInfoDictionaryKey: "FinnhubAPIKey") as? String)?.trimmed.nonEmpty
    }

    static func stockQuotes(_ symbols: [String], allowNetwork: Bool, now: Date = Date()) async -> [String: StockQuote] {
        var stored = cache
        var result: [String: StockQuote] = [:]
        for symbol in Set(symbols) {
            if let quote = stored.stocks[symbol], now.timeIntervalSince(quote.fetchedAt) < refreshInterval {
                result[symbol] = quote
                continue
            }
            if allowNetwork, let key = stockKey, let quote = try? await fetchStock(symbol, key: key, now: now) {
                stored.stocks[symbol] = quote
                result[symbol] = quote
            } else if let quote = stored.stocks[symbol] {
                result[symbol] = quote
            }
        }
        SharedStore.shared.write(stored, to: .markets)
        return result
    }

    static func priceBook(for state: PortfolioState, allowNetwork: Bool) async -> PriceBook {
        var book = PriceBook()
        let coinIDs = state.holdings.filter { $0.kind == .crypto }.map(\.symbol)
        for quote in await coinQuotes(coinIDs, allowNetwork: allowNetwork) {
            book.prices[quote.id] = quote.price
            book.changes[quote.id] = quote.change24h
        }
        let tickers = state.holdings.filter { $0.kind == .stock || $0.kind == .etf }.map(\.symbol)
        for (symbol, quote) in await stockQuotes(tickers, allowNetwork: allowNetwork) {
            book.prices[symbol] = quote.price
            book.changes[symbol] = quote.changePercent
        }
        return book
    }

    // MARK: Network

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = (Bundle.main.object(forInfoDictionaryKey: "CoinGeckoAPIKey") as? String)?.trimmed.nonEmpty {
            request.setValue(key, forHTTPHeaderField: "x-cg-demo-api-key")
        }
        return request
    }

    private static func fetchQuotes(_ ids: [String], currency: String) async throws -> [CoinQuote] {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
        ]
        let (data, response) = try await URLSession.shared.data(for: request(components.url!))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
        struct Row: Decodable {
            let id: String
            let symbol: String
            let name: String
            let current_price: Double?
            let price_change_percentage_24h: Double?
        }
        return try JSONDecoder().decode([Row].self, from: data).map {
            CoinQuote(id: $0.id, symbol: $0.symbol.uppercased(), name: $0.name, price: $0.current_price ?? 0, change24h: $0.price_change_percentage_24h ?? 0)
        }
    }

    private static func fetchGlobal(now: Date) async throws -> MarketGlobal {
        let (data, response) = try await URLSession.shared.data(for: request(URL(string: "https://api.coingecko.com/api/v3/global")!))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
        struct Payload: Decodable {
            struct Inner: Decodable {
                let total_market_cap: [String: Double]
                let market_cap_percentage: [String: Double]
                let market_cap_change_percentage_24h_usd: Double
            }
            let data: Inner
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data).data
        let currency = SharedStore.shared.settings.cryptoCurrency
        return MarketGlobal(
            totalMarketCap: payload.total_market_cap[currency] ?? payload.total_market_cap["usd"] ?? 0,
            change24h: payload.market_cap_change_percentage_24h_usd,
            bitcoinDominance: payload.market_cap_percentage["btc"] ?? 0,
            ethereumDominance: payload.market_cap_percentage["eth"] ?? 0,
            fetchedAt: now
        )
    }

    private static func fetchStock(_ symbol: String, key: String, now: Date) async throws -> StockQuote {
        var components = URLComponents(string: "https://finnhub.io/api/v1/quote")!
        components.queryItems = [URLQueryItem(name: "symbol", value: symbol), URLQueryItem(name: "token", value: key)]
        var req = URLRequest(url: components.url!)
        req.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
        struct Quote: Decodable { let c: Double; let dp: Double? }
        let quote = try JSONDecoder().decode(Quote.self, from: data)
        guard quote.c > 0 else { throw WeatherError.decoding }
        return StockQuote(symbol: symbol, price: quote.c, changePercent: quote.dp ?? 0, fetchedAt: now)
    }
}
