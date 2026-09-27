import Foundation

struct CoinInfo: Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String
}

struct CoinSnapshot: Codable, Hashable {
    var id: String
    var symbol: String
    var name: String
    var currency: String
    var price: Double
    var change24h: Double
    /// Last 7 days, downsampled for drawing.
    var sparkline: [Double]
    var fetchedAt: Date
}

struct CryptoCache: Codable {
    var coins: [String: CoinSnapshot] = [:]
}

enum CryptoResult: Hashable {
    case ready(CoinSnapshot)
    case unavailable(CoinSnapshot?)
}

/// Market data from CoinGecko's public API. An optional demo key (COINGECKO_API_KEY) raises the rate limit.
enum CryptoService {
    static let refreshInterval: TimeInterval = 15 * 60

    static let coins: [CoinInfo] = [
        CoinInfo(id: "bitcoin", symbol: "BTC", name: "Bitcoin"),
        CoinInfo(id: "ethereum", symbol: "ETH", name: "Ethereum"),
        CoinInfo(id: "solana", symbol: "SOL", name: "Solana"),
        CoinInfo(id: "ripple", symbol: "XRP", name: "XRP"),
        CoinInfo(id: "cardano", symbol: "ADA", name: "Cardano"),
        CoinInfo(id: "dogecoin", symbol: "DOGE", name: "Dogecoin"),
        CoinInfo(id: "litecoin", symbol: "LTC", name: "Litecoin"),
        CoinInfo(id: "polkadot", symbol: "DOT", name: "Polkadot"),
    ]

    static func info(_ id: String) -> CoinInfo {
        coins.first { $0.id == id } ?? coins[0]
    }

    private static func cacheKey(_ id: String, _ currency: String) -> String { "\(id)-\(currency)" }

    static func cached(_ id: String, currency: String) -> CoinSnapshot? {
        SharedStore.shared.read(CryptoCache.self, from: .crypto)?.coins[cacheKey(id, currency)]
    }

    static func load(coinID: String, allowNetwork: Bool, now: Date = Date()) async -> CryptoResult {
        let currency = SharedStore.shared.settings.cryptoCurrency
        let cache = cached(coinID, currency: currency)
        if let cache, now.timeIntervalSince(cache.fetchedAt) < refreshInterval {
            return .ready(cache)
        }
        guard allowNetwork else {
            if let cache { return .ready(cache) }
            return .unavailable(nil)
        }
        do {
            let snapshot = try await fetch(coinID: coinID, currency: currency)
            var store = SharedStore.shared.read(CryptoCache.self, from: .crypto) ?? CryptoCache()
            store.coins[cacheKey(coinID, currency)] = snapshot
            SharedStore.shared.write(store, to: .crypto)
            return .ready(snapshot)
        } catch {
            return .unavailable(cache)
        }
    }

    static func fetch(coinID: String, currency: String) async throws -> CoinSnapshot {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "ids", value: coinID),
            URLQueryItem(name: "sparkline", value: "true"),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = (Bundle.main.object(forInfoDictionaryKey: "CoinGeckoAPIKey") as? String)?.trimmed.nonEmpty {
            request.setValue(key, forHTTPHeaderField: "x-cg-demo-api-key")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherError.badResponse
        }
        let markets = try JSONDecoder().decode([Market].self, from: data)
        guard let market = markets.first else { throw WeatherError.decoding }
        let coin = Self.info(coinID)
        return CoinSnapshot(
            id: coinID,
            symbol: coin.symbol,
            name: coin.name,
            currency: currency.uppercased(),
            price: market.current_price ?? 0,
            change24h: market.price_change_percentage_24h ?? 0,
            sparkline: downsample(market.sparkline_in_7d?.price ?? [], to: 56),
            fetchedAt: Date()
        )
    }

    static func downsample(_ values: [Double], to count: Int) -> [Double] {
        guard values.count > count, count > 1 else { return values }
        let step = Double(values.count - 1) / Double(count - 1)
        return (0..<count).map { values[Int((Double($0) * step).rounded())] }
    }

    private struct Market: Decodable {
        struct Sparkline: Decodable { let price: [Double] }
        let current_price: Double?
        let price_change_percentage_24h: Double?
        let sparkline_in_7d: Sparkline?
    }
}
