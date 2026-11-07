import Foundation

/// Official pages of the food data sources, linked from the credits (licence conditions).
enum FoodSourceLinks {
    static let openFoodFacts = URL(string: "https://world.openfoodfacts.org")!
    static let odbl = URL(string: "https://opendatacommons.org/licenses/odbl/1-0/")!
    static let dbcl = URL(string: "https://opendatacommons.org/licenses/dbcl/1-0/")!
    static let usda = URL(string: "https://fdc.nal.usda.gov")!
    static let openGovernmentLicence = URL(string: "https://open.canada.ca/en/open-government-licence-canada")!
    static let ccBy4 = URL(string: "https://creativecommons.org/licenses/by/4.0/")!
}

/// The generic foods of the app: about 5,900 foods of the Canadian Nutrient File 2026 (Health Canada, Open Government
/// Licence – Canada) with their French and English names, and about 3,000 USDA SR Legacy foods the Canadian file does not
/// have (English names only), values per 100 g with the provenance of each value, portions, densities and the USDA
/// cooking yields of meats. It all lives in `ardane-food.sqlite` (built by `scripts/food_db/build.py`), read through
/// `SQLiteFoodRepository`, so the search finds them offline without loading the file into memory.
///
/// Where `ardane-food.sqlite` is absent the search falls back on `cnf-foods.json`, the Canadian Nutrient File 2015 the app
/// shipped until now (built by `scripts/cnf_build.py` and `scripts/cnf_extend.py`), read once, the first time someone
/// searches. That file goes away once the new base is proven in CI.
enum NutrientFile {
    private static let currentAttribution = tr("Aliments génériques : Fichier canadien sur les éléments nutritifs, Santé Canada, 2026 (licence du gouvernement ouvert – Canada), et USDA FoodData Central. Ardane n'est pas une version officielle de la FCÉN, n'est pas affilié à Santé Canada ni approuvé par lui.")
    private static let legacyAttribution = tr("Aliments génériques : Fichier canadien sur les éléments nutritifs, Santé Canada (licence du gouvernement ouvert – Canada). Ardane n'est pas affilié à Santé Canada.")

    /// The credit shown under the generic foods.
    static var attribution: String { repository == nil ? legacyAttribution : currentAttribution }

    /// The food database of the app bundle; nil where the file is absent (the old JSON answers instead).
    private static let repository: FoodRepository? = SQLiteFoodRepository.bundled()

    /// The repository behind the search (nil: the earlier JSON file is used). Portions, densities, cooking yields and the
    /// provenance of the values are read from it.
    static var foodRepository: FoodRepository? { repository }

    static var isEmpty: Bool { repository == nil && Legacy.isEmpty }

    /// The foods whose name matches every word of the query (start of a word, accents ignored), in the language shown or
    /// in the other one; the closest and shortest names first.
    static func search(_ query: String, limit: Int = 60) -> [FoodItem] {
        if let repository { return repository.search(query, limit: limit) }
        return Legacy.search(query, limit: limit)
    }

    /// One food by identifier. A `cnf.<number>` of the earlier edition is resolved to the food it became (`cnf.501098`
    /// is `cnf.6304`); nil when the identifier is not, or no longer, in the base.
    static func item(id: String) -> FoodItem? {
        if let repository { return repository.item(id: id) }
        return Legacy.item(id: id)
    }

    // MARK: The earlier file

    private enum Legacy {
        struct Entry {
            let food: FoodItem
            /// The name shown (French in French, English otherwise), then the other one.
            let shownWords: [String]
            let shownName: String
            let otherWords: [String]
        }

        static let entries: [Entry] = load()

        static var isEmpty: Bool { entries.isEmpty }

        static func item(id: String) -> FoodItem? {
            entries.first { $0.food.id == id }?.food
        }

        static func search(_ query: String, limit: Int) -> [FoodItem] {
            let q = FoodDatabase.normalized(query)
            let tokens = words(q)
            guard !tokens.isEmpty else { return [] }
            var ranked: [(Int, Int, FoodItem)] = []
            for entry in entries {
                let rank: Int
                if entry.shownName.hasPrefix(q) { rank = 0 }
                else if tokens.allSatisfy({ t in entry.shownWords.contains { $0.hasPrefix(t) } }) { rank = 1 }
                else if tokens.allSatisfy({ t in entry.otherWords.contains { $0.hasPrefix(t) } }) { rank = 2 }
                else { continue }
                ranked.append((rank, entry.shownName.count, entry.food))
            }
            return ranked.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(limit).map(\.2)
        }

        static func words(_ text: String) -> [String] {
            FoodDatabase.normalized(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }

        /// Columns 15 to 43 (`scripts/cnf_extend.py`): fats, minerals, vitamins, caffeine and alcohol, null when
        /// the file has none. A row stops after its last known value.
        static func micros(_ row: [Any]) -> Micronutrients? {
            func number(_ index: Int) -> Double? { index < row.count ? (row[index] as? NSNumber)?.doubleValue : nil }
            let micros = Micronutrients(
                monounsaturatedFat: number(15), polyunsaturatedFat: number(16), potassiumMg: number(17), calciumMg: number(18),
                ironMg: number(19), magnesiumMg: number(20), vitaminCMg: number(21), vitaminAMcg: number(22),
                vitaminDMcg: number(23), vitaminB12Mcg: number(24), folateMcg: number(25),
                transFat: number(26), omega3Fat: number(27), omega6Fat: number(28), zincMg: number(29), phosphorusMg: number(30),
                seleniumMcg: number(31), copperMg: number(32), manganeseMg: number(33), vitaminEMg: number(34), vitaminKMcg: number(35),
                thiaminMg: number(36), riboflavinMg: number(37), niacinMg: number(38), pantothenicAcidMg: number(39),
                vitaminB6Mg: number(40), cholineMg: number(41), caffeineMg: number(42), alcohol: number(43))
            return micros.isEmpty ? nil : micros
        }

        static func load() -> [Entry] {
            guard let url = Bundle.main.url(forResource: "cnf-foods", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return [] }
            let french = Localization.isFrench
            func number(_ value: Any) -> Double? { (value as? NSNumber)?.doubleValue }
            return rows.compactMap { row -> Entry? in
                guard row.count >= 15, let id = number(row[0]), let fr = row[1] as? String, let en = row[2] as? String,
                      let kcal = number(row[3]) else { return nil }
                let name = french ? fr : en
                let serving = number(row[12]) ?? 100
                // A macronutrient or fibre the table does not give is unknown, not zero: 0 is stored but flagged.
                var unknown = Set<MacroField>()
                if number(row[4]) == nil { unknown.insert(.protein) }
                if number(row[5]) == nil { unknown.insert(.carbs) }
                if number(row[6]) == nil { unknown.insert(.fat) }
                let food = FoodItem(
                    id: "cnf.\(Int(id))", name: name, brand: nil, kcal: kcal,
                    protein: number(row[4]) ?? 0, carbs: number(row[5]) ?? 0, fat: number(row[6]) ?? 0, fiber: number(row[7]) ?? 0,
                    servingGrams: serving > 0 ? serving : 100,
                    servingName: ((french ? row[13] : row[14]) as? String) ?? "100 g",
                    source: .nutrientFile, barcode: nil,
                    sugars: number(row[8]), saturatedFat: number(row[9]), sodiumMg: number(row[10]), cholesterolMg: number(row[11]),
                    micros: micros(row), unknownMacros: unknown.isEmpty ? nil : unknown,
                    fiberUnknown: number(row[7]) == nil ? true : nil)
                return Entry(food: food, shownWords: words(name), shownName: FoodDatabase.normalized(name), otherWords: words(french ? en : fr))
            }
        }
    }
}
