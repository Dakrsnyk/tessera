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
    /// Nothing in the file said which lines are sales and which are costs (amounts all positive, no type,
    /// no debit and credit columns): every line was read as a sale, and the preview asks (`asExpenses()`).
    var directionGuessed = false
    /// The entries (`importKey`) whose status says they aren't paid yet (« à payer », « prévu », « pending »).
    var pendingKeys: Set<String> = []
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
        /// The currencies Stripe's amounts were converted from by the last sync, at the ECB rate of their day.
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
    /// by hand are never touched, and an entry converted before keeps its conversion when it comes back
    /// unconverted for lack of a rate (`keepsConversion`).
    @discardableResult
    mutating func merge(_ batch: BusinessBatch) -> BusinessMergeResult {
        var result = BusinessMergeResult()
        // A line imported before on the wrong side (a cost read as a sale, or the other way): it moves to
        // its side, counted as updated, never twice.
        let incomingSales = Set(batch.sales.compactMap(\.importKey))
        let incomingCosts = Set(batch.expenses.compactMap(\.importKey))
        var moved = Set<String>()
        sales.removeAll { sale in
            guard let key = sale.importKey, incomingCosts.contains(key), !incomingSales.contains(key) else { return false }
            moved.insert(key)
            return true
        }
        expenses.removeAll { cost in
            guard let key = cost.importKey, incomingSales.contains(key), !incomingCosts.contains(key) else { return false }
            moved.insert(key)
            return true
        }
        var saleIndex: [String: Int] = [:]
        for (index, sale) in sales.enumerated() { if let key = sale.importKey { saleIndex[key] = index } }
        for sale in batch.sales {
            guard let key = sale.importKey else { continue }
            if let index = saleIndex[key] {
                var updated = sale
                updated.id = sales[index].id
                if batch.keepsConversion(sales[index].original, comingBack: sale.amount, sale.original) {
                    updated.amount = sales[index].amount
                    updated.original = sales[index].original
                }
                if sales[index] == updated { result.unchanged += 1 } else { sales[index] = updated; result.updated += 1 }
            } else {
                saleIndex[key] = sales.count
                sales.append(sale)
                if moved.contains(key) { result.updated += 1 } else { result.added += 1 }
            }
        }
        var costIndex: [String: Int] = [:]
        for (index, cost) in expenses.enumerated() { if let key = cost.importKey { costIndex[key] = index } }
        for cost in batch.expenses {
            guard let key = cost.importKey else { continue }
            if let index = costIndex[key] {
                var updated = cost
                updated.id = expenses[index].id
                if batch.keepsConversion(expenses[index].original, comingBack: cost.amount, cost.original) {
                    updated.amount = expenses[index].amount
                    updated.original = expenses[index].original
                }
                if expenses[index] == updated { result.unchanged += 1 } else { expenses[index] = updated; result.updated += 1 }
            } else {
                costIndex[key] = expenses.count
                expenses.append(cost)
                if moved.contains(key) { result.updated += 1 } else { result.added += 1 }
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

/// Reads a sales export: Stripe (payments or balance), Shopify (orders), PayPal, Wave, QuickBooks, a bank
/// (Desjardins, RBC, BNC, TD, with or without a header) or a spreadsheet with a date and an amount. Paid
/// sales become sales, refunds negative sales, fees and money out costs; failed or cancelled payments,
/// payouts and transfers are left out. Nothing is guessed when a line lacks its date or its amount: it is
/// counted as skipped.
///
/// Whether a line is a sale or a cost, in this order (the first that says it decides):
/// 1. Left out: a failed or cancelled status, a payout, a transfer, a currency conversion or a memo
///    (PayPal's « Balance Impact: Memo »), or the other side of an accounting entry (Wave: « Assets »).
/// 2. A fee (type « stripe_fee », « Frais », « Fee ») is a cost.
/// 3. A refund (type « refund », « Remboursement ») is a negative sale; a refund that came in (credit,
///    deposit, positive amount in a signed file) is money in: a sale with no order.
/// 4. A direction column (« Balance Impact », « Sens », « Débit/Crédit », « DR/CR »): debit is a cost,
///    credit a sale.
/// 5. Two amount columns (Débit/Crédit, Retrait/Dépôt, Withdrawal/Deposit, Money out/Money in, Paid
///    out/Paid in, Sortie/Entrée, Dépenses/Revenus, Expense/Income): the out one is a cost, the in one a
///    sale. Used unless a single amount column is signed (Wave writes both).
/// 6. A type or category column (« Type », « Transaction type », « Catégorie », « Account Group »): débit,
///    DR, dépense, expense, achat, purchase, retrait, withdrawal, sortie, bill, chèque are costs; crédit,
///    CR, revenu, recette, income, vente, sale, dépôt, deposit, entrée, invoice, charge (Stripe) are sales;
///    « paiement » is a cost unless the file is signed and the amount positive.
/// 7. The sign of the amount: negative (« -12.50 », « −12,50 », « (12.50) », « 12.50- », « 12.50 DR »)
///    is a cost, positive a sale.
/// The « Solde » / « Balance » column is never an amount. When nothing in the file says it (amounts all
/// positive, no type, no sales columns), every line is read as a sale and `directionGuessed` is set: the
/// preview asks what the file holds (`asExpenses()`).
enum BusinessCSV {
    enum ImportError: Error, Equatable {
        case empty
        /// No column that reads as a date, or none as an amount.
        case missingColumns
    }

    /// What a line is, as its type, category or direction says.
    enum LineKind: Equatable {
        case sale, refund, fee, expense, skip
        /// « Paiement »: money out, unless a signed file says it came in.
        case likelyExpense
    }

    /// Statuses of payments that never happened.
    static let failedStatuses: Set<String> = ["failed", "canceled", "cancelled", "voided", "expired", "denied", "declined", "rejected",
                                              "echoue", "echouee", "annule", "annulee", "refuse", "refusee"]
    /// Statuses of operations not paid yet (planned, to pay): imported, but counted apart in the preview.
    static let pendingStatuses: Set<String> = ["a payer", "a recevoir", "prevu", "prevue", "a venir", "en attente", "planifie", "impaye",
                                               "non paye", "pending", "unpaid", "planned", "scheduled", "upcoming", "due", "overdue", "draft", "brouillon"]

    /// The roles of a file's columns, read from its header.
    struct Layout {
        var date: Int
        var isUTC: Bool
        /// The amount, signed (the first one filled on a line); with a currency when the column names one (RBC: « CAD$ », « USD$ »).
        var amounts: [(index: Int, currency: String?)]
        /// Money out and money in, each positive (Débit/Crédit, Retrait/Dépôt…).
        var moneyOut: Int?
        var moneyIn: Int?
        /// Columns that say debit or credit (PayPal's « Balance Impact », « Sens »).
        var directions: [Int]
        /// Type and category columns, in that order.
        var kinds: [Int]
        var id: Int?
        var status: Int?
        var fee: Int?
        var refunded: Int?
        var label: Int?
        var category: Int?
        var currency: Int?

        /// A sales export (Stripe, Shopify): its lines are sales unless they say otherwise.
        var isSalesExport: Bool

        init?(header: [String]) {
            let names = header.map(BusinessCSV.normalized)
            func column(_ candidates: [String], excluding excluded: Set<Int> = []) -> Int? {
                for candidate in candidates {
                    if let index = names.indices.first(where: { !excluded.contains($0) && names[$0] == candidate }) { return index }
                }
                for candidate in candidates {
                    if let index = names.indices.first(where: { !excluded.contains($0) && names[$0].hasPrefix(candidate) }) { return index }
                }
                return nil
            }
            let words = names.map { BusinessCSV.words($0) }
            let balances = Set(names.indices.filter { index in
                !words[index].isDisjoint(with: ["solde", "balance", "disponible", "available", "cumul", "running"]) && !words[index].contains("impact")
            })
            var flows: [Int: Bool] = [:]
            var bothWays: [Int] = []
            for index in names.indices where !balances.contains(index) {
                switch BusinessCSV.flow(names[index], words[index]) {
                case .some(true): flows[index] = true
                case .some(false): flows[index] = false
                case nil:
                    if BusinessCSV.namesBothWays(words[index]) { bothWays.append(index) }
                }
            }
            guard let dateColumn = column(["created date (utc)", "created (utc)", "created at", "paid at", "processed at", "transaction date",
                                     "date de creation", "date", "created", "jour", "posting date", "posted date", "booking date"],
                                    excluding: balances) else { return nil }
            var notAmounts = balances.union(flows.keys).union(bothWays).union([dateColumn])
            for index in names.indices where !words[index].isDisjoint(with: ["refunded", "rembourse", "fee", "fees", "frais", "tax", "taxes",
                                                                             "discount", "shipping", "date", "id", "currency", "devise"]) {
                notAmounts.insert(index)
            }
            var amountColumns: [(index: Int, currency: String?)] = []
            if let amount = column(["amount", "total", "gross", "montant", "net", "total amount", "prix", "price", "valeur", "value", "somme", "sum"],
                                   excluding: notAmounts) {
                amountColumns = [(index: amount, currency: nil)]
            } else {
                // RBC: « CAD$ », « USD$ »: one of them filled on each line.
                for index in names.indices where !notAmounts.contains(index) && names[index].contains("$") {
                    let code = names[index].filter(\.isLetter).uppercased()
                    if BusinessCSV.currencyCodes.contains(code) { amountColumns.append((index: index, currency: code)) }
                }
            }
            let outColumn = names.indices.first { flows[$0] == false }
            let inColumn = names.indices.first { flows[$0] == true }
            guard !amountColumns.isEmpty || outColumn != nil || inColumn != nil else { return nil }
            let directionColumns = [column(["balance impact", "sens", "direction", "debit/credit", "credit/debit", "dr/cr", "cr/dr", "d/c", "c/d",
                                            "debit ou credit", "credit ou debit", "impact"])].compactMap { $0 } + bothWays
            let typeColumn = column(["type", "transaction type", "type de transaction", "type d'operation", "type d’operation", "type operation",
                                     "operation type", "reporting category", "nature", "kind"], excluding: Set(directionColumns))
            let categoryColumn = column(["categorie", "category", "account group", "groupe de comptes"],
                                        excluding: Set(directionColumns + [typeColumn].compactMap { $0 }))
            var kindColumns: [Int] = []
            for index in [typeColumn, categoryColumn].compactMap({ $0 }) where !kindColumns.contains(index) { kindColumns.append(index) }
            date = dateColumn
            isUTC = names[dateColumn].contains("utc")
            amounts = amountColumns
            moneyOut = outColumn
            moneyIn = inColumn
            directions = directionColumns
            kinds = kindColumns
            category = categoryColumn
            // « Name » is the order's number in Shopify only (elsewhere, a customer's name).
            let isShopify = names.contains("financial status") || names.contains("lineitem name")
            id = column(["id", "transaction id", "charge id", "order id"] + (isShopify ? ["name"] : []) + ["numero", "reference", "ref"])
            status = column(["status", "financial status", "statut", "etat"])
            let feeColumn = column(["fee", "fees", "frais"])
            let refundedColumn = column(["amount refunded", "refunded amount", "montant rembourse"])
            fee = feeColumn
            refunded = refundedColumn
            label = column(["description", "libelle", "note", "title", "lineitem name", "produit", "transaction description",
                            "payee", "beneficiaire", "merchant", "details", "memo"])
            currency = column(["currency", "devise", "monnaie"])
            isSalesExport = refundedColumn != nil || feeColumn != nil || isShopify || names.contains("paid at")
        }
    }

    static func parse(_ text: String) throws -> BusinessBatch {
        var rows = table(text)
        guard rows.count > 1 else { throw ImportError.empty }
        // The header: the first of the first lines that names a date and an amount (some banks write the
        // account above it). Without one, a file of lines only (TD): the roles are read from the cells.
        var found: Layout?
        for index in 0..<min(rows.count - 1, 15) {
            if let layout = Layout(header: rows[index]) {
                found = layout
                rows.removeFirst(index + 1)
                break
            }
        }
        if found == nil, let names = headerlessNames(rows) { found = Layout(header: names) }
        guard let layout = found else { throw ImportError.missingColumns }

        func cell(_ row: [String], _ index: Int?) -> String { index.flatMap { row[safe: $0] }?.trimmed ?? "" }
        // One negative amount is enough for every sign to say the direction of its line.
        let signed = rows.contains { row in layout.amounts.contains { (amount(cell(row, $0.index)) ?? 0) < 0 } }
        let usesPair = (layout.moneyOut != nil || layout.moneyIn != nil) && (layout.amounts.isEmpty || !signed)
        var decided = usesPair || signed || layout.isSalesExport

        var batch = BusinessBatch()
        var seen = Set<String>()
        for row in rows where row.contains(where: { !$0.trimmed.isEmpty }) {
            func value(_ index: Int?) -> String { cell(row, index) }
            // The amount, signed: money in positive, money out negative.
            var read: (value: Double, currency: String?)?
            if usesPair {
                let out = money(value(layout.moneyOut))
                let came = money(value(layout.moneyIn))
                if out != nil || came != nil {
                    read = (abs(came?.value ?? 0) - abs(out?.value ?? 0), came?.currency ?? out?.currency)
                }
            } else {
                for column in layout.amounts {
                    if let parsed = money(value(column.index)) {
                        read = (parsed.value, parsed.currency ?? column.currency)
                        break
                    }
                }
            }
            guard let when = date(value(layout.date), utc: layout.isUTC), let read else {
                batch.skipped += 1
                continue
            }
            let total = read.value
            let status = normalized(value(layout.status))
            let lineDirection = layout.directions.lazy.compactMap { BusinessCSV.direction(of: value($0)) }.first
            let lineKind = layout.kinds.lazy.compactMap { BusinessCSV.kind(of: value($0)) }.first
            if lineDirection != nil || lineKind != nil { decided = true }
            if failedStatuses.contains(status) || lineDirection == .skip || lineKind == .skip {
                batch.skipped += 1
                continue
            }
            let category = value(layout.category)
            let description = value(layout.label)
            // The description; the category when there is none.
            let label = description.isEmpty ? category : description
            let rawID = value(layout.id)
            // Without an id, the line itself is its id: the same file imported twice adds nothing. Two
            // columns: the amount as it is written (positive), the id an older import gave the line.
            let idAmount = usesPair ? abs(total) : total
            let id = rawID.isEmpty ? fingerprint([DateMath.dayKey(when), String(format: "%.2f", idAmount), description]) : rawID
            // Shopify writes one line per item of an order: its total is on the first one only.
            guard seen.insert(id).inserted else { continue }
            let fileCurrency = value(layout.currency)
            let currency = (fileCurrency.isEmpty ? read.currency ?? "" : fileCurrency).lowercased()
            if !currency.isEmpty { batch.currencies.insert(currency) }
            // Kept as the file gives them; converted afterwards with the rates of their days.
            let code = currency.uppercased()
            let isPending = pendingStatuses.contains(status)
            func track(_ key: String?) {
                guard let key else { return }
                if !code.isEmpty { batch.entryCurrencies[key] = code }
                if isPending { batch.pendingKeys.insert(key) }
            }
            func addSale(_ sale: SalesEntry) {
                batch.sales.append(sale)
                track(sale.importKey)
            }
            func addCost(_ cost: BusinessExpense) {
                batch.expenses.append(cost)
                track(cost.importKey)
            }
            func cost(_ amount: Double, _ fallback: String) -> BusinessExpense {
                BusinessExpense(date: when, amount: abs(amount), label: label.isEmpty ? fallback : label,
                                source: BusinessSource.csv.rawValue, externalID: id)
            }

            if lineKind == .fee {
                addCost(cost(total, tr("Dépense importée")))
                continue
            }
            if lineKind == .refund || status == "refunded" && total < 0 {
                // A refund that came in (a credit, a deposit, a positive amount in a signed file) is money in.
                let cameBack = lineDirection == .sale || (lineDirection == nil && (usesPair || signed) && total > 0)
                addSale(SalesEntry(date: when, amount: cameBack ? abs(total) : -abs(total), orders: 0,
                                   note: label.isEmpty ? tr("Remboursement") : label, source: BusinessSource.csv.rawValue, externalID: id))
                continue
            }
            let isOut: Bool
            if let lineDirection {
                isOut = lineDirection != .sale
            } else if usesPair {
                isOut = total < 0
            } else if lineKind == .expense {
                isOut = true
            } else if lineKind == .sale {
                isOut = false
            } else if lineKind == .likelyExpense {
                isOut = signed ? total < 0 : true
            } else {
                isOut = total < 0
            }
            if isOut {
                addCost(cost(total, tr("Dépense importée")))
                continue
            }
            // Refunded in full, without the refunded amount in the file (Shopify): no sale left.
            if status == "refunded", layout.refunded == nil, total > 0 {
                batch.skipped += 1
                continue
            }
            let refunded = amount(value(layout.refunded)) ?? 0
            addSale(SalesEntry(date: when, amount: total - abs(refunded), orders: 1, note: label,
                               source: BusinessSource.csv.rawValue, externalID: id))
            if let fee = amount(value(layout.fee)), fee != 0 {
                addCost(BusinessExpense(date: when, amount: abs(fee), label: tr("Frais de paiement"),
                                        source: BusinessSource.csv.rawValue, externalID: "\(id)-fee"))
            }
        }
        batch.directionGuessed = !decided && !batch.sales.isEmpty
        return batch
    }

    // MARK: Columns

    static func words(_ name: String) -> Set<String> {
        Set(name.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }

    private static let outWords: Set<String> = ["debit", "debits", "retrait", "retraits", "withdrawal", "withdrawals", "sortie", "sorties",
                                                "depense", "depenses", "expense", "expenses", "decaissement", "decaissements"]
    private static let inWords: Set<String> = ["credit", "credits", "depot", "depots", "deposit", "deposits", "entree", "entrees", "revenu",
                                               "revenus", "revenue", "revenues", "income", "recette", "recettes", "encaissement", "encaissements"]

    /// A column of money out (false) or money in (true), positive: « Retrait », « Montant crédit », « Paid in ».
    static func flow(_ name: String, _ words: Set<String>) -> Bool? {
        guard words.isDisjoint(with: ["type", "sens", "category", "categorie", "account", "compte", "date", "carte", "card", "number",
                                      "numero", "no", "impact", "status", "statut", "id"]) else { return nil }
        let out = !words.isDisjoint(with: outWords) || ["paid out", "money out", "amount out", "montant sortant"].contains { name.contains($0) } || name == "out"
        let came = !words.isDisjoint(with: inWords) || ["paid in", "money in", "amount in", "montant entrant"].contains { name.contains($0) } || name == "in"
        guard out != came else { return nil }
        return came
    }

    /// « Débit/Crédit », « Crédit ou débit »: a column that says which way, not how much.
    static func namesBothWays(_ words: Set<String>) -> Bool {
        !words.isDisjoint(with: outWords) && !words.isDisjoint(with: inWords) && words.isDisjoint(with: ["solde", "balance"])
    }

    /// What a direction column says: also a single letter (« C » / « D », « E » / « S »).
    static func direction(of text: String) -> LineKind? {
        switch normalized(text) {
        case "c", "e": .sale
        case "d", "s": .expense
        default: kind(of: text)
        }
    }

    /// What a type, category or direction says of its line (nil: nothing, the sign decides).
    static func kind(of text: String) -> LineKind? {
        let value = normalized(text)
        guard !value.isEmpty else { return nil }
        if value == "+" { return .sale }
        if value == "-" { return .expense }
        var parts = BusinessCSV.words(value)
        if parts.isEmpty { return nil }
        // Moves of money already counted, and the other side of an accounting entry.
        if value.contains("payout") || value == "transfer" || value == "virement" || value.contains("currency conversion")
            || value.contains("conversion de devise") || value == "memo" || value.contains("authorization") || value.contains("autorisation")
            || (value.contains("withdraw") && (value.contains("bank") || value.contains("general")))
            || !parts.isDisjoint(with: ["assets", "asset", "liabilities", "liability", "equity", "actif", "passif"]) {
            return .skip
        }
        if value.contains("refund") || value.contains("rembours") || value.contains("chargeback") { return .refund }
        if !parts.isDisjoint(with: ["fee", "fees", "frais", "commission", "commissions"]) { return .fee }
        // Stripe's payments.
        if value == "charge" || value == "payment" { return .sale }
        // « Carte de crédit », « Debit card »: the card, not the direction.
        if !parts.isDisjoint(with: ["card", "carte"]) { parts.subtract(["credit", "debit"]) }
        if !parts.isDisjoint(with: ["debit", "debits", "dr", "expense", "expenses", "depense", "depenses", "achat", "achats", "purchase",
                                    "purchases", "withdrawal", "withdrawals", "retrait", "retraits", "sortie", "sorties", "out", "decaissement",
                                    "charges", "cost", "costs", "cout", "couts", "bill", "bills", "check", "cheque", "cheques", "prelevement"]) {
            return .expense
        }
        if !parts.isDisjoint(with: ["credit", "credits", "cr", "income", "revenu", "revenus", "revenue", "sale", "sales", "vente", "ventes",
                                    "deposit", "deposits", "depot", "depots", "entree", "entrees", "in", "recette", "recettes", "encaissement",
                                    "order", "orders", "commande", "commandes", "invoice", "received", "recu", "recue"]) {
            return .sale
        }
        if !parts.isDisjoint(with: ["paiement", "paiements"]) { return .likelyExpense }
        return nil
    }

    /// The names of a file without a header (TD: date, description, withdrawal, deposit, balance), from its
    /// cells: the date, the first column of text, then its numbers. One: the amount. Two: the amount and
    /// the balance when both are on every line, else money out and money in. Three or more: the last
    /// three are money out, money in and the balance. Nil when the first line has no date.
    static func headerlessNames(_ rows: [[String]]) -> [String]? {
        guard let first = rows.first, let dateIndex = first.prefix(4).firstIndex(where: { date($0) != nil }) else { return nil }
        let width = rows.map(\.count).max() ?? 0
        var names = Array(repeating: "", count: width)
        names[dateIndex] = "date"
        var label: Int?
        var numbers: [Int] = []
        for index in 0..<width where index != dateIndex {
            let cells = rows.map { $0[safe: index]?.trimmed ?? "" }.filter { !$0.isEmpty }
            if cells.allSatisfy({ amount($0) != nil }) {
                if label != nil { numbers.append(index) }
            } else if label == nil {
                label = index
            }
        }
        if let label { names[label] = "description" }
        func filledEverywhere(_ index: Int) -> Bool { rows.allSatisfy { !($0[safe: index]?.trimmed ?? "").isEmpty } }
        switch numbers.count {
        case 0: return nil
        case 1: names[numbers[0]] = "montant"
        case 2:
            if filledEverywhere(numbers[0]) && filledEverywhere(numbers[1]) {
                names[numbers[0]] = "montant"
                names[numbers[1]] = "solde"
            } else {
                names[numbers[0]] = "debit"
                names[numbers[1]] = "credit"
            }
        default:
            let last = Array(numbers.suffix(3))
            names[last[0]] = "debit"
            names[last[1]] = "credit"
            names[last[2]] = "solde"
        }
        return names
    }

    // MARK: Reading

    /// The cells of a CSV file: commas, semicolons or tabs (the one that splits the first lines most
    /// evenly, or Excel's « sep=; »), quoted cells with delimiters, quotes and line breaks, a BOM.
    static func table(_ text: String) -> [[String]] {
        var body = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        var delimiter: Character = ","
        let firstLine = body.prefix { $0 != "\n" && $0 != "\r" && $0 != "\r\n" }
        if firstLine.lowercased().hasPrefix("sep="), let given = firstLine.dropFirst(4).first {
            delimiter = given
            body = String(body.dropFirst(firstLine.count).drop { $0.isNewline })
        } else {
            let lines = body.split(whereSeparator: \.isNewline).prefix(10)
            func counts(_ candidate: Character) -> [Int] {
                lines.map { line in
                    var quoted = false
                    var count = 0
                    for char in line {
                        if char == "\"" { quoted.toggle() } else if char == candidate && !quoted { count += 1 }
                    }
                    return count
                }
            }
            // The most lines with the same number of delimiters, then the most delimiters.
            var best = (0, 0)
            for candidate: Character in [";", "\t", ","] {
                let found = counts(candidate).filter { $0 > 0 }
                guard !found.isEmpty else { continue }
                let frequency = Dictionary(grouping: found, by: { $0 }).mapValues(\.count)
                guard let mode = frequency.max(by: { ($0.value, $0.key) < ($1.value, $1.key) }) else { continue }
                if (mode.value, mode.key) > best {
                    best = (mode.value, mode.key)
                    delimiter = candidate
                }
            }
        }
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
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) && $0.contains { !$0.trimmed.isEmpty } }
    }

    static func normalized(_ text: String) -> String {
        text.trimmed.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The ISO codes of currencies (« USD »).
    static let currencyCodes = Set(Locale.commonISOCurrencyCodes.map { $0.uppercased() })

    /// « 1 234,56 $ », « $1,234.56 », « -12.00 », « (12.00) »: the number, the decimal mark being the last
    /// one when both are there.
    static func amount(_ text: String) -> Double? {
        money(text)?.value
    }

    /// The number of a cell and the currency it says, if any (« USD -12.50 », « 12,50 € », « CA$ 5 »).
    /// Negative: a minus (- − –) before or after the number, accounting parentheses, or « DR ». Thousands
    /// separators: spaces (also no-break and narrow ones), apostrophes, commas or dots.
    static func money(_ text: String) -> (value: Double, currency: String?)? {
        let chars = Array(text.trimmed)
        func isDigit(_ char: Character) -> Bool { ("0"..."9").contains(char) }
        guard let first = chars.firstIndex(where: isDigit), let last = chars.lastIndex(where: isDigit) else { return nil }
        let before = chars[..<first]
        let after = chars[(last + 1)...]
        let around = Array(before) + Array(after)
        let minus: Set<Character> = ["-", "\u{2212}", "\u{2013}", "\u{2012}", "\u{FE63}", "\u{FF0D}"]
        let letters = String(around.filter(\.isLetter)).uppercased()
        let negative = around.contains(where: minus.contains) || (before.contains("(") && after.contains(")")) || letters == "DR"
        var cleaned = String(chars[first...last].filter { isDigit($0) || $0 == "," || $0 == "." })
        if before.last == "." || before.last == "," { cleaned = "0." + cleaned }
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
        case (nil, _?):
            if cleaned.filter({ $0 == "." }).count > 1 { cleaned = cleaned.replacingOccurrences(of: ".", with: "") }
        default:
            break
        }
        guard let value = Double(cleaned), value.isFinite else { return nil }
        var currency: String?
        if letters.count == 3, currencyCodes.contains(letters) {
            currency = letters
        } else if around.contains("€") {
            currency = "EUR"
        } else if around.contains("£") {
            currency = "GBP"
        } else if around.contains("$"), ["CA", "C"].contains(letters) {
            currency = "CAD"
        } else if around.contains("$"), letters == "US" {
            currency = "USD"
        }
        return (negative ? -value : value, currency)
    }

    private static let dateFormats = [
        "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd", "dd/MM/yyyy HH:mm", "dd/MM/yyyy",
        "dd-MM-yyyy", "dd.MM.yyyy", "MM/dd/yyyy HH:mm", "MM/dd/yyyy", "d MMM yyyy", "MMM d, yyyy",
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

    /// Why some currencies couldn't be converted, said as it is: « Non converti (taux indisponible) : AED. La
    /// BCE ne publie pas de taux pour AED. » Offline (`unreachable`): try again. Not published
    /// (`unsupported`): never a rate. Rates fetched but none for some days (a date to come, or misread): no
    /// rate for that date, nothing guessed.
    static func problemMessage(for codes: Set<String>, unavailable: [String: FXHistory.Problem]) -> String {
        let list = codes.sorted().joined(separator: ", ")
        var sentences = [tr("Non converti (taux indisponible) : \(list).")]
        let unsupported = codes.filter { unavailable[$0] == .unsupported }.sorted()
        if !unsupported.isEmpty {
            let unpublished = unsupported.joined(separator: ", ")
            sentences.append(tr("La BCE ne publie pas de taux pour \(unpublished)."))
        }
        if codes.contains(where: { unavailable[$0] == .unreachable }) {
            sentences.append(tr("Impossible d'obtenir les taux de la BCE. Vérifie ta connexion, puis réessaie."))
        }
        if codes.contains(where: { unavailable[$0] == nil }) {
            sentences.append(tr("Aucun taux de la BCE pour la date de certaines opérations : date à venir, ou mal lue."))
        }
        return sentences.joined(separator: " ")
    }

    /// The rates a file needs, for its whole period: one request per currency.
    static func rates(for batch: BusinessBatch, home: String, now: Date = Date()) async -> FXHistory {
        let foreign = batch.foreignCurrencies(home: home)
        guard !foreign.isEmpty, let period = batch.period else { return FXHistory(home: home.uppercased()) }
        return await FXService.history(of: foreign, in: home, from: period.lowerBound, to: period.upperBound, now: now)
    }
}

extension BusinessBatch {
    /// The same file read as costs, when the person says it holds costs (`directionGuessed`): every sale
    /// becomes a cost of the same amount, with the same id (importing it again still adds nothing).
    func asExpenses() -> BusinessBatch {
        var result = self
        let costs = sales.map { sale in
            BusinessExpense(date: sale.date, amount: abs(sale.amount), label: sale.note.isEmpty ? tr("Dépense importée") : sale.note,
                            source: sale.source, externalID: sale.externalID,
                            original: sale.original.map { ForeignAmount(amount: abs($0.amount), currency: $0.currency, rate: $0.rate, rateDay: $0.rateDay) })
        }
        result.expenses = costs + expenses
        result.sales = []
        return result
    }

    /// The batch without the entries not paid yet (`pendingKeys`).
    func withoutPending() -> BusinessBatch {
        guard !pendingKeys.isEmpty else { return self }
        var result = self
        result.sales.removeAll { $0.importKey.map(pendingKeys.contains) ?? false }
        result.expenses.removeAll { $0.importKey.map(pendingKeys.contains) ?? false }
        result.pendingKeys = []
        return result
    }

    /// How many entries aren't paid yet.
    var pendingCount: Int {
        sales.filter { $0.importKey.map(pendingKeys.contains) ?? false }.count
            + expenses.filter { $0.importKey.map(pendingKeys.contains) ?? false }.count
    }

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

    /// True when an entry comes back as it was for lack of a rate (its currency is in `unconverted`), while
    /// the one already there was converted from that same amount: the conversion is kept, never undone by an
    /// import or a sync without conversion.
    func keepsConversion(_ stored: ForeignAmount?, comingBack amount: Double, _ incoming: ForeignAmount?) -> Bool {
        guard incoming == nil, let stored, unconverted.contains(stored.currency.uppercased()) else { return false }
        return abs(stored.amount - amount) < 0.000_1
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
