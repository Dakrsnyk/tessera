import Foundation

/// App-wide identity used for API etiquette (the SEC asks for a contact in the User-Agent).
enum AppInfo {
    static let supportEmail = "support@exemple.com"
    static var userAgent: String { tr("Ardane/1.0 (\(supportEmail))") }
}

struct CompanyRef: Codable, Hashable, Identifiable {
    var cik: Int
    var ticker: String
    var name: String
    var id: Int { cik }

    var paddedCIK: String { String(format: "%010d", cik) }
}

struct FinancialPeriod: Codable, Hashable {
    var label: String
    var end: Date
    var value: Double
}

struct CompanyFinancials: Codable, Hashable {
    var ref: CompanyRef
    var annualRevenue: [FinancialPeriod]
    var quarterlyRevenue: [FinancialPeriod]
    var annualNetIncome: [FinancialPeriod]
    var sharesOutstanding: Double?
    var fetchedAt: Date

    var latestRevenue: FinancialPeriod? { annualRevenue.last }
    var latestNetIncome: FinancialPeriod? { annualNetIncome.last }

    var revenueGrowth: Double? {
        guard annualRevenue.count >= 2 else { return nil }
        return Stats.change(from: annualRevenue[annualRevenue.count - 2].value, to: annualRevenue[annualRevenue.count - 1].value)
    }

    var netMargin: Double? {
        guard let revenue = latestRevenue, let income = annualNetIncome.first(where: { $0.label == revenue.label }), revenue.value != 0 else { return nil }
        return income.value / revenue.value
    }
}

struct MarketsState: Codable, Hashable {
    var followed: [CompanyRef] = [
        CompanyRef(cik: 320193, ticker: "AAPL", name: tr("Apple Inc.")),
        CompanyRef(cik: 1045810, ticker: "NVDA", name: tr("NVIDIA Corp")),
        CompanyRef(cik: 1318605, ticker: "TSLA", name: tr("Tesla, Inc.")),
    ]

    enum CodingKeys: String, CodingKey { case followed }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        followed = c.value(.followed, MarketsState().followed)
    }
}

struct CompanyCache: Codable {
    var companies: [String: CompanyFinancials] = [:]
}

/// Official financial statements from SEC EDGAR (public domain data, no key needed).
/// Covers companies filing with the SEC (US-listed), which includes Apple, Tesla, Nvidia or Amazon.
enum CompanyService {
    static let refreshInterval: TimeInterval = 24 * 3600

    static func cached(_ cik: Int) -> CompanyFinancials? {
        SharedStore.shared.read(CompanyCache.self, from: .companies)?.companies[String(cik)]
    }

    static func financials(_ ref: CompanyRef, allowNetwork: Bool, now: Date = Date()) async -> CompanyFinancials? {
        let cache = cached(ref.cik)
        if let cache, now.timeIntervalSince(cache.fetchedAt) < refreshInterval { return cache }
        guard allowNetwork, let fetched = try? await fetch(ref, now: now) else { return cache }
        var store = SharedStore.shared.read(CompanyCache.self, from: .companies) ?? CompanyCache()
        store.companies[String(ref.cik)] = fetched
        SharedStore.shared.write(store, to: .companies)
        return fetched
    }

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private struct Concept: Decodable {
        struct Fact: Decodable {
            let end: String
            let val: Double
            let form: String?
            let frame: String?
        }
        let units: [String: [Fact]]
    }

    private static func concept(_ cik: String, taxonomy: String, tag: String) async -> [Concept.Fact] {
        guard let url = URL(string: "https://data.sec.gov/api/xbrl/companyconcept/CIK\(cik)/\(taxonomy)/\(tag).json"),
              let (data, response) = try? await URLSession.shared.data(for: request(url)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let concept = try? JSONDecoder().decode(Concept.self, from: data) else { return [] }
        return concept.units.values.first ?? []
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Keeps de-duplicated calendar frames: "CY2023" for years, "CY2024Q1" for quarters.
    private static func periods(_ facts: [Concept.Fact], quarterly: Bool) -> [FinancialPeriod] {
        var byLabel: [String: FinancialPeriod] = [:]
        for fact in facts {
            guard let frame = fact.frame, frame.hasPrefix("CY"), !frame.hasSuffix("I") else { continue }
            let isQuarter = frame.contains("Q")
            guard isQuarter == quarterly, let end = dayFormatter.date(from: fact.end) else { continue }
            let label = quarterly
                ? "T\(frame.suffix(1)) \(frame.dropFirst(2).prefix(4))"
                : String(frame.dropFirst(2))
            byLabel[label] = FinancialPeriod(label: label, end: end, value: fact.val)
        }
        return byLabel.values.sorted { $0.end < $1.end }
    }

    static func fetch(_ ref: CompanyRef, now: Date) async throws -> CompanyFinancials {
        let cik = ref.paddedCIK
        var bestAnnual: [FinancialPeriod] = []
        var bestQuarterly: [FinancialPeriod] = []
        for tag in ["RevenueFromContractWithCustomerExcludingAssessedTax", tr("Revenues"), "SalesRevenueNet", "RevenueFromContractWithCustomerIncludingAssessedTax"] {
            let facts = await concept(cik, taxonomy: "us-gaap", tag: tag)
            let annual = periods(facts, quarterly: false)
            if let last = annual.last, last.end > (bestAnnual.last?.end ?? .distantPast) {
                bestAnnual = annual
                bestQuarterly = periods(facts, quarterly: true)
            }
        }
        guard !bestAnnual.isEmpty else { throw WeatherError.decoding }
        let income = periods(await concept(cik, taxonomy: "us-gaap", tag: "NetIncomeLoss"), quarterly: false)
        let shares = await concept(cik, taxonomy: "dei", tag: "EntityCommonStockSharesOutstanding")
            .sorted { $0.end < $1.end }.last?.val
        return CompanyFinancials(
            ref: ref,
            annualRevenue: Array(bestAnnual.suffix(6)),
            quarterlyRevenue: Array(bestQuarterly.suffix(8)),
            annualNetIncome: Array(income.suffix(6)),
            sharesOutstanding: shares,
            fetchedAt: now
        )
    }

    // MARK: Search (app only; the ticker list is large)

    private struct TickerRow: Decodable {
        let cik_str: Int
        let ticker: String
        let title: String
    }

    private static var tickerFile: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("sec_tickers.json")
    }

    static func search(_ query: String) async throws -> [CompanyRef] {
        let q = query.trimmed.lowercased()
        guard q.count >= 1 else { return [] }
        let data: Data
        if let cached = try? Data(contentsOf: tickerFile),
           let attributes = try? FileManager.default.attributesOfItem(atPath: tickerFile.path),
           let modified = attributes[.modificationDate] as? Date, Date().timeIntervalSince(modified) < 7 * 86_400 {
            data = cached
        } else {
            let (fresh, response) = try await URLSession.shared.data(for: request(URL(string: "https://www.sec.gov/files/company_tickers.json")!))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
            try? fresh.write(to: tickerFile)
            data = fresh
        }
        let rows = try JSONDecoder().decode([String: TickerRow].self, from: data).values
        let matches = rows.filter { $0.ticker.lowercased() == q || $0.ticker.lowercased().hasPrefix(q) || $0.title.lowercased().contains(q) }
        return matches
            .sorted { lhs, rhs in
                let lExact = lhs.ticker.lowercased() == q, rExact = rhs.ticker.lowercased() == q
                if lExact != rExact { return lExact }
                return lhs.title.count < rhs.title.count
            }
            .prefix(25)
            .map { CompanyRef(cik: $0.cik_str, ticker: $0.ticker, name: $0.title) }
    }
}

enum BigNumber {
    /// "383,3 G$" / "12,4 M$" style compact amounts for financial statements.
    static func compact(_ value: Double, currency: String = "USD") -> String {
        let magnitude = abs(value)
        var divisor = 1.0
        var suffix = ""
        if magnitude >= 1e12 {
            divisor = 1e12; suffix = " T"
        } else if magnitude >= 1e9 {
            divisor = 1e9; suffix = " G"
        } else if magnitude >= 1e6 {
            divisor = 1e6; suffix = " M"
        } else if magnitude >= 1e3 {
            divisor = 1e3; suffix = " k"
        }
        let number = value / divisor
        let formatter = NumberFormatter()
        formatter.locale = Fmt.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(number) >= 100 ? 0 : 1
        let text = formatter.string(from: NSNumber(value: number)) ?? "\(number)"
        let symbol = currency == "USD" ? tr("$ US") : currency == "EUR" ? "€" : "$"
        // "416 G$ US", "12,4 M€", but "950 $ US".
        return suffix.isEmpty ? "\(text) \(symbol)" : "\(text)\(suffix)\(symbol)"
    }
}
