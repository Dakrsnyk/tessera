import Foundation

/// About 5,600 generic foods from the Canadian Nutrient File (Health Canada, CNF 2015, Open
/// Government Licence – Canada), with their French and English names and values per 100 g.
/// Bundled with the app (`cnf-foods.json`, built by `scripts/cnf_build.py`), so the search finds
/// them offline; read once, the first time someone searches.
enum NutrientFile {
    static let attribution = tr("Aliments génériques : Fichier canadien sur les éléments nutritifs, Santé Canada.")

    private struct Entry {
        let food: FoodItem
        /// The name shown (French in French, English otherwise), then the other one.
        let shownWords: [String]
        let shownName: String
        let otherWords: [String]
    }

    private static let entries: [Entry] = load()

    static var isEmpty: Bool { entries.isEmpty }

    /// The foods whose name matches every word of the query (start of a word, accents ignored), in
    /// the language shown or in the other one; the closest and shortest names first.
    static func search(_ query: String, limit: Int = 60) -> [FoodItem] {
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

    private static func words(_ text: String) -> [String] {
        FoodDatabase.normalized(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private static func load() -> [Entry] {
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
            let food = FoodItem(
                id: "cnf.\(Int(id))", name: name, brand: nil, kcal: kcal,
                protein: number(row[4]) ?? 0, carbs: number(row[5]) ?? 0, fat: number(row[6]) ?? 0, fiber: number(row[7]) ?? 0,
                servingGrams: serving > 0 ? serving : 100,
                servingName: ((french ? row[13] : row[14]) as? String) ?? "100 g",
                source: .nutrientFile, barcode: nil,
                sugars: number(row[8]), saturatedFat: number(row[9]), sodiumMg: number(row[10]), cholesterolMg: number(row[11]))
            return Entry(food: food, shownWords: words(name), shownName: FoodDatabase.normalized(name), otherWords: words(french ? en : fr))
        }
    }
}
