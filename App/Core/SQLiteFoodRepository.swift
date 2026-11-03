import Foundation
import SQLite3

/// The text key of the search: the same rule as `normalize` and `words` of `scripts/food_db/common.py` (which wrote the
/// index): compatibility decomposition, accents removed, lower case, ligatures spelled out; words are the runs of
/// letters and digits. Change both together.
enum FoodSearchKey {
    private static let ligatures: [(String, String)] = [("œ", "oe"), ("æ", "ae"), ("ß", "ss"), ("ø", "o"), ("ł", "l"), ("đ", "d")]

    static func normalized(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.decomposedStringWithCompatibilityMapping.unicodeScalars where scalar.properties.generalCategory != .nonspacingMark {
            scalars.append(scalar)
        }
        var result = String(scalars).lowercased()
        for (ligature, plain) in ligatures where result.contains(ligature) {
            result = result.replacingOccurrences(of: ligature, with: plain)
        }
        return result
    }

    static func words(_ text: String) -> [String] {
        normalized(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}

/// `SQLITE_TRANSIENT`: SQLite copies the text it is given (the macro is not imported into Swift).
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// One prepared statement, finalized when it goes out of scope.
private final class SQLiteStatement {
    let handle: OpaquePointer

    init?(_ database: OpaquePointer, _ sql: String) {
        var raw: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &raw, nil) == SQLITE_OK, let prepared = raw else {
            sqlite3_finalize(raw)
            return nil
        }
        handle = prepared
    }

    deinit { sqlite3_finalize(handle) }

    func bind(_ index: Int32, int value: Int) { sqlite3_bind_int64(handle, index, Int64(value)) }
    func bind(_ index: Int32, text value: String) { sqlite3_bind_text(handle, index, value, -1, sqliteTransient) }

    /// True while a row is available.
    func step() -> Bool { sqlite3_step(handle) == SQLITE_ROW }

    func isNull(_ column: Int32) -> Bool { sqlite3_column_type(handle, column) == SQLITE_NULL }
    func int(_ column: Int32) -> Int { Int(sqlite3_column_int64(handle, column)) }
    func double(_ column: Int32) -> Double { sqlite3_column_double(handle, column) }
    func optionalInt(_ column: Int32) -> Int? { isNull(column) ? nil : int(column) }
    func optionalDouble(_ column: Int32) -> Double? { isNull(column) ? nil : double(column) }

    func text(_ column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: pointer)
    }
}

/// `FoodRepository` over `ardane-food.sqlite` (built by `scripts/food_db/build.py`), opened read-only from the app
/// bundle. Not in the widget extension: the file is not copied there.
///
/// - Identifiers: `cnf.<Food_Code>` (Canadian Nutrient File 2026) and `usda.<NDB>` (USDA SR Legacy foods the Canadian
///   file does not have). `cnf.<number>` of the earlier edition that is not a current Food_Code goes through `alias`.
/// - Every food it returns has `source == .nutrientFile`; there is no separate case for USDA.
/// - A nutrient the pack has no row for is nil (or, for a macronutrient, listed in `unknownMacros`), never 0.
final class SQLiteFoodRepository: FoodRepository {
    /// `food.id` from here on is a USDA food: `usda.<id - 100000>`.
    private static let usdaBase = 100_000
    private static let supportedVersion = 1
    private static let maximumTokens = 8

    private let database: OpaquePointer

    init?(url: URL) {
        var raw: OpaquePointer?
        guard sqlite3_open_v2(url.path, &raw, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let connection = raw else {
            sqlite3_close(raw)
            return nil
        }
        guard SQLiteFoodRepository.hasSupportedSchema(connection) else {
            sqlite3_close(connection)
            return nil
        }
        database = connection
    }

    deinit { sqlite3_close(database) }

    /// The repository of the app bundle; nil where `ardane-food.sqlite` is absent or not readable.
    static func bundled(bundle: Bundle = .main) -> SQLiteFoodRepository? {
        guard let url = bundle.url(forResource: "ardane-food", withExtension: "sqlite") else { return nil }
        return SQLiteFoodRepository(url: url)
    }

    private static func hasSupportedSchema(_ connection: OpaquePointer) -> Bool {
        guard let version = SQLiteStatement(connection, "PRAGMA user_version"), version.step() else { return false }
        return version.int(0) == supportedVersion
    }

    private func prepare(_ sql: String) -> SQLiteStatement? {
        SQLiteStatement(database, sql)
    }

    // MARK: Identifiers

    static func identifier(ofDatabaseID databaseID: Int) -> String {
        databaseID >= usdaBase ? "usda.\(databaseID - usdaBase)" : "cnf.\(databaseID)"
    }

    /// The `food.id` an identifier writes, or nil when it is not of the form of the pack (`builtin.*`, `off.*`…). An old
    /// `cnf.<FoodID>` can name a food that is not in the pack: the caller checks, then tries the alias.
    static func databaseID(ofIdentifier identifier: String) -> Int? {
        func number(after prefix: String) -> Int? {
            let digits = identifier.dropFirst(prefix.count)
            guard !digits.isEmpty, digits.count <= 9, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(digits)
        }
        if identifier.hasPrefix("cnf.") {
            guard let value = number(after: "cnf."), value < usdaBase else { return nil }
            return value
        }
        if identifier.hasPrefix("usda.") {
            guard let value = number(after: "usda."), value < usdaBase else { return nil }
            return usdaBase + value
        }
        return nil
    }

    private func exists(_ databaseID: Int) -> Bool {
        guard let row = prepare("SELECT 1 FROM food WHERE id = ?") else { return false }
        row.bind(1, int: databaseID)
        return row.step()
    }

    /// The `food.id` of an identifier today: itself, or the one the alias table gives.
    private func resolvedDatabaseID(of identifier: String) -> Int? {
        if let direct = Self.databaseID(ofIdentifier: identifier), exists(direct) { return direct }
        guard identifier.hasPrefix("cnf."), let alias = prepare("SELECT food_id FROM alias WHERE old = ?") else { return nil }
        alias.bind(1, text: identifier)
        return alias.step() ? alias.int(0) : nil
    }

    func resolvedID(of id: String) -> String? {
        resolvedDatabaseID(of: id).map { Self.identifier(ofDatabaseID: $0) }
    }

    // MARK: Search

    func search(_ query: String, limit: Int, preferFrench: Bool) -> [FoodItem] {
        let tokens = Array(FoodSearchKey.words(query).prefix(Self.maximumTokens))
        guard !tokens.isEmpty, limit > 0 else { return [] }
        let normalizedQuery = FoodSearchKey.normalized(query).trimmingCharacters(in: .whitespacesAndNewlines)

        // Every word of the query must start a word of a name or an alternate name (the index is `word`).
        let clause = "id IN (SELECT food_id FROM word WHERE term >= ? AND term < ?)"
        let sql = "SELECT id, name_fr, name_en, source FROM food WHERE "
            + Array(repeating: clause, count: tokens.count).joined(separator: " AND ")
        guard let rows = prepare(sql) else { return [] }
        for (index, token) in tokens.enumerated() {
            rows.bind(Int32(index * 2 + 1), text: token)
            rows.bind(Int32(index * 2 + 2), text: token + "\u{10FFFF}")
        }

        func matches(_ words: [String]) -> Bool {
            tokens.allSatisfy { token in words.contains { $0.hasPrefix(token) } }
        }

        // Closest first: the name starts with the query, then every word starts a word of the name shown, then of the
        // name in the other language, then across both, then only through an alternate name; shorter names first.
        var candidates: [(rank: Int, length: Int, source: Int, id: Int)] = []
        while rows.step() {
            let id = rows.int(0)
            let nameFrench = rows.text(1)
            let nameEnglish = rows.text(2) ?? ""
            let shown = preferFrench ? (nameFrench ?? nameEnglish) : nameEnglish
            let other = preferFrench ? (nameFrench == nil ? "" : nameEnglish) : (nameFrench ?? "")
            let shownKey = FoodSearchKey.normalized(shown)
            let shownWords = FoodSearchKey.words(shown)
            let rank: Int
            if shownKey.hasPrefix(normalizedQuery) {
                rank = 0
            } else if matches(shownWords) {
                rank = 1
            } else {
                let otherWords = FoodSearchKey.words(other)
                if matches(otherWords) { rank = 2 }
                else if matches(shownWords + otherWords) { rank = 3 }
                else { rank = 4 }
            }
            candidates.append((rank: rank, length: shownKey.count, source: rows.int(3), id: id))
        }
        candidates.sort { ($0.rank, $0.length, $0.source, $0.id) < ($1.rank, $1.length, $1.source, $1.id) }
        return candidates.prefix(limit).compactMap { makeItem(databaseID: $0.id, preferFrench: preferFrench) }
    }

    // MARK: One food

    func item(id: String, preferFrench: Bool) -> FoodItem? {
        guard let databaseID = resolvedDatabaseID(of: id) else { return nil }
        return makeItem(databaseID: databaseID, preferFrench: preferFrench)
    }

    private func nutrientValues(of databaseID: Int) -> [Int: Double] {
        var result: [Int: Double] = [:]
        guard let rows = prepare("SELECT nutrient_id, value FROM nutrient_value WHERE food_id = ?") else { return result }
        rows.bind(1, int: databaseID)
        while rows.step() { result[rows.int(0)] = rows.double(1) }
        return result
    }

    /// The serving proposed by default (grams, label), or 100 g.
    private func defaultServing(of databaseID: Int, preferFrench: Bool) -> (grams: Double, name: String) {
        let sql = "SELECT m.label_en, m.label_fr, p.grams FROM portion p JOIN measure m ON m.id = p.measure_id WHERE p.food_id = ? AND p.preferred = 1 LIMIT 1"
        let hundredGrams: (grams: Double, name: String) = (grams: 100, name: "100 g")
        guard let row = prepare(sql) else { return hundredGrams }
        row.bind(1, int: databaseID)
        guard row.step() else { return hundredGrams }
        let label = (preferFrench ? row.text(1) : nil) ?? row.text(0) ?? "100 g"
        let grams = row.double(2)
        guard grams > 0 else { return hundredGrams }
        return (grams: grams, name: label)
    }

    private func makeItem(databaseID: Int, preferFrench: Bool) -> FoodItem? {
        guard let food = prepare("SELECT name_fr, name_en FROM food WHERE id = ?") else { return nil }
        food.bind(1, int: databaseID)
        guard food.step() else { return nil }
        let nameFrench = food.text(0)
        let nameEnglish = food.text(1) ?? ""
        let values = nutrientValues(of: databaseID)
        // A food without an energy value cannot be logged; the build leaves such foods out.
        guard let kcal = values[FoodNutrientCode.energy] else { return nil }

        // Unknown macronutrients are marked, not shown as a measured zero.
        var unknown = Set<MacroField>()
        func macro(_ code: Int, _ field: MacroField) -> Double {
            if let value = values[code] { return value }
            unknown.insert(field)
            return 0
        }
        let protein = macro(FoodNutrientCode.protein, .protein)
        let carbs = macro(FoodNutrientCode.carbs, .carbs)
        let fat = macro(FoodNutrientCode.fat, .fat)

        let micros = Micronutrients(
            monounsaturatedFat: values[645], polyunsaturatedFat: values[646], potassiumMg: values[306], calciumMg: values[301],
            ironMg: values[303], magnesiumMg: values[304], vitaminCMg: values[401], vitaminAMcg: values[320],
            vitaminDMcg: values[328], vitaminB12Mcg: values[418], folateMcg: values[435],
            transFat: values[605], omega3Fat: values[FoodNutrientCode.omega3], omega6Fat: values[FoodNutrientCode.omega6],
            zincMg: values[309], phosphorusMg: values[305], seleniumMcg: values[317], copperMg: values[312],
            manganeseMg: values[315], vitaminEMg: values[323], vitaminKMcg: values[430],
            thiaminMg: values[404], riboflavinMg: values[405], niacinMg: values[409] ?? values[406], pantothenicAcidMg: values[410],
            vitaminB6Mg: values[415], cholineMg: values[421], caffeineMg: values[262], alcohol: values[221])
        let serving = defaultServing(of: databaseID, preferFrench: preferFrench)

        return FoodItem(
            id: Self.identifier(ofDatabaseID: databaseID), name: preferFrench ? (nameFrench ?? nameEnglish) : nameEnglish, brand: nil,
            kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: values[FoodNutrientCode.fibre] ?? 0,
            servingGrams: serving.grams, servingName: serving.name, source: .nutrientFile, barcode: nil,
            sugars: values[FoodNutrientCode.sugars], saturatedFat: values[FoodNutrientCode.saturatedFat],
            sodiumMg: values[FoodNutrientCode.sodium], cholesterolMg: values[FoodNutrientCode.cholesterol],
            micros: micros.isEmpty ? nil : micros, unknownMacros: unknown.isEmpty ? nil : unknown)
    }

    // MARK: Portions, densities, yields

    func portions(id: String, preferFrench: Bool) -> [RepositoryPortion] {
        let sql = """
            SELECT m.label_en, m.label_fr, m.ml, p.grams, p.kind, p.preferred FROM portion p JOIN measure m ON m.id = p.measure_id \
            WHERE p.food_id = ? ORDER BY CASE p.kind WHEN 6 THEN 0 WHEN 9 THEN 1 ELSE 2 END, p.pos
            """
        guard let databaseID = resolvedDatabaseID(of: id), let rows = prepare(sql) else { return [] }
        rows.bind(1, int: databaseID)
        var result: [RepositoryPortion] = []
        while rows.step() {
            let label = (preferFrench ? rows.text(1) : nil) ?? rows.text(0) ?? ""
            result.append(RepositoryPortion(
                label: label, grams: rows.double(3), kind: RepositoryPortion.Kind(rawValue: rows.int(4)) ?? .conversion,
                isDefault: rows.optionalInt(5) == 1, milliliters: rows.optionalDouble(2)))
        }
        return result
    }

    private static func densityOrder(_ kind: RepositoryDensity.Kind) -> Int {
        switch kind {
        case .plain: return 0
        case .container: return 1
        case .dense: return 2
        case .pieces: return 3
        }
    }

    func densities(id: String) -> [RepositoryDensity] {
        let sql = """
            SELECT d.g_per_ml, d.kind, m.label_en, m.ml, p.grams FROM density d JOIN measure m ON m.id = d.measure_id \
            JOIN portion p ON p.food_id = d.food_id AND p.measure_id = d.measure_id WHERE d.food_id = ?
            """
        guard let databaseID = resolvedDatabaseID(of: id), let rows = prepare(sql) else { return [] }
        rows.bind(1, int: databaseID)
        var result: [RepositoryDensity] = []
        while rows.step() {
            guard let kind = RepositoryDensity.Kind(rawValue: rows.int(1)), let milliliters = rows.optionalDouble(3) else { continue }
            result.append(RepositoryDensity(
                gPerMl: rows.double(0), kind: kind, measure: rows.text(2) ?? "", measureGrams: rows.double(4), milliliters: milliliters))
        }
        // A plain measure first, then the contents of a container, then dense, then pieces; the larger volume first
        // (a cup says more than a teaspoon).
        result.sort { (Self.densityOrder($0.kind), -$0.milliliters, $0.measure) < (Self.densityOrder($1.kind), -$1.milliliters, $1.measure) }
        return result
    }

    func cookingYields(id: String) -> [RepositoryYield] {
        let sql = "SELECT raw_id, method, percent, n, sd, minimum, maximum, moisture, fat FROM prep_link WHERE cooked_id = ? ORDER BY method, percent"
        guard let databaseID = resolvedDatabaseID(of: id), let rows = prepare(sql) else { return [] }
        rows.bind(1, int: databaseID)
        var result: [RepositoryYield] = []
        while rows.step() {
            result.append(RepositoryYield(
                method: rows.text(1) ?? "", percent: rows.double(2), observations: rows.optionalInt(3), standardDeviation: rows.optionalDouble(4),
                minimumPercent: rows.optionalDouble(5), maximumPercent: rows.optionalDouble(6),
                moistureChangePercent: rows.optionalDouble(7), fatChangePercent: rows.optionalDouble(8),
                rawFoodID: rows.optionalInt(0).map { Self.identifier(ofDatabaseID: $0) }))
        }
        return result
    }

    // MARK: Provenance and checks

    func provenance(id: String, nutrient: Int) -> RepositoryProvenance? {
        let sql = "SELECT v.prov, f.source FROM nutrient_value v JOIN food f ON f.id = v.food_id WHERE v.food_id = ? AND v.nutrient_id = ?"
        guard let databaseID = resolvedDatabaseID(of: id), let row = prepare(sql) else { return nil }
        row.bind(1, int: databaseID)
        row.bind(2, int: nutrient)
        guard row.step() else { return nil }
        let source = row.int(1)
        guard !row.isNull(0) else { return RepositoryProvenance(sourceCode: nil, kind: nil, label: nil, observations: nil, standardError: nil) }

        // `nutrient_value.prov`: bits 0-6 source code + 1, bits 7-18 observations, bits 19 and up standard error x 10000.
        let packed = row.int(0)
        let field = packed & 0x7F
        let observations = (packed >> 7) & 0xFFF
        let scaledError = packed >> 19
        let code: Int? = field == 0 ? nil : field - 1

        var kind: RepositoryProvenance.Kind?
        var label: String?
        if let code, let meaning = prepare("SELECT class, label_en, label_fr FROM prov_code WHERE source = ? AND code = ?") {
            meaning.bind(1, int: source)
            meaning.bind(2, int: code)
            if meaning.step() {
                kind = RepositoryProvenance.Kind(rawValue: meaning.int(0))
                label = (Localization.isFrench ? meaning.text(2) : nil) ?? meaning.text(1)
            }
        }
        return RepositoryProvenance(
            sourceCode: code, kind: kind, label: label, observations: observations == 0 ? nil : observations,
            standardError: scaledError == 0 ? nil : Double(scaledError) / 10_000)
    }

    private func foodColumns(_ id: String) -> (qc: Int, prep: Int)? {
        guard let databaseID = resolvedDatabaseID(of: id), let row = prepare("SELECT qc, prep FROM food WHERE id = ?") else { return nil }
        row.bind(1, int: databaseID)
        guard row.step() else { return nil }
        return (qc: row.int(0), prep: row.int(1))
    }

    func qualityFlags(id: String) -> FoodQualityFlags? {
        foodColumns(id).map { FoodQualityFlags(rawValue: $0.qc) }
    }

    func preparationState(id: String) -> FoodPreparationState? {
        foodColumns(id).flatMap { FoodPreparationState(rawValue: $0.prep) }
    }
}
