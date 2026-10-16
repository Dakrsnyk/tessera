import Foundation

// Sales, refunds and costs that come from elsewhere than the person's hands: a connected service
// (Stripe, read-only) or a file exported from one (Stripe, Shopify, a bank, a spreadsheet). Each entry
// keeps where it came from and its id there, so a second sync or the same file imported again never adds
// it twice: it is updated in place instead.

/// Where an entry of Business came from.
enum BusinessSource: String, Codable, CaseIterable {
    case stripe, csv

    var title: String {
        switch self {
        case .stripe: "Stripe"
        case .csv: tr("Fichier importé")
        }
    }
}

/// A batch of entries read from a service or a file, before it is merged.
struct BusinessBatch: Hashable {
    var sales: [SalesEntry] = []
    var expenses: [BusinessExpense] = []
    /// Lines of the file that couldn't be read (no date or no amount), or were left out (failed payments).
    var skipped = 0
    /// The currencies met (lowercase ISO codes), to warn when they differ from the app's.
    var currencies: Set<String> = []
    /// The currency of each entry whose line said it (`importKey` → « USD »), to convert it
    /// (`converted(with:)`). An entry without one is in the app's currency.
    var entryCurrencies: [String: String] = [:]
    /// Currencies whose amounts couldn't be converted for lack of a rate: they are still as they came, so
    /// the batch is merged only if the person chooses to keep them that way.
    var unconverted: Set<String> = []
}

/// What a merge did.
struct BusinessMergeResult: Hashable {
    var added = 0
    var updated = 0
    var unchanged = 0
}

/// The connections and imports of Business, with what happened last.
struct BusinessConnections: Codable, Hashable {
    /// Stripe, connected with a restricted read-only key kept in the iPhone's keychain (never here).
    var stripe: StripeLink?
    var lastImport: ImportRecord?

    struct StripeLink: Codable, Hashable {
        /// The end of the key (« …a1B2 »), to recognize it; the key itself is in the keychain only.
        var keyHint: String
        var isTestMode: Bool
        var connectedAt: Date
        var lastSync: Date?
        /// The time of the newest transaction read: the next sync starts a little before it.
        var syncedUntil: Date?
        var lastError: String?
        var lastResult: BusinessMergeResult?
        /// The last sync stopped for lack of exchange rates for these currencies: the card offers to sync
        /// without conversion.
        var unconvertedCurrencies: [String]?
        /// The currencies Stripe's amounts were converted from, at the ECB rate of their day.
        var convertedCurrencies: [String]?
        /// Currencies the ECB doesn't publish that the person chose to keep as Stripe gives them: the next
        /// syncs keep them too.
        var keptCurrencies: [String]?
    }

    struct ImportRecord: Codable, Hashable {
        var fileName: String
        var date: Date
        var result: BusinessMergeResult
        var skipped: Int
    }
}

extension BusinessMergeResult: Codable {}

extension BusinessState {
    /// Adds the entries of a batch, or updates the ones already there (same source, same id). Entries typed
    /// by hand are never touched.
    @discardableResult
    mutating func merge(_ batch: BusinessBatch) -> BusinessMergeResult {
        var result = BusinessMergeResult()
        var saleIndex: [String: Int] = [:]
        for (index, sale) in sales.enumerated() { if let key = sale.importKey { saleIndex[key] = index } }
        for sale in batch.sales {
            guard let key = sale.importKey else { continue }
            if let index = saleIndex[key] {
                var updated = sale
                updated.id = sales[index].id
                if sales[index] == updated { result.unchanged += 1 } else { sales[index] = updated; result.updated += 1 }
            } else {
                saleIndex[key] = sales.count
                sales.append(sale)
                result.added += 1
            }
        }
        var costIndex: [String: Int] = [:]
        for (index, cost) in expenses.enumerated() { if let key = cost.importKey { costIndex[key] = index } }
        for cost in batch.expenses {
            guard let key = cost.importKey else { continue }
            if let index = costIndex[key] {
                var updated = cost
                updated.id = expenses[index].id
                if expenses[index] == updated { result.unchanged += 1 } else { expenses[index] = updated; result.updated += 1 }
            } else {
                costIndex[key] = expenses.count
                expenses.append(cost)
                result.added += 1
            }
        }
        sales.sort { $0.date < $1.date }
        expenses.sort { $0.date < $1.date }
        return result
    }

    /// Takes off everything a source brought (when the person disconnects it and asks for it).
    mutating func removeEntries(from source: BusinessSource) {
        sales.removeAll { $0.source == source.rawValue }
        expenses.removeAll { $0.source == source.rawValue }
    }
}

extension SalesEntry {
    /// « stripe:txn_123 »: the same entry on every sync. Nil for an entry typed by hand.
    var importKey: String? {
        guard let source, let externalID else { return nil }
        return "\(source):\(externalID)"
    }
}

extension BusinessExpense {
    var importKey: String? {
        guard let source, let externalID else { return nil }
        return "\(source):\(externalID)"
    }
}

// MARK: - Files (CSV)

/// Reads a sales export: Stripe (payments or balance), Shopify (orders), a bank or a spreadsheet with a
/// date and an amount. Paid sales become sales, refunds negative sales, fees and negative amounts costs;
/// failed or cancelled payments and payouts are left out. Nothing is guessed when a line lacks its date
/// or its amount: it is counted as skipped.
enum BusinessCSV {
    enum ImportError: Error, Equatable {
        case empty
        /// No column that reads as a date, or none as an amount.
        case missingColumns
    }

    static func parse(_ text: String) throws -> BusinessBatch {
        let rows = table(text)
        guard let header = rows.first, rows.count > 1 else { throw ImportError.empty }
        let names = header.map(normalized)
        func column(_ candidates: [String]) -> Int? {
            for candidate in candidates { if let index = names.firstIndex(of: candidate) { return index } }
            for candidate in candidates { if let index = names.firstIndex(where: { $0.hasPrefix(candidate) }) { return index } }
            return nil
        }
        guard let dateColumn = column(["created date (utc)", "created (utc)", "created at", "paid at", "processed at", "transaction date",
                                        "date de creation", "date", "created", "jour"]),
              let amountColumn = column(["amount", "total", "gross", "montant", "net", "total amount", "prix", "price", "credit"]) else {
            throw ImportError.missingColumns
        }
        let idColumn = column(["id", "transaction id", "charge id", "order id", "name", "numero", "reference", "ref"])
        let typeColumn = column(["type", "reporting category"])
        let statusColumn = column(["status", "financial status", "statut", "etat"])
        let feeColumn = column(["fee", "fees", "frais"])
        let refundedColumn = column(["amount refunded", "refunded amount", "montant rembourse"])
        let labelColumn = column(["description", "libelle", "note", "title", "lineitem name", "produit"])
        let currencyColumn = column(["currency", "devise"])

        // Stripe writes its times in UTC without saying it in the cell (only in the column's name).
        let isUTC = names[dateColumn].contains("utc")
        var batch = BusinessBatch()
        var seen = Set<String>()
        for row in rows.dropFirst() where row.contains(where: { !$0.trimmed.isEmpty }) {
            func value(_ index: Int?) -> String { index.flatMap { row[safe: $0] }?.trimmed ?? "" }
            guard let when = date(value(dateColumn), utc: isUTC), let total = amount(value(amountColumn)) else {
                batch.skipped += 1
                continue
            }
            let type = normalized(value(typeColumn))
            let status = normalized(value(statusColumn))
            if ["failed", "canceled", "cancelled", "voided", "expired", "echoue", "annule"].contains(status)
                || ["payout", "transfer", "virement"].contains(type) {
                batch.skipped += 1
                continue
            }
            let label = value(labelColumn)
            let rawID = value(idColumn)
            // Without an id, the line itself is its id: the same file imported twice adds nothing.
            let id = rawID.isEmpty ? fingerprint([DateMath.dayKey(when), String(format: "%.2f", total), label]) : rawID
            // Shopify writes one line per item of an order: its total is on the first one only.
            guard seen.insert(id).inserted else { continue }
            let currency = value(currencyColumn).lowercased()
            if !currency.isEmpty { batch.currencies.insert(currency) }
            // Kept as the file gives them; converted afterwards with the rates of their days.
            let code = currency.uppercased()
            func addSale(_ sale: SalesEntry) {
                batch.sales.append(sale)
                if !code.isEmpty, let key = sale.importKey { batch.entryCurrencies[key] = code }
            }
            func addCost(_ cost: BusinessExpense) {
                batch.expenses.append(cost)
                if !code.isEmpty, let key = cost.importKey { batch.entryCurrencies[key] = code }
            }

            let isRefund = type.contains("refund") || type.contains("rembours") || (status == "refunded" && total < 0)
            if type.contains("fee") || type.contains("frais") || (total < 0 && !isRefund && type.isEmpty) {
                addCost(BusinessExpense(date: when, amount: abs(total), label: label.isEmpty ? tr("Dépense importée") : label,
                                        source: BusinessSource.csv.rawValue, externalID: id))
                continue
            }
            if isRefund {
                addSale(SalesEntry(date: when, amount: -abs(total), orders: 0, note: label.isEmpty ? tr("Remboursement") : label,
                                   source: BusinessSource.csv.rawValue, externalID: id))
                continue
            }
            // Refunded in full, without the refunded amount in the file (Shopify): no sale left.
            if status == "refunded", refundedColumn == nil, total > 0 {
                batch.skipped += 1
                continue
            }
            let refunded = amount(value(refundedColumn)) ?? 0
            addSale(SalesEntry(date: when, amount: total - abs(refunded), orders: 1, note: label,
                               source: BusinessSource.csv.rawValue, externalID: id))
            if let fee = amount(value(feeColumn)), fee != 0 {
                addCost(BusinessExpense(date: when, amount: abs(fee), label: tr("Frais de paiement"),
                                        source: BusinessSource.csv.rawValue, externalID: "\(id)-fee"))
            }
        }
        return batch
    }

    // MARK: Reading

    /// The cells of a CSV file: commas, semicolons or tabs, quoted cells with commas, quotes and line breaks.
    static func table(_ text: String) -> [[String]] {
        let body = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let firstLine = body.prefix { $0 != "\n" && $0 != "\r" }
        let counts: [(Character, Int)] = [";", "\t", ","].map { candidate in (candidate, firstLine.filter { $0 == candidate }.count) }
        let best = counts.max { $0.1 < $1.1 }
        let delimiter: Character = (best?.1 ?? 0) > 0 ? (best?.0 ?? ",") : ","
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var quoted = false
        var iterator = Array(body).makeIterator()
        var pending: Character?
        while let char = pending ?? iterator.next() {
            pending = nil
            if quoted {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { cell.append("\"") } else { quoted = false; pending = next }
                    } else {
                        quoted = false
                    }
                } else {
                    cell.append(char)
                }
            } else if char == "\"" {
                quoted = true
            } else if char == delimiter {
                row.append(cell)
                cell = ""
            } else if char == "\n" || char == "\r" || char == "\r\n" {
                row.append(cell)
                rows.append(row)
                row = []
                cell = ""
            } else {
                cell.append(char)
            }
        }
        if !cell.isEmpty || !row.isEmpty {
            row.append(cell)
            rows.append(row)
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }

    static func normalized(_ text: String) -> String {
        text.trimmed.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// « 1 234,56 $ », « $1,234.56 », « -12.00 », « (12.00) »: the number, the decimal mark being the last
    /// one when both are there.
    static func amount(_ text: String) -> Double? {
        var cleaned = text.trimmed
        guard !cleaned.isEmpty else { return nil }
        let negative = cleaned.hasPrefix("-") || cleaned.hasPrefix("−") || (cleaned.hasPrefix("(") && cleaned.hasSuffix(")"))
        cleaned = String(cleaned.filter { $0.isNumber || $0 == "," || $0 == "." })
        guard !cleaned.isEmpty else { return nil }
        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")
        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            if comma > dot {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        case let (comma?, nil):
            let decimals = cleaned.distance(from: comma, to: cleaned.endIndex) - 1
            let commas = cleaned.filter { $0 == "," }.count
            cleaned = commas == 1 && decimals <= 2 ? cleaned.replacingOccurrences(of: ",", with: ".") : cleaned.replacingOccurrences(of: ",", with: "")
        default:
            break
        }
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return negative ? -value : value
    }

    private static let dateFormats = [
        "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "dd/MM/yyyy HH:mm", "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
        "MM/dd/yyyy HH:mm", "MM/dd/yyyy",
    ]

    /// The dates of exports: ISO (with or without time zone), « 2026-10-01 10:12:13 -0400 » (Shopify),
    /// day/month/year (then month/day/year when the day can't be a month).
    /// `utc`: a time without its zone is in UTC (Stripe's « Created date (UTC) »), else in the iPhone's.
    static func date(_ text: String, utc: Bool = false) -> Date? {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc ? TimeZone(identifier: "UTC") : Fmt.timeZone
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// A short stable id for a line that has none.
    static func fingerprint(_ parts: [String]) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in parts.joined(separator: "|").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return "line-" + String(hash, radix: 36)
    }
}

// MARK: - Stripe

/// Stripe's balance transactions (GET /v1/balance_transactions), read with a restricted key that can only
/// read them: payments become sales, refunds negative sales, Stripe's fees one cost a day; payouts to the
/// bank and transfers are left out (they move money that was already counted).
enum StripeTransactions {
    struct Page: Decodable {
        let data: [Transaction]
        let hasMore: Bool

        enum CodingKeys: String, CodingKey { case data, hasMore = "has_more" }
    }

    struct Transaction: Decodable, Hashable {
        let id: String
        let amount: Int
        let fee: Int
        let created: TimeInterval
        let currency: String
        let type: String
        let description: String?
    }

    /// Currencies Stripe counts without cents (an amount of 500 JPY is 500, not 5,00).
    static let zeroDecimal: Set<String> = ["bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga", "pyg", "rwf", "ugx", "vnd", "vuv", "xaf", "xof", "xpf"]

    static func units(_ amount: Int, _ currency: String) -> Double {
        zeroDecimal.contains(currency.lowercased()) ? Double(amount) : Double(amount) / 100
    }

    /// The transactions as sales and costs. With `history`, an amount in another currency than the app's is
    /// converted at the rate of its day (each payment, refund and fee, before the fees are added up by day);
    /// without a rate it stays as it was and its currency goes in `unconverted`.
    static func batch(from transactions: [Transaction], history: FXHistory? = nil) -> BusinessBatch {
        var batch = BusinessBatch()
        var feesByDay: [String: (date: Date, byCurrency: [String: Double])] = [:]
        var unconverted = Set<String>()
        let source = BusinessSource.stripe.rawValue
        func money(_ value: Double, _ currency: String, on date: Date) -> (amount: Double, original: ForeignAmount?) {
            guard let history else { return (value, nil) }
            if let converted = CurrencyConversion.convert(value, currency, on: date, with: history) { return converted }
            unconverted.insert(currency.uppercased())
            return (value, nil)
        }
        func addFee(_ value: Double, _ currency: String, on date: Date) {
            let key = DateMath.dayKey(date)
            var day = feesByDay[key] ?? (date: date, byCurrency: [:])
            day.byCurrency[currency, default: 0] += value
            feesByDay[key] = day
        }
        for transaction in transactions {
            let date = Date(timeIntervalSince1970: transaction.created)
            let currency = transaction.currency.lowercased()
            let value = units(transaction.amount, currency)
            batch.currencies.insert(currency)
            switch transaction.type {
            case "charge", "payment":
                let sale = money(value, currency, on: date)
                batch.sales.append(SalesEntry(date: date, amount: sale.amount, orders: 1, note: transaction.description ?? "",
                                              source: source, externalID: transaction.id, original: sale.original))
            case "refund", "payment_refund", "payment_failure_refund":
                let refund = money(-abs(value), currency, on: date)
                batch.sales.append(SalesEntry(date: date, amount: refund.amount, orders: 0, note: transaction.description ?? tr("Remboursement"),
                                              source: source, externalID: transaction.id, original: refund.original))
            case "stripe_fee", "tax_fee", "application_fee":
                addFee(abs(value), currency, on: date)
                continue
            default:
                batch.skipped += 1
            }
            // The fee taken on a payment or a refund.
            if transaction.fee != 0 {
                addFee(units(transaction.fee, currency), currency, on: date)
            }
        }
        for (key, fee) in feesByDay {
            // One cost a day, whatever the currencies: its original amount is kept when there is a single one.
            let parts = fee.byCurrency.filter { $0.value != 0 }.sorted { $0.key < $1.key }
            var total = 0.0
            var originals: [ForeignAmount] = []
            for part in parts {
                let converted = money(part.value, part.key, on: fee.date)
                total += converted.amount
                if let original = converted.original { originals.append(original) }
            }
            guard total != 0 else { continue }
            let amount = history.map { CurrencyConversion.rounded(total, in: $0.home) } ?? total
            batch.expenses.append(BusinessExpense(date: fee.date, amount: amount, label: tr("Frais Stripe"), source: source, externalID: "fees-\(key)",
                                                  original: parts.count == 1 ? originals.first : nil))
        }
        batch.unconverted = unconverted
        return batch
    }
}

// MARK: - Currencies

/// Amounts in another currency than the app's, brought into it at the reference rate of the European
/// Central Bank of their own day (or of the business day before: no rate on weekends and holidays), rounded
/// to the cent. What the file or Stripe said is kept on the entry (`ForeignAmount`). Without a rate nothing
/// is guessed: the amount stays as it came and the person is told.
enum CurrencyConversion {
    /// To the cent; to the unit for currencies without cents (yen, won).
    static func rounded(_ value: Double, in currency: String) -> Double {
        let factor = StripeTransactions.zeroDecimal.contains(currency.lowercased()) ? 1.0 : 100.0
        return (value * factor).rounded() / factor
    }

    /// `amount` of `currency` on `date` in the history's currency, with what it was (nil when it was
    /// already in it). Nil without a rate for that day or the week before.
    static func convert(_ amount: Double, _ currency: String, on date: Date, with history: FXHistory) -> (amount: Double, original: ForeignAmount?)? {
        let code = currency.uppercased()
        if code.isEmpty || code == history.home.uppercased() { return (amount, nil) }
        guard let rate = history.rate(code, on: DateMath.dayKey(date)) else { return nil }
        return (rounded(amount * rate.value, in: history.home), ForeignAmount(amount: amount, currency: code, rate: rate.value, rateDay: rate.day))
    }

    /// The rates a file needs, for its whole period: one request per currency.
    static func rates(for batch: BusinessBatch, home: String, now: Date = Date()) async -> FXHistory {
        let foreign = batch.foreignCurrencies(home: home)
        guard !foreign.isEmpty, let period = batch.period else { return FXHistory(home: home.uppercased()) }
        return await FXService.history(of: foreign, in: home, from: period.lowerBound, to: period.upperBound, now: now)
    }
}

extension BusinessBatch {
    /// The currencies other than `home` some entries are in (« USD »).
    func foreignCurrencies(home: String) -> Set<String> {
        Set(entryCurrencies.values).subtracting([home.uppercased()])
    }

    /// From the first entry to the last.
    var period: ClosedRange<Date>? {
        let dates = sales.map(\.date) + expenses.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return first...last
    }

    /// The batch in the history's currency, each entry at the rate of its day, its original amount kept.
    /// An entry without a rate stays as it was and its currency goes in `unconverted`. Ids don't change:
    /// importing the same file again still adds nothing.
    func converted(with history: FXHistory) -> BusinessBatch {
        var result = self
        for index in result.sales.indices {
            let sale = result.sales[index]
            guard sale.original == nil, let key = sale.importKey, let currency = entryCurrencies[key] else { continue }
            if let value = CurrencyConversion.convert(sale.amount, currency, on: sale.date, with: history) {
                result.sales[index].amount = value.amount
                result.sales[index].original = value.original
            } else {
                result.unconverted.insert(currency)
            }
        }
        for index in result.expenses.indices {
            let cost = result.expenses[index]
            guard cost.original == nil, let key = cost.importKey, let currency = entryCurrencies[key] else { continue }
            if let value = CurrencyConversion.convert(cost.amount, currency, on: cost.date, with: history) {
                result.expenses[index].amount = value.amount
                result.expenses[index].original = value.original
            } else {
                result.unconverted.insert(currency)
            }
        }
        return result
    }

    /// The currencies converted (« USD »).
    var convertedCurrencies: Set<String> {
        Set(sales.compactMap { $0.original?.currency } + expenses.compactMap { $0.original?.currency })
    }

    /// The first and last days of the rates used (yyyy-MM-dd).
    var rateDays: ClosedRange<String>? {
        let days = sales.compactMap { $0.original?.rateDay } + expenses.compactMap { $0.original?.rateDay }
        guard let first = days.min(), let last = days.max() else { return nil }
        return first...last
    }
}
