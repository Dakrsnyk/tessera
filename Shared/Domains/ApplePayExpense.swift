import Foundation

/// Apple Pay payments received from the « Transaction » personal automation of Shortcuts, which calls the
/// « Ajouter une dépense Apple Pay » action with the amount, the shop and the card as TEXT. Everything stays
/// on the iPhone: the text is read here, a category is guessed from the shop's name, and the expense lands
/// in the budget like any other. Nothing is invented: an unreadable or null amount adds nothing, and a
/// refund is not turned into a negative expense.
enum ApplePayExpense {
    /// The same amount from the same shop within this many seconds is one payment: the automation can run
    /// twice for it.
    static let duplicateWindow: TimeInterval = 120

    /// What an expense without a shop name is called.
    static let genericMerchant = "Apple Pay"

    /// The reasons given by `ApplePayResult.ignored`.
    enum Reason {
        static let refund = "remboursement"
        static let zero = "montant nul"
        static let unreadable = "montant illisible"
        static let storeUnreadable = "données illisibles"
    }

    // MARK: Amount

    /// The amount of a text given by Shortcuts: « 12,50 $ », « $12.50 », « 12.50 », « 1 234,56 »,
    /// « CA$ 5.00 », « 1,234.56 », with any kind of space (non-breaking ones included). Only a positive
    /// amount is returned: a refund (« -12.50 »), zero or a text without a number give nil.
    static func parseAmount(_ text: String) -> Double? {
        guard let value = parseSignedAmount(text), value > 0 else { return nil }
        return value
    }

    /// The same, with its sign (a minus before the number, or an amount in parentheses, is negative), so
    /// that a refund can be told from a text that can't be read. nil when no number is found.
    static func parseSignedAmount(_ text: String) -> Double? {
        // Every kind of space (no-break, narrow no-break, thin…) becomes a plain one.
        let spaced = String(text.map { $0.isWhitespace ? Character(" ") : $0 })
        let whole = NSRange(spaced.startIndex..., in: spaced)
        guard let regex = amountRegex,
              let match = regex.firstMatch(in: spaced, range: whole),
              let range = Range(match.range, in: spaced),
              let magnitude = value(ofToken: String(spaced[range])),
              magnitude < 10_000_000 else { return nil }
        let before = spaced[..<range.lowerBound]
        let after = spaced[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let trimmed = spaced.trimmingCharacters(in: .whitespaces)
        let negative = before.contains { minusSigns.contains($0) }
            || after.hasPrefix("-")
            || (trimmed.hasPrefix("(") && trimmed.hasSuffix(")"))
        let rounded = (magnitude * 100).rounded() / 100
        return negative ? -rounded : rounded
    }

    private static let minusSigns: Set<Character> = ["-", "\u{2212}", "\u{2013}", "\u{2014}"]

    /// A number with spaces as thousands separators (« 1 234,56 »), or any run of digits, dots and commas.
    private static let amountRegex = try? NSRegularExpression(pattern: #"\d{1,3}(?: \d{3})+(?:[.,]\d{1,2})?(?!\d)|\d[\d.,]*"#)

    /// The value of a run of digits with dots, commas or spaces. When both separators appear, the last one
    /// is the decimal mark; a single repeated one groups thousands; a single one followed by exactly three
    /// digits (after one to three, not « 0 ») groups thousands too, otherwise it is the decimal mark.
    private static func value(ofToken raw: String) -> Double? {
        var token = raw.replacingOccurrences(of: " ", with: "")
        while let last = token.last, last == "." || last == "," { token.removeLast() }
        guard !token.isEmpty else { return nil }
        let isMark: (Character) -> Bool = { $0 == "." || $0 == "," }
        let marks = token.filter(isMark).count
        let hasDot = token.contains(".")
        let hasComma = token.contains(",")
        var integer = token
        var fraction = ""
        if hasDot && hasComma {
            guard let split = token.lastIndex(where: isMark) else { return nil }
            integer = String(token[..<split]).filter { !isMark($0) }
            fraction = String(token[token.index(after: split)...])
        } else if marks > 1 {
            let groups = token.split(whereSeparator: isMark).map(String.init)
            guard groups.count == marks + 1,
                  (1...3).contains(groups[0].count),
                  groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
            integer = groups.joined()
        } else if marks == 1 {
            let parts = token.split(whereSeparator: isMark).map(String.init)
            guard parts.count == 2 else { return nil }
            if parts[1].count == 3, (1...3).contains(parts[0].count), parts[0] != "0" {
                integer = parts[0] + parts[1]
            } else {
                integer = parts[0]
                fraction = parts[1]
            }
        }
        guard !integer.isEmpty, integer.allSatisfy(\.isASCII), fraction.allSatisfy(\.isASCII) else { return nil }
        guard let number = Double(fraction.isEmpty ? integer : "\(integer).\(fraction)"), number.isFinite else { return nil }
        return number
    }

    /// The currency written in an amount when it is explicit (« US$ 5 », « 12 € », « 5 EUR »), nil for a
    /// bare « $ » or no currency at all. The amount is never converted: the caller flags a foreign one.
    static func currencyCode(in text: String) -> String? {
        let upper = text.uppercased()
        let symbols: [(String, String)] = [("US$", "USD"), ("CA$", "CAD"), ("C$", "CAD"), ("AU$", "AUD"), ("€", "EUR"), ("£", "GBP")]
        if let found = symbols.first(where: { upper.contains($0.0) }) { return found.1 }
        let words = Set(upper.split { !$0.isLetter }.map(String.init))
        return ["USD", "CAD", "EUR", "GBP", "CHF", "JPY", "AUD", "MXN"].first { words.contains($0) }
    }

    // MARK: Shop

    /// The name as shown: spaces collapsed, « Apple Pay » when there is none.
    static func displayName(_ raw: String) -> String {
        let name = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return name.isEmpty ? genericMerchant : name
    }

    /// The name shown in the list of operations: the shop without its terminal reference (« #123 … »), and
    /// a name written in capitals set in proper case (« 7-ELEVEN #123 » → « 7-Eleven »). Digits stay.
    static func noteName(_ shown: String) -> String {
        var name = shown
        if let hash = name.firstIndex(of: "#") { name = String(name[..<hash]).trimmed }
        if name.isEmpty { name = shown }
        guard name.contains(where: \.isLetter), name == name.uppercased() else { return name }
        var result = ""
        var insideWord = false
        for character in name.lowercased() {
            if character.isLetter {
                result += insideWord ? String(character) : String(character).uppercased()
                insideWord = true
            } else {
                result.append(character)
                // An apostrophe doesn't start a new word: « McDonald's ».
                insideWord = insideWord && (character == "'" || character == "\u{2019}")
            }
        }
        return result
    }

    private static let cardProcessors: Set<String> = ["sq", "tst", "sp", "pp", "paypal", "pos", "sumup", "izettle", "stripe", "toast", "clover"]
    private static let regionWords: Set<String> = ["qc", "on", "bc", "ab", "mb", "nb", "ns", "pe", "pei", "nl", "sk", "nt", "yt", "nu", "ca", "can", "usa", "us"]
    private static let cityWords: Set<String> = ["montreal", "mtl", "laval", "quebec", "longueuil", "gatineau", "sherbrooke", "toronto", "ottawa", "vancouver",
                                                 "calgary", "edmonton", "winnipeg", "halifax", "brossard", "levis", "saguenay"]

    /// The shop reduced to what identifies it: lowercase, without accents, apostrophes, punctuation, terminal
    /// numbers (« #1234 »), processor prefixes (« SQ * ») nor an evident city or province at the end:
    /// « TIM HORTONS #1234 MONTREAL QC » → « tim hortons ». Empty for a name with nothing to keep.
    static func normalizedMerchant(_ raw: String) -> String {
        var text = raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        // « SQ *BLUE BOTTLE », « PAYPAL *SPOTIFY »: the shop follows the processor; « AMZN MKTP CA*1A2B »: a reference follows the shop.
        if text.contains("*") {
            let parts = text.split(separator: "*", maxSplits: 1, omittingEmptySubsequences: false).map { String($0).trimmed }
            let head = parts.first ?? ""
            let tail = parts.count > 1 ? parts[1] : ""
            if cardProcessors.contains(head) {
                text = tail.isEmpty ? head : tail
            } else {
                text = head.isEmpty ? tail : head
            }
        }
        if let hash = text.firstIndex(of: "#") { text = String(text[..<hash]) }
        text = text.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "").replacingOccurrences(of: "`", with: "")
        let tokens = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var kept = tokens.filter { token in !token.contains(where: \.isNumber) }
        if kept.isEmpty { kept = tokens }
        var changed = true
        while changed {
            changed = false
            if kept.count > 1, let last = kept.last, regionWords.contains(last) {
                kept.removeLast()
                changed = true
            } else if kept.count > 2, let last = kept.last, cityWords.contains(last) {
                kept.removeLast()
                changed = true
            }
        }
        return kept.joined(separator: " ")
    }

    // MARK: Category

    /// The category of a shop in this budget: the one the person taught first, then the built-in keywords
    /// (restaurants, groceries, fuel, transit, subscriptions, health, home, clothes, outings…) mapped to the
    /// categories that exist. nil when nothing matches, or when the matching category was deleted.
    static func categoryID(for merchant: String, in state: BudgetState) -> UUID? {
        let key = normalizedMerchant(merchant)
        return learnedCategoryID(forKey: key, in: state) ?? keywordCategoryID(forKey: key, in: state)
    }

    /// The category taught for this normalized shop name, if it still exists.
    static func learnedCategoryID(forKey key: String, in state: BudgetState) -> UUID? {
        guard !key.isEmpty, let id = state.merchantRules[key], state.category(id) != nil else { return nil }
        return id
    }

    /// The built-in guess alone, for a normalized shop name.
    static func keywordCategoryID(forKey key: String, in state: BudgetState) -> UUID? {
        // The bare « Apple Pay » of a payment without a shop name says nothing about the purchase.
        guard !key.isEmpty, key != normalizedMerchant(genericMerchant) else { return nil }
        let tokens = key.split(separator: " ").map(String.init)
        let padded = " " + key + " "
        for kind in Kind.allCases where kind.keywords.contains(where: { matches($0, tokens: tokens, padded: padded) }) {
            for candidate in kind.fallbackChain {
                if let id = existingCategoryID(for: candidate, in: state) { return id }
            }
            // A known kind of shop without a category of its own (a pharmacy, a clothes shop): « Autre », as
            // the fixed expenses do, still to be checked by the person.
            let other = BudgetState.fixedID(6)
            return state.category(other) != nil ? other : nil
        }
        return nil
    }

    /// A keyword of several words must appear as such; a single one must be a whole word (or, from six
    /// letters, the start of one: « mcdonald » for « mcdonalds »).
    private static func matches(_ keyword: String, tokens: [String], padded: String) -> Bool {
        if keyword.contains(" ") { return padded.contains(" " + keyword + " ") }
        return tokens.contains { $0 == keyword || (keyword.count >= 6 && $0.hasPrefix(keyword)) }
    }

    /// The category of a kind in this budget: the default one (same identifier everywhere) if it is still
    /// there, otherwise one whose name says the same thing.
    private static func existingCategoryID(for kind: Kind, in state: BudgetState) -> UUID? {
        if let index = kind.defaultIndex {
            let id = BudgetState.fixedID(index)
            if state.category(id) != nil { return id }
        }
        for category in state.categories {
            let name = category.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
            if kind.categoryNames.contains(where: { name == $0 || ($0.count >= 5 && name.contains($0)) }) { return category.id }
        }
        return nil
    }

    /// The kinds of shop, in the order they are tried (« uber eats » is a restaurant before « uber » is a ride).
    private enum Kind: CaseIterable {
        case restaurant, grocery, fuel, transport, subscription, health, home, clothing, leisure, shopping

        /// Words of the folded shop name (accents out, hyphens and apostrophes gone).
        var keywords: [String] {
            switch self {
            case .restaurant:
                ["tim hortons", "tims", "mcdonald", "mc donald", "starbucks", "subway", "st hubert", "harvey", "a w", "burger king", "wendy", "kfc", "popeyes",
                 "pizza", "pizzeria", "dominos", "pizza hut", "little caesars", "second cup", "dunkin", "van houtte", "cafe", "coffee", "restaurant", "resto",
                 "bistro", "brasserie", "sushi", "ramen", "pub", "grill", "poutine", "boulangerie", "patisserie", "bagel", "boston pizza", "scores", "mikes",
                 "cora", "nickels", "uber eats", "ubereats", "doordash", "skip the dishes", "skipthedishes", "chipotle", "la belle province", "taco bell",
                 "tacobell", "five guys", "pret a manger", "traiteur", "cantine"]
            case .grocery:
                ["iga", "metro", "maxi", "provigo", "super c", "walmart", "wal mart", "costco", "loblaws", "adonis", "marche", "epicerie", "supermarche",
                 "food basics", "freshco", "no frills", "sobeys", "safeway", "save on foods", "intermarche", "carrefour", "aldi", "lidl", "avril", "fruiterie",
                 "boucherie", "poissonnerie", "kroger", "trader joes", "whole foods", "tnt supermarket", "rachelle bery", "eleven"]
            case .fuel:
                ["esso", "shell", "petro canada", "petro", "ultramar", "couche tard", "couchetard", "circle k", "irving", "pioneer", "husky", "sunoco", "chevron",
                 "bp", "mobil", "gas bar", "station service", "essence", "carburant", "fuel"]
            case .transport:
                ["stm", "opus", "uber", "lyft", "exo", "rtc", "ttc", "via rail", "viarail", "transit", "autobus", "bus", "taxi", "taxis", "bixi", "presto",
                 "compass", "translink", "oc transpo", "navigo", "sncf", "ratp", "stationnement", "parking", "impark", "green p", "air canada", "westjet", "porter",
                 "amtrak", "greyhound", "orleans express", "saaq", "autoroute", "peage"]
            case .subscription:
                ["netflix", "spotify", "apple", "icloud", "google", "youtube", "disney", "crave", "prime video", "amazon prime", "hbo", "max", "paramount", "deezer",
                 "tidal", "audible", "patreon", "dropbox", "adobe", "microsoft", "openai", "chatgpt", "anthropic", "notion", "github", "playstation", "xbox",
                 "nintendo", "steam", "twitch", "duolingo", "canva", "zoom", "1password", "nordvpn", "expressvpn", "tou tv", "illico", "abonnement", "subscription"]
            case .health:
                ["jean coutu", "pharmaprix", "uniprix", "familiprix", "brunet", "proxim", "shoppers drug mart", "shoppers", "rexall", "lawtons", "pharmacie",
                 "pharmacy", "clinique", "dentiste", "dental", "optometriste", "lunetterie", "physio", "chiropraticien", "medecin", "hopital", "hospital", "laboratoire"]
            case .home:
                ["home depot", "rona", "reno depot", "canadian tire", "ikea", "bmr", "patrick morin", "leons", "brick", "structube", "bouclair", "hydro quebec",
                 "energir", "quincaillerie", "bricolage"]
            case .clothing:
                ["h m", "zara", "uniqlo", "simons", "winners", "marshalls", "old navy", "gap", "aritzia", "lululemon", "nike", "adidas", "sport experts",
                 "decathlon", "marks", "urban outfitters", "american eagle", "foot locker", "reitmans", "la vie en rose", "sport chek", "sportchek", "aldo",
                 "browns shoes", "vetement", "vetements", "chaussures"]
            case .leisure:
                ["cinema", "cinemas", "cineplex", "guzzo", "theatre", "spectacle", "billetterie", "ticketmaster", "evenko", "bar", "bowling", "musee", "museum",
                 "zoo", "parc", "la ronde", "gym", "fitness", "spa", "concert", "festival", "saq", "sqdc", "casino", "loto quebec"]
            case .shopping:
                ["amazon", "amzn", "ebay", "aliexpress", "temu", "shein", "etsy", "best buy", "staples", "renaud bray", "archambault", "dollarama"]
            }
        }

        /// The identifier suffix of the default category of this kind (`BudgetState.fixedID`), if there is one.
        var defaultIndex: Int? {
            switch self {
            case .grocery: 1
            case .restaurant: 2
            case .transport: 3
            case .leisure: 4
            case .home: 5
            case .fuel, .subscription, .health, .clothing, .shopping: nil
            }
        }

        /// Names (folded) a category of this kind can have when it isn't the default one.
        var categoryNames: [String] {
            switch self {
            case .grocery: ["epicerie", "courses", "alimentation", "supermarche", "groceries", "grocery"]
            case .restaurant: ["restos", "resto", "restaurant", "restaurants", "cafe", "cafes", "dining"]
            case .fuel: ["essence", "carburant", "auto", "voiture", "gas", "car"]
            case .transport: ["transport", "transports", "deplacements"]
            case .subscription: ["abonnements", "abonnement", "subscriptions", "streaming"]
            case .health: ["sante", "pharmacie", "health", "soins"]
            case .home: ["maison", "logement", "habitation", "domicile", "bricolage", "home"]
            case .clothing: ["vetements", "vetement", "habillement", "mode", "clothing", "clothes"]
            case .leisure: ["sorties", "loisirs", "divertissement", "entertainment", "culture"]
            case .shopping: ["shopping", "achats", "magasinage", "boutique"]
            }
        }

        /// The kinds tried in turn when the category of this one doesn't exist (fuel goes to transport,
        /// a subscription to outings).
        var fallbackChain: [Kind] {
            switch self {
            case .fuel: [.fuel, .transport]
            case .subscription: [.subscription, .leisure]
            default: [self]
            }
        }
    }
}

/// What `BudgetState.addApplePay` did with a payment.
enum ApplePayResult: Hashable {
    /// Recorded: the expense as saved.
    case added(Expense)
    /// The same payment (amount and shop) was received less than `ApplePayExpense.duplicateWindow` ago.
    case duplicate
    /// Not recorded, with the reason (`ApplePayExpense.Reason`): a refund, a null or unreadable amount.
    case ignored(String)
}

extension BudgetState {
    /// Records an Apple Pay payment as an expense. Nothing is invented: a refund (negative amount), a null
    /// or unreadable amount adds nothing; the same amount at the same shop within two minutes is a
    /// duplicate (the automation can run twice); an empty shop becomes « Apple Pay ». The category is the
    /// one taught for this shop (the expense is then checked) or a guess from its name, which stays « à
    /// vérifier », or none. The card is accepted but not kept.
    @discardableResult
    mutating func addApplePay(amount: Double, merchant: String, card: String?, date: Date) -> ApplePayResult {
        guard amount.isFinite else { return .ignored(ApplePayExpense.Reason.unreadable) }
        guard amount >= 0 else { return .ignored(ApplePayExpense.Reason.refund) }
        let cents = (amount * 100).rounded() / 100
        guard cents > 0 else { return .ignored(ApplePayExpense.Reason.zero) }

        let shown = ApplePayExpense.displayName(merchant)
        let key = ApplePayExpense.normalizedMerchant(shown)
        let isDuplicate = expenses.contains { other in
            other.source == .applePay
                && abs(other.date.timeIntervalSince(date)) <= ApplePayExpense.duplicateWindow
                && abs(other.amount - cents) < 0.005
                && ApplePayExpense.normalizedMerchant(other.merchant ?? ApplePayExpense.genericMerchant) == key
        }
        if isDuplicate { return .duplicate }

        let learned = ApplePayExpense.learnedCategoryID(forKey: key, in: self)
        let category = learned ?? ApplePayExpense.keywordCategoryID(forKey: key, in: self)
        let expense = Expense(amount: cents, categoryID: category, note: ApplePayExpense.noteName(shown), date: date,
                              source: .applePay, merchant: shown, needsReview: learned == nil)
        add(expense)
        return .added(expense)
    }

    /// Remembers the category the person chose for the shop of an expense, so the next payment there lands
    /// in it without a check. Does nothing for an expense without a shop or a (still existing) category, or
    /// for the bare « Apple Pay ». Lifts « à vérifier » on the saved expense.
    mutating func learnMerchantCategory(for expense: Expense) {
        guard let merchant = expense.merchant, let categoryID = expense.categoryID, category(categoryID) != nil else { return }
        let key = ApplePayExpense.normalizedMerchant(merchant)
        guard !key.isEmpty, key != ApplePayExpense.normalizedMerchant(ApplePayExpense.genericMerchant) else { return }
        // A bound on what a stream of odd names can pile up.
        guard merchantRules[key] != nil || merchantRules.count < 1_000 else { return }
        merchantRules[key] = categoryID
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) { expenses[index].needsReview = false }
    }
}
