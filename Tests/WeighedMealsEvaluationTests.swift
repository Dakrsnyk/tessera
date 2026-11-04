import XCTest
import UIKit
import Vision
import CryptoKit
@testable import Ardane

// Measure of the REAL precision of the food scanner on WEIGHED meals (photo + weight of every food read on a kitchen scale).
// Protocol: docs/scanner/Protocole-mesure.md. Dataset format: Tests/Fixtures/WeighedMeals/README.md and manifest.schema.json.
//
// Rules this file keeps:
//  - the weights come from the dataset (a scale), never from this code; the reference calories and macros are computed from the
//    food tables of the app; nothing is estimated here;
//  - with no weighed meal the test says so and passes: it prints no figure;
//  - a result measured on the simulator is labelled as such: it is never an iPhone result.

// MARK: - Dataset model (meals.json)

struct WeighedMealsManifest: Decodable {
    let schemaVersion: Int
    let dataset: WeighedDataset
    let meals: [WeighedMeal]
}

struct WeighedDataset: Decodable {
    let name: String
    let createdAt: String
    let example: Bool?
    let notes: String?

    /// The structure example (`meals.example.json`) is never measured.
    var isExample: Bool { example ?? false }
}

struct WeighedPhoto: Decodable {
    let file: String
    let capturedAt: String
    let sha256: String?
    let widthPx: Int?
    let heightPx: Int?
}

struct WeighedRights: Decodable {
    let origin: String
    let license: String
    let consent: Bool
    let consentDate: String?
    let author: String?
    let sourceURL: String?
    let commercialUseAllowed: Bool
    let containsPeopleOrPersonalData: Bool
    let exifLocationRemoved: Bool
}

struct WeighedDevice: Decodable {
    let model: String
    let iosVersion: String
    let lens: String
    let lidar: Bool
}

struct WeighedCapture: Decodable {
    let lighting: String
    let tableware: String
    let angle: String
    let distanceCm: Double
    let plateDiameterCm: Double?
    let referenceObject: String
}

struct WeighedWeighing: Decodable {
    let scaleModel: String
    let resolutionG: Double
    let method: String
}

/// Values per 100 g read on the label of a product (or of a recipe ingredient that is not in the tables).
struct WeighedPer100: Decodable {
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?

    var isPlausible: Bool {
        [kcal, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 }
            && kcal <= 900 && protein + carbs + fat <= 100.5
    }
}

struct WeighedIngredient: Decodable {
    let foodID: String
    let foodName: String
    let grams: Double
    let nutrientsPer100g: WeighedPer100?
}

/// A homemade dish: the ingredients weighed when cooking and the total weight once cooked. The reference values of a
/// portion are the ingredients' values times (portion weight / cooked weight).
struct WeighedRecipe: Decodable {
    let totalCookedG: Double
    let ingredients: [WeighedIngredient]
}

struct WeighedMask: Decodable {
    let file: String
}

struct WeighedItem: Decodable {
    let foodID: String
    let foodName: String
    let grams: Double
    let state: String
    let acceptedFoodIDs: [String]?
    let visible: Bool?
    let nutrientsPer100g: WeighedPer100?
    let recipe: WeighedRecipe?
    let mask: WeighedMask?

    /// False for what the photo cannot show (oil in the pan, butter, a sauce under the cheese).
    var isVisible: Bool { visible ?? true }
    /// The identifiers that count as this food when the scanner proposes it.
    var acceptedIDs: Set<String> { Set([foodID] + (acceptedFoodIDs ?? [])) }
}

struct WeighedMeal: Decodable {
    let id: String
    let split: String
    let groupID: String
    let cuisine: String
    let mealType: String
    let notes: String?
    let photo: WeighedPhoto
    let rights: WeighedRights
    let device: WeighedDevice
    let capture: WeighedCapture
    let weighing: WeighedWeighing
    let items: [WeighedItem]
}

/// The allowed values of the dataset. `manifest.schema.json` carries the same lists: a test compares them.
enum WeighedMealsVocabulary {
    static let splits = ["train", "validation", "test"]
    static let cuisines = ["quebecoise", "nord-americaine", "francaise", "mediterraneenne", "italienne", "mexicaine",
                           "asiatique-de-lest", "asiatique-du-sud", "moyen-orientale", "africaine", "autre"]
    static let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    static let lenses = ["main", "ultrawide", "telephoto", "front", "other"]
    static let lightings = ["daylight-window", "daylight-outdoor", "warm-indoor", "cool-indoor", "dim", "flash", "mixed"]
    static let tablewares = ["flat-plate", "deep-plate", "bowl", "board", "takeout-box", "tray", "hand-held", "other"]
    static let angles = ["top-down", "oblique-45", "oblique-30", "side"]
    static let referenceObjects = ["none", "card", "coin", "hand", "other"]
    static let cookingStates = ["raw", "cooked", "not-applicable"]
    static let weighingMethods = ["tare-sequence", "separate-weighing", "recipe-share"]
    static let rightsOrigins = ["own-photo", "licensed-dataset"]
    static let licenses = ["owner-consent", "CC0", "public-domain", "CC BY 2.0", "CC BY 3.0", "CC BY 4.0"]

    /// The name of each list in `$defs` of the schema.
    static let bySchemaName: [String: [String]] = [
        "split": splits, "cuisine": cuisines, "mealType": mealTypes, "lens": lenses, "lighting": lightings,
        "tableware": tablewares, "angle": angles, "referenceObject": referenceObjects, "cookingState": cookingStates,
        "weighingMethod": weighingMethods, "rightsOrigin": rightsOrigins, "license": licenses,
    ]
}

// MARK: - Foods and validation

enum WeighedFoodBase {
    /// `builtin.*`: the built-in table. `cnf.*`: the Canadian Nutrient File, found through the name written in the dataset.
    static func lookup(_ id: String, _ name: String?) -> FoodItem? {
        if id.hasPrefix("builtin.") { return FoodDatabase.item(id) }
        if id.hasPrefix("cnf."), let name, !name.isEmpty {
            return NutrientFile.search(name, limit: 5_000).first { $0.id == id }
        }
        return nil
    }
}

extension WeighedMealsManifest {
    /// The food of the tables for an id, or the one built from the values of the label written in the dataset.
    static func food(id: String, name: String, per100: WeighedPer100?, lookup: (String, String?) -> FoodItem?) -> FoodItem? {
        if let per100 {
            return FoodItem(id: id, name: name, brand: nil, kcal: per100.kcal, protein: per100.protein, carbs: per100.carbs,
                            fat: per100.fat, fiber: per100.fiber ?? 0, servingGrams: 100, servingName: "100 g",
                            source: .custom, barcode: nil)
        }
        return lookup(id, name)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static let identifierPattern = "^[a-z0-9][a-z0-9-]{1,63}$"
    private static let relativePathPattern = "^[A-Za-z0-9._/-]+$"

    /// Everything wrong with the dataset (an empty list = valid). `resolveFile`: where a file of the dataset is on disk
    /// (nil: the files are not checked).
    func validationProblems(resolveFile: ((String) -> URL?)?, lookup: (String, String?) -> FoodItem?) -> [String] {
        typealias V = WeighedMealsVocabulary
        var problems: [String] = []
        if schemaVersion != 1 { problems.append("schemaVersion \(schemaVersion) non géré (1 attendu)") }
        var ids = Set<String>()
        var photos = Set<String>()
        var splitOfGroup: [String: String] = [:]

        func checkFile(_ relative: String, label: String, kind: String, extensions: [String], sha256: String?) -> [String] {
            var found: [String] = []
            let ext = (relative as NSString).pathExtension
            if relative.hasPrefix("/") || relative.contains("..") || !Self.matches(relative, Self.relativePathPattern)
                || !extensions.contains(ext) {
                found.append("\(label) : chemin de \(kind) invalide « \(relative) » (relatif, sans « .. », extensions \(extensions.joined(separator: "/")))")
                return found
            }
            guard let resolveFile else { return found }
            guard let url = resolveFile(relative), let data = try? Data(contentsOf: url) else {
                found.append("\(label) : \(kind) introuvable « \(relative) »")
                return found
            }
            if let sha256, Self.sha256Hex(data) != sha256 {
                found.append("\(label) : somme SHA-256 de « \(relative) » différente de celle du jeu (fichier modifié ?)")
            }
            return found
        }

        for meal in meals {
            let name = meal.id
            if !ids.insert(meal.id).inserted { problems.append("\(name) : identifiant de repas en double") }
            if !Self.matches(meal.id, Self.identifierPattern) { problems.append("\(name) : identifiant invalide (a-z, 0-9, tirets, 2 à 64 caractères)") }
            if !V.splits.contains(meal.split) { problems.append("\(name) : split inconnu « \(meal.split) »") }
            if !V.cuisines.contains(meal.cuisine) { problems.append("\(name) : cuisine inconnue « \(meal.cuisine) »") }
            if !V.mealTypes.contains(meal.mealType) { problems.append("\(name) : type de repas inconnu « \(meal.mealType) »") }
            if !Self.matches(meal.groupID, Self.identifierPattern) { problems.append("\(name) : groupID invalide") }
            // No leakage: one group (same plate, same preparation, same recipe) lives in ONE split.
            if let known = splitOfGroup[meal.groupID], known != meal.split {
                problems.append("\(name) : fuite entre jeux, le groupe « \(meal.groupID) » est dans « \(known) » et dans « \(meal.split) »")
            } else {
                splitOfGroup[meal.groupID] = meal.split
            }

            // Photo.
            if !photos.insert(meal.photo.file).inserted { problems.append("\(name) : photo « \(meal.photo.file) » déjà utilisée par un autre repas") }
            problems += checkFile(meal.photo.file, label: name, kind: "photo", extensions: ["jpg", "jpeg", "png", "heic"], sha256: meal.photo.sha256)
            if ISO8601DateFormatter().date(from: meal.photo.capturedAt) == nil { problems.append("\(name) : capturedAt illisible (AAAA-MM-JJThh:mm:ssZ attendu)") }
            if let sha = meal.photo.sha256, !Self.matches(sha, "^[0-9a-f]{64}$") { problems.append("\(name) : sha256 invalide (64 caractères hexadécimaux en minuscules)") }

            // Rights and consent.
            let rights = meal.rights
            if !V.rightsOrigins.contains(rights.origin) { problems.append("\(name) : origine des droits inconnue « \(rights.origin) »") }
            if !V.licenses.contains(rights.license) { problems.append("\(name) : licence inconnue « \(rights.license) »") }
            if !rights.consent { problems.append("\(name) : consentement non donné, photo inutilisable") }
            if !rights.commercialUseAllowed { problems.append("\(name) : usage commercial non autorisé, photo inutilisable") }
            if rights.containsPeopleOrPersonalData { problems.append("\(name) : la photo montre des personnes ou des données personnelles, inutilisable") }
            if !rights.exifLocationRemoved { problems.append("\(name) : métadonnées de position (EXIF) non retirées") }
            if rights.origin == "own-photo" {
                if rights.license != "owner-consent" { problems.append("\(name) : une photo personnelle doit avoir la licence owner-consent") }
                if !Self.matches(rights.consentDate ?? "", "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") { problems.append("\(name) : date du consentement manquante (AAAA-MM-JJ)") }
            } else if rights.origin == "licensed-dataset" {
                if rights.license == "owner-consent" { problems.append("\(name) : un jeu sous licence doit citer sa licence (CC0, domaine public, CC BY)") }
                if (rights.author ?? "").isEmpty || (rights.sourceURL ?? "").isEmpty { problems.append("\(name) : auteur et URL de la source requis") }
            }

            // Device and conditions.
            if meal.device.model.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("\(name) : modèle d'appareil manquant") }
            if !Self.matches(meal.device.iosVersion, "^[0-9]+(\\.[0-9]+){0,2}$") { problems.append("\(name) : version d'iOS invalide « \(meal.device.iosVersion) »") }
            if !V.lenses.contains(meal.device.lens) { problems.append("\(name) : objectif inconnu « \(meal.device.lens) »") }
            let capture = meal.capture
            if !V.lightings.contains(capture.lighting) { problems.append("\(name) : éclairage inconnu « \(capture.lighting) »") }
            if !V.tablewares.contains(capture.tableware) { problems.append("\(name) : vaisselle inconnue « \(capture.tableware) »") }
            if !V.angles.contains(capture.angle) { problems.append("\(name) : angle inconnu « \(capture.angle) »") }
            if !V.referenceObjects.contains(capture.referenceObject) { problems.append("\(name) : objet de référence inconnu « \(capture.referenceObject) »") }
            if !(10.0...200.0).contains(capture.distanceCm) { problems.append("\(name) : distance hors de 10 à 200 cm") }
            if let plate = capture.plateDiameterCm, !(5.0...50.0).contains(plate) { problems.append("\(name) : diamètre d'assiette hors de 5 à 50 cm") }

            // Scale.
            let weighing = meal.weighing
            if weighing.scaleModel.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("\(name) : modèle de balance manquant") }
            if !(0.01...5.0).contains(weighing.resolutionG) { problems.append("\(name) : résolution de la balance hors de 0,01 à 5 g") }
            if !V.weighingMethods.contains(weighing.method) { problems.append("\(name) : méthode de pesée inconnue « \(weighing.method) »") }

            // Foods and weights.
            if meal.items.isEmpty { problems.append("\(name) : aucun aliment") }
            if !meal.items.isEmpty && !meal.items.contains(where: { $0.isVisible }) { problems.append("\(name) : aucun aliment visible, repas inutilisable") }
            for item in meal.items {
                let label = "\(name)/\(item.foodID)"
                if !Self.matches(item.foodID, "^(builtin|cnf|off|custom)\\.[A-Za-z0-9_-]+$") { problems.append("\(label) : foodID invalide (builtin.*, cnf.*, off.* ou custom.*)") }
                if !(item.grams > 0 && item.grams <= 5_000) {
                    problems.append("\(label) : poids hors de 0 à 5 000 g")
                } else if weighing.resolutionG > 0 {
                    let steps = item.grams / weighing.resolutionG
                    if abs(steps - steps.rounded()) > 1e-6 {
                        problems.append("\(label) : \(item.grams) g n'est pas un multiple de la résolution de la balance (\(weighing.resolutionG) g), poids non lu sur la balance ?")
                    }
                }
                if !V.cookingStates.contains(item.state) { problems.append("\(label) : état inconnu « \(item.state) »") }
                if let per100 = item.nutrientsPer100g, !per100.isPlausible { problems.append("\(label) : valeurs pour 100 g impossibles") }
                if let recipe = item.recipe {
                    if !(recipe.totalCookedG >= item.grams) { problems.append("\(label) : le poids total cuit de la recette est inférieur à la portion") }
                    if recipe.ingredients.isEmpty { problems.append("\(label) : recette sans ingrédient") }
                    for ingredient in recipe.ingredients {
                        let ingredientLabel = "\(label)/\(ingredient.foodID)"
                        if !(ingredient.grams > 0) { problems.append("\(ingredientLabel) : poids d'ingrédient invalide") }
                        if let per100 = ingredient.nutrientsPer100g, !per100.isPlausible { problems.append("\(ingredientLabel) : valeurs pour 100 g impossibles") }
                        if Self.food(id: ingredient.foodID, name: ingredient.foodName, per100: ingredient.nutrientsPer100g, lookup: lookup) == nil {
                            problems.append("\(ingredientLabel) : ingrédient introuvable dans les tables et sans valeurs d'étiquette")
                        }
                    }
                } else if let food = Self.food(id: item.foodID, name: item.foodName, per100: item.nutrientsPer100g, lookup: lookup) {
                    // The state written must not contradict the name of the food of the table (« cuit », « cru »).
                    if item.nutrientsPer100g == nil {
                        switch (FoodLabelMatcher.cookingState(of: food), item.state) {
                        case (.raw?, "cooked"), (.cooked?, "raw"):
                            problems.append("\(label) : l'état « \(item.state) » contredit le nom de l'aliment de la table « \(food.name) »")
                        default:
                            break
                        }
                    }
                } else {
                    problems.append("\(label) : aliment introuvable dans les tables (builtin.* ou cnf.* avec son nom) et sans valeurs d'étiquette")
                }
                if let mask = item.mask {
                    problems += checkFile(mask.file, label: label, kind: "masque", extensions: ["png"], sha256: nil)
                }
            }
        }
        return problems
    }
}

// MARK: - Scoring of one meal

/// An expected food that the scanner proposed: where, and with how many grams against the weighed ones.
struct WeighedItemError {
    let foodID: String
    let predictedGrams: Double
    let truthGrams: Double
    let rank: Int
}

struct WeighedMealScore {
    var mealID: String
    var proposalCount = 0
    /// Foods the photo shows (hidden ones excluded).
    var visibleExpected = 0
    var top1 = false
    var top3 = false
    var top5 = false
    var foundAt1 = 0
    var foundAt3 = 0
    var foundAt5 = 0
    /// Proposals that match no weighed food (visible or hidden).
    var extraProposals = 0
    var itemErrors: [WeighedItemError] = []
    var predictedGrams = 0.0
    var truthGrams = 0.0
    var predictedKcal = 0.0
    var referenceKcal = 0.0
    var predictedProtein = 0.0
    var referenceProtein = 0.0
    var predictedCarbs = 0.0
    var referenceCarbs = 0.0
    var predictedFat = 0.0
    var referenceFat = 0.0
    /// The range of calories computed by the recap, and the one shown to the person (rounded outwards, see `ScanRecapView.kcalRangeText`).
    var rangeLow = 0.0
    var rangeHigh = 0.0
    var shownLow = 0.0
    var shownHigh = 0.0
}

struct WeighedScoredMeal {
    let meal: WeighedMeal
    let score: WeighedMealScore
}

enum WeighedMealScorer {
    /// The calories and macros of what was weighed for one item, computed from the tables (or from the label values / the recipe
    /// written in the dataset). Nil when a food cannot be found.
    static func reference(of item: WeighedItem, lookup: (String, String?) -> FoodItem?) -> NutritionTotals? {
        if let recipe = item.recipe {
            guard recipe.totalCookedG > 0 else { return nil }
            var total = NutritionTotals()
            for ingredient in recipe.ingredients {
                guard let food = WeighedMealsManifest.food(id: ingredient.foodID, name: ingredient.foodName,
                                                           per100: ingredient.nutrientsPer100g, lookup: lookup) else { return nil }
                total = total + food.nutrients(grams: ingredient.grams)
            }
            let share = item.grams / recipe.totalCookedG
            return NutritionTotals(kcal: total.kcal * share, protein: total.protein * share, carbs: total.carbs * share, fat: total.fat * share)
        }
        guard let food = WeighedMealsManifest.food(id: item.foodID, name: item.foodName, per100: item.nutrientsPer100g, lookup: lookup) else { return nil }
        return food.nutrients(grams: item.grams)
    }

    /// What the scanner got right and wrong for one meal, against the weighed foods. Nil when a reference cannot be computed.
    static func score(meal: WeighedMeal, proposals: [MealProposal], lookup: (String, String?) -> FoodItem?) -> WeighedMealScore? {
        var score = WeighedMealScore(mealID: meal.id)
        var reference = NutritionTotals()
        for item in meal.items {
            guard let totals = self.reference(of: item, lookup: lookup) else { return nil }
            reference = reference + totals
            score.truthGrams += item.grams
        }
        score.referenceKcal = reference.kcal
        score.referenceProtein = reference.protein
        score.referenceCarbs = reference.carbs
        score.referenceFat = reference.fat

        let ranked = proposals.map { $0.food.id }
        score.proposalCount = proposals.count

        // Recognition: the foods the photo shows.
        let visible = meal.items.filter { $0.isVisible }
        let visibleSets = visible.map { $0.acceptedIDs }
        score.visibleExpected = visible.count
        let anyVisible = visibleSets.reduce(into: Set<String>()) { $0.formUnion($1) }
        score.top1 = ScanMetrics.topK(ranked: ranked, accepted: anyVisible, k: 1)
        score.top3 = ScanMetrics.topK(ranked: ranked, accepted: anyVisible, k: 3)
        score.top5 = ScanMetrics.topK(ranked: ranked, accepted: anyVisible, k: 5)
        func found(_ k: Int) -> Int {
            ScanMetrics.match(ranked: Array(ranked.prefix(k)), expected: visibleSets).compactMap { $0 }.count
        }
        score.foundAt1 = found(1)
        score.foundAt3 = found(3)
        score.foundAt5 = found(5)

        // Quantities: grams proposed for each visible food that was found, against the weighed grams.
        let ranks = ScanMetrics.match(ranked: ranked, expected: visibleSets)
        for (index, rank) in ranks.enumerated() {
            guard let rank else { continue }
            score.itemErrors.append(WeighedItemError(foodID: visible[index].foodID, predictedGrams: proposals[rank].grams,
                                                     truthGrams: visible[index].grams, rank: rank))
        }
        let matchedAny = ScanMetrics.match(ranked: ranked, expected: meal.items.map { $0.acceptedIDs }).compactMap { $0 }.count
        score.extraProposals = proposals.count - matchedAny

        // What the person would get by accepting the recap as it is.
        let recap = ScanRecap(proposals: proposals)
        let totals = recap.totals
        score.predictedGrams = recap.lines.reduce(0) { $0 + $1.grams }
        score.predictedKcal = totals.kcal
        score.predictedProtein = totals.protein
        score.predictedCarbs = totals.carbs
        score.predictedFat = totals.fat
        let range = recap.kcalRange
        score.rangeLow = range.low
        score.rangeHigh = range.high
        // Same rounding as `ScanRecapView.kcalRangeText`.
        let shown = range.rounded(to: range.high < 100 ? 5 : 10)
        score.shownLow = shown.low
        score.shownHigh = shown.high
        return score
    }
}

// MARK: - Aggregation and report text

final class WeighedMetricSink {
    private(set) var values: [String: Double] = [:]

    func record(_ key: String, _ value: Double?) {
        guard let value, value.isFinite else { return }
        values[key] = value
    }
}

/// One photo through one pipeline.
struct WeighedPhotoRun {
    let meal: WeighedMeal
    /// Nil when the pipeline failed on this photo.
    let proposals: [MealProposal]?
    let failure: String?
    let seconds: Double
    /// Memory footprint of the process right after the photo (MB), nil if unreadable.
    let footprintMB: Double?
}

enum WeighedMealsReport {
    /// Under this number of meals the figures are only indicative.
    static let minimumMeals = 30

    static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.1f %%", $0 * 100) } ?? "n/d"
    }

    static func number(_ value: Double?, _ digits: Int = 1) -> String {
        value.map { String(format: "%.\(digits)f", $0) } ?? "n/d"
    }

    /// Speed, memory and failures of a pipeline over all the photos.
    static func timing(_ runs: [WeighedPhotoRun], prefix: String, sink: WeighedMetricSink) -> [String] {
        var lines: [String] = []
        let done = runs.filter { $0.proposals != nil }
        let failed = runs.filter { $0.failure != nil }
        lines.append("  photos analysées : \(done.count)/\(runs.count)" + (failed.isEmpty ? "" : ", échecs : \(failed.count)"))
        for run in failed.prefix(3) { lines.append("    échec \(run.meal.id) : \(run.failure ?? "?")") }
        sink.record("\(prefix).photosDone", Double(done.count))
        sink.record("\(prefix).photosFailed", Double(failed.count))
        let seconds = done.map(\.seconds)
        let afterFirst = Array(seconds.dropFirst())
        let median = ScanMetrics.median(seconds)
        let p95 = ScanMetrics.percentile(seconds, 95)
        sink.record("\(prefix).secondsMedian", median)
        sink.record("\(prefix).secondsP95", p95)
        sink.record("\(prefix).secondsFirst", seconds.first)
        lines.append("  temps par photo : médiane \(number(median, 2)) s, 95e centile \(number(p95, 2)) s, "
                     + "première photo (à froid) \(number(seconds.first, 2)) s, médiane des suivantes \(number(ScanMetrics.median(afterFirst), 2)) s")
        let footprints = done.compactMap(\.footprintMB)
        sink.record("\(prefix).footprintMedianMB", ScanMetrics.median(footprints))
        sink.record("\(prefix).footprintMaxMB", footprints.max())
        lines.append("  mémoire du processus après chaque photo : médiane \(number(ScanMetrics.median(footprints), 0)) Mo, maximum observé \(number(footprints.max(), 0)) Mo "
                     + "(échantillonnée entre deux photos : ce n'est pas le pic exact)")
        return lines
    }

    /// The recognition, quantity, calories, macros and calibration figures of a set of scored meals.
    static func summary(_ scored: [WeighedScoredMeal], prefix: String, sink: WeighedMetricSink) -> [String] {
        guard !scored.isEmpty else { return ["  (aucun repas analysé)"] }
        var lines: [String] = []
        let count = scored.count
        let groups = Set(scored.map { $0.meal.groupID }).count
        sink.record("\(prefix).meals", Double(count))
        sink.record("\(prefix).groups", Double(groups))
        lines.append("  repas : \(count) (groupes distincts : \(groups))")
        if count < minimumMeals {
            lines.append("  ATTENTION : moins de \(minimumMeals) repas, chiffres INDICATIFS, à ne pas publier ni comparer")
        }

        // Recognition.
        let top1 = ScanMetrics.rate(scored.map { $0.score.top1 })
        let top3 = ScanMetrics.rate(scored.map { $0.score.top3 })
        let top5 = ScanMetrics.rate(scored.map { $0.score.top5 })
        sink.record("\(prefix).top1", top1)
        sink.record("\(prefix).top3", top3)
        sink.record("\(prefix).top5", top5)
        func withInterval(_ rate: Double?, _ hits: Int) -> String {
            guard let interval = ScanMetrics.wilsonInterval(successes: hits, total: count) else { return percent(rate) }
            return "\(percent(rate)) [\(percent(interval.low)) ; \(percent(interval.high))]"
        }
        let top1Text = withInterval(top1, scored.filter { $0.score.top1 }.count)
        let top3Text = withInterval(top3, scored.filter { $0.score.top3 }.count)
        let top5Text = withInterval(top5, scored.filter { $0.score.top5 }.count)
        lines.append("  Reconnaissance (aliments visibles) : Top-1 \(top1Text), Top-3 \(top3Text), Top-5 \(top5Text) des photos")
        lines.append("    (entre crochets : intervalle de Wilson à 95 %, l'incertitude due au nombre de repas)")
        let expected = scored.reduce(0) { $0 + $1.score.visibleExpected }
        func recall(_ pick: (WeighedMealScore) -> Int) -> Double? {
            expected > 0 ? Double(scored.reduce(0) { $0 + pick($1.score) }) / Double(expected) : nil
        }
        let recall1 = recall { $0.foundAt1 }
        let recall3 = recall { $0.foundAt3 }
        let recall5 = recall { $0.foundAt5 }
        sink.record("\(prefix).recall1", recall1)
        sink.record("\(prefix).recall3", recall3)
        sink.record("\(prefix).recall5", recall5)
        lines.append("  Rappel des aliments (sur \(expected) aliments visibles) : @1 \(percent(recall1)), @3 \(percent(recall3)), @5 \(percent(recall5))")
        let extras = Double(scored.reduce(0) { $0 + $1.score.extraProposals }) / Double(count)
        let empty = scored.filter { $0.score.proposalCount == 0 }.count
        sink.record("\(prefix).extraPerMeal", extras)
        sink.record("\(prefix).mealsWithoutProposal", Double(empty))
        lines.append("  Propositions superflues par repas : \(number(extras, 2)) en moyenne ; repas sans aucune proposition : \(empty)")
        lines.append("  Segmentation IoU / Dice : NON MESURÉE (le pipeline actuel n'expose aucun masque par aliment)")

        // Grams of the foods found.
        let itemErrors = scored.flatMap { $0.score.itemErrors }
        let predicted = itemErrors.map(\.predictedGrams)
        let truth = itemErrors.map(\.truthGrams)
        let gramsMAE = ScanMetrics.meanAbsoluteError(predicted: predicted, truth: truth)
        let gramsBias = ScanMetrics.bias(predicted: predicted, truth: truth)
        let gramsRelative = ScanMetrics.meanRelativeError(predicted: predicted, truth: truth)
        sink.record("\(prefix).gramsMAE", gramsMAE)
        sink.record("\(prefix).gramsBias", gramsBias)
        sink.record("\(prefix).gramsRelative", gramsRelative)
        lines.append("  Grammes des aliments reconnus (\(itemErrors.count) aliments) : MAE \(number(gramsMAE)) g, biais \(number(gramsBias)) g, erreur relative moyenne \(percent(gramsRelative))")
        let itemsByFood = Dictionary(grouping: itemErrors, by: { $0.foodID })
        let expectedByFood = Dictionary(grouping: scored.flatMap { entry in entry.meal.items.filter { $0.isVisible } }, by: { $0.foodID }).mapValues { $0.count }
        lines.append("  Par aliment (attendu / reconnu, MAE g, biais g, erreur relative moyenne) :")
        for food in expectedByFood.keys.sorted() {
            let list = itemsByFood[food] ?? []
            let p = list.map(\.predictedGrams)
            let t = list.map(\.truthGrams)
            lines.append("    \(food) : \(expectedByFood[food] ?? 0) / \(list.count), MAE \(number(ScanMetrics.meanAbsoluteError(predicted: p, truth: t))) g, "
                         + "biais \(number(ScanMetrics.bias(predicted: p, truth: t))) g, \(percent(ScanMetrics.meanRelativeError(predicted: p, truth: t)))")
        }

        // Meal totals.
        let predictedGrams = scored.map { $0.score.predictedGrams }
        let truthGrams = scored.map { $0.score.truthGrams }
        sink.record("\(prefix).mealGramsMAE", ScanMetrics.meanAbsoluteError(predicted: predictedGrams, truth: truthGrams))
        sink.record("\(prefix).mealGramsBias", ScanMetrics.bias(predicted: predictedGrams, truth: truthGrams))
        lines.append("  Poids total du repas : MAE \(number(ScanMetrics.meanAbsoluteError(predicted: predictedGrams, truth: truthGrams))) g, "
                     + "biais \(number(ScanMetrics.bias(predicted: predictedGrams, truth: truthGrams))) g")
        let predictedKcal = scored.map { $0.score.predictedKcal }
        let referenceKcal = scored.map { $0.score.referenceKcal }
        let kcalMAE = ScanMetrics.meanAbsoluteError(predicted: predictedKcal, truth: referenceKcal)
        let kcalBias = ScanMetrics.bias(predicted: predictedKcal, truth: referenceKcal)
        let kcalRelative = ScanMetrics.meanRelativeError(predicted: predictedKcal, truth: referenceKcal)
        let within20 = ScanMetrics.shareWithin(relativeTolerance: 0.2, predicted: predictedKcal, truth: referenceKcal)
        sink.record("\(prefix).kcalMAE", kcalMAE)
        sink.record("\(prefix).kcalBias", kcalBias)
        sink.record("\(prefix).kcalRelative", kcalRelative)
        sink.record("\(prefix).kcalWithin20", within20)
        lines.append("  Calories : MAE \(number(kcalMAE)) kcal, biais \(number(kcalBias)) kcal, erreur relative moyenne \(percent(kcalRelative)), repas à ±20 % : \(percent(within20))")
        let macros: [(key: String, title: String, predicted: KeyPath<WeighedMealScore, Double>, reference: KeyPath<WeighedMealScore, Double>)] = [
            ("protein", "Protéines", \WeighedMealScore.predictedProtein, \WeighedMealScore.referenceProtein),
            ("carbs", "Glucides", \WeighedMealScore.predictedCarbs, \WeighedMealScore.referenceCarbs),
            ("fat", "Lipides", \WeighedMealScore.predictedFat, \WeighedMealScore.referenceFat),
        ]
        for macro in macros {
            let p = scored.map { $0.score[keyPath: macro.predicted] }
            let t = scored.map { $0.score[keyPath: macro.reference] }
            let mae = ScanMetrics.meanAbsoluteError(predicted: p, truth: t)
            let bias = ScanMetrics.bias(predicted: p, truth: t)
            sink.record("\(prefix).\(macro.key)MAE", mae)
            sink.record("\(prefix).\(macro.key)Bias", bias)
            lines.append("  \(macro.title) : MAE \(number(mae)) g, biais \(number(bias)) g")
        }

        // Calibration of the range shown (« ≈ 420–560 kcal »): how often the weighed value is inside, and how wide it is.
        let shown: [(low: Double, high: Double)] = scored.map { (low: $0.score.shownLow, high: $0.score.shownHigh) }
        let raw: [(low: Double, high: Double)] = scored.map { (low: $0.score.rangeLow, high: $0.score.rangeHigh) }
        let coverageShown = ScanMetrics.coverage(intervals: shown, truths: referenceKcal)
        let coverageRaw = ScanMetrics.coverage(intervals: raw, truths: referenceKcal)
        let width = ScanMetrics.meanRelativeWidth(intervals: shown, truths: referenceKcal)
        sink.record("\(prefix).coverageShown", coverageShown)
        sink.record("\(prefix).coverageRaw", coverageRaw)
        sink.record("\(prefix).rangeRelativeWidth", width)
        let coveredCount = Int(((coverageShown ?? 0) * Double(count)).rounded())
        let coverageText = withInterval(coverageShown, coveredCount)
        lines.append("  Fourchette de calories affichée : la valeur pesée est dedans pour \(coverageText) des repas "
                     + "(fourchette brute \(percent(coverageRaw))), largeur moyenne \(percent(width)) de la valeur pesée")
        lines.append("    (l'app n'annonce aucun taux de confiance : la couverture est mesurée, pas comparée à un taux annoncé)")

        // Robustness by condition.
        lines.append("  Par condition de prise de vue (n, Top-3, erreur relative moyenne en kcal) :")
        lines += breakdown(scored, title: "éclairage") { $0.capture.lighting }
        lines += breakdown(scored, title: "vaisselle") { $0.capture.tableware }
        lines += breakdown(scored, title: "angle") { $0.capture.angle }
        lines += breakdown(scored, title: "appareil photo") { $0.device.model }
        lines += breakdown(scored, title: "cuisine") { $0.cuisine }
        return lines
    }

    private static func breakdown(_ scored: [WeighedScoredMeal], title: String, key: (WeighedMeal) -> String) -> [String] {
        let groups = Dictionary(grouping: scored, by: { key($0.meal) })
        var lines = ["    \(title) :"]
        for name in groups.keys.sorted() {
            let list = groups[name] ?? []
            let top3 = ScanMetrics.rate(list.map { $0.score.top3 })
            let relative = ScanMetrics.meanRelativeError(predicted: list.map { $0.score.predictedKcal }, truth: list.map { $0.score.referenceKcal })
            lines.append("      \(name) : n=\(list.count), Top-3 \(percent(top3)), \(percent(relative))")
        }
        return lines
    }
}

// MARK: - Where the dataset is, and the pipelines under test

final class WeighedMealsBundleToken {}

enum WeighedMealsError: Error {
    case unreadableImage
}

struct WeighedLoadedDataset {
    let folder: URL?
    let manifest: WeighedMealsManifest
    /// SHA-256 of meals.json: two reports are comparable only when this is the same.
    let fingerprint: String
}

enum WeighedDatasetState {
    case absent(String)
    case ready(WeighedLoadedDataset)
}

enum WeighedMealsLocation {
    /// The fixtures folder next to this source file (the repository is on the runner's disk in CI): the schema and the example.
    static func sourceFolder() -> URL? {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/WeighedMeals", isDirectory: true)
        return FileManager.default.fileExists(atPath: source.path) ? source : nil
    }

    /// Where the weighed meals are: `WEIGHED_MEALS_DIR` (with xcodebuild: `TEST_RUNNER_WEIGHED_MEALS_DIR`) if set, else the
    /// fixtures folder. The photos can stay outside the repository this way.
    static func folder() -> URL? {
        if let path = ProcessInfo.processInfo.environment["WEIGHED_MEALS_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return sourceFolder()
    }

    /// The file of a photo or a mask: in the folder, else in the test bundle (the file name only).
    static func fileURL(_ relative: String, folder: URL?) -> URL? {
        if let folder {
            let url = folder.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let file = (relative as NSString).lastPathComponent
        return Bundle(for: WeighedMealsBundleToken.self).url(forResource: (file as NSString).deletingPathExtension,
                                                             withExtension: (file as NSString).pathExtension)
    }

    /// `meals.json` (the real dataset), never `meals.example.json`. Throws when the file exists but cannot be read: a broken
    /// dataset must fail loudly, not look like an empty one.
    static func loadDataset() throws -> WeighedDatasetState {
        let folder = Self.folder()
        var data: Data?
        if let folder { data = try? Data(contentsOf: folder.appendingPathComponent("meals.json")) }
        if data == nil, let url = Bundle(for: WeighedMealsBundleToken.self).url(forResource: "meals", withExtension: "json") {
            data = try? Data(contentsOf: url)
        }
        guard let data else {
            return .absent("aucun fichier Tests/Fixtures/WeighedMeals/meals.json : aucun repas pesé n'a été fourni")
        }
        let manifest = try JSONDecoder().decode(WeighedMealsManifest.self, from: data)
        if manifest.dataset.isExample { return .absent("meals.json est marqué « example » : un exemple de structure n'est jamais mesuré") }
        if manifest.meals.isEmpty { return .absent("meals.json ne contient aucun repas") }
        return .ready(WeighedLoadedDataset(folder: folder, manifest: manifest, fingerprint: WeighedMealsManifest.sha256Hex(data)))
    }

    static func dayString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

enum WeighedMealsPipelines {
    /// The photo redrawn upright on at most `OnDeviceMealAnalyzer.maximumSide` pixels, like the scan does.
    static func uprightCopy(of image: UIImage) -> CGImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let factor = min(1, OnDeviceMealAnalyzer.maximumSide / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, (image.size.width * factor).rounded()), height: max(1, (image.size.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    /// Pipeline « matcher »: the labels Vision gives to the whole photo, turned into foods by `FoodLabelMatcher` with the
    /// built-in table and the Canadian Nutrient File, without the person's learning or visual memory.
    static func wholePhoto(_ image: UIImage) throws -> [MealProposal] {
        guard let upright = uprightCopy(of: image) else { throw WeighedMealsError.unreadableImage }
        let request = VNClassifyImageRequest()
        #if targetEnvironment(simulator)
        request.usesCPUOnly = true
        #endif
        try VNImageRequestHandler(cgImage: upright, orientation: .up, options: [:]).perform([request])
        let scores = (request.results ?? []).map {
            FoodLabelMatcher.LabelScore(label: $0.identifier, confidence: Double($0.confidence))
        }
        return FoodLabelMatcher.proposals(
            from: scores, limit: OnDeviceMealAnalyzer.maximumProposals,
            resolve: { FoodDatabase.item($0) }, search: OnDeviceMealAnalyzer.localSearch
        )
    }

    /// Runs one pipeline on one photo and times it.
    static func measure(_ meal: WeighedMeal, _ work: () async throws -> [MealProposal]) async -> WeighedPhotoRun {
        let start = DispatchTime.now().uptimeNanoseconds
        do {
            let proposals = try await work()
            let seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
            return WeighedPhotoRun(meal: meal, proposals: proposals, failure: nil, seconds: seconds, footprintMB: footprintMB())
        } catch {
            let seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
            return WeighedPhotoRun(meal: meal, proposals: nil, failure: String(describing: error), seconds: seconds, footprintMB: footprintMB())
        }
    }

    /// The memory footprint of the process in MB (the figure Xcode shows), nil if the system does not answer.
    static func footprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        return Double(info.phys_footprint) / 1_048_576
    }

    private static func byteSize(of url: URL) -> Int64 {
        var total = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let file as URL in enumerator {
                total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        return total
    }

    /// The Core ML models shipped inside the app (none today: the classifier is the one of iOS) and their size.
    static func bundledModels() -> (count: Int, bytes: Int64) {
        guard let enumerator = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) else { return (0, 0) }
        var count = 0
        var bytes: Int64 = 0
        for case let url as URL in enumerator where ["mlmodelc", "mlpackage", "mlmodel"].contains(url.pathExtension) {
            count += 1
            bytes += byteSize(of: url)
            enumerator.skipDescendants()
        }
        return (count, bytes)
    }

    static func cnfBytes() -> Int64? {
        guard let url = Bundle.main.url(forResource: "cnf-foods", withExtension: "json") else { return nil }
        return byteSize(of: url)
    }
}

// MARK: - Tests

@MainActor
final class WeighedMealsEvaluationTests: XCTestCase {

    // MARK: Helpers to build datasets in memory (structure tests)

    private func itemObject(_ foodID: String, name: String = "Aliment test", grams: Double, state: String = "cooked",
                            visible: Bool = true, per100: [String: Any]? = nil, extra: [String: Any] = [:]) -> [String: Any] {
        var item: [String: Any] = ["foodID": foodID, "foodName": name, "grams": grams, "state": state, "visible": visible]
        if let per100 { item["nutrientsPer100g"] = per100 }
        return item.merging(extra) { _, new in new }
    }

    private func mealObject(_ id: String, split: String = "test", group: String? = nil, items: [[String: Any]]? = nil,
                            photo: [String: Any] = [:], rights: [String: Any] = [:], capture: [String: Any] = [:],
                            weighing: [String: Any] = [:]) -> [String: Any] {
        let basePhoto: [String: Any] = ["file": "\(id).jpg", "capturedAt": "2026-11-02T12:30:00Z"]
        let baseRights: [String: Any] = [
            "origin": "own-photo", "license": "owner-consent", "consent": true, "consentDate": "2026-11-02",
            "commercialUseAllowed": true, "containsPeopleOrPersonalData": false, "exifLocationRemoved": true,
        ]
        let device: [String: Any] = ["model": "iPhone 15 Pro", "iosVersion": "17.5", "lens": "main", "lidar": true]
        let baseCapture: [String: Any] = [
            "lighting": "daylight-window", "tableware": "flat-plate", "angle": "top-down", "distanceCm": 40,
            "plateDiameterCm": 26, "referenceObject": "none",
        ]
        let baseWeighing: [String: Any] = ["scaleModel": "balance de cuisine, pas de 1 g", "resolutionG": 1, "method": "tare-sequence"]
        let defaultItems: [[String: Any]] = [itemObject("builtin.rice", name: "Riz blanc cuit", grams: 200)]
        let meal: [String: Any] = [
            "id": id, "split": split, "groupID": group ?? "groupe-\(id)", "cuisine": "quebecoise", "mealType": "lunch",
            "photo": basePhoto.merging(photo) { _, new in new },
            "rights": baseRights.merging(rights) { _, new in new },
            "device": device,
            "capture": baseCapture.merging(capture) { _, new in new },
            "weighing": baseWeighing.merging(weighing) { _, new in new },
            "items": items ?? defaultItems,
        ]
        return meal
    }

    private func decode(_ meals: [[String: Any]], example: Bool = false) throws -> WeighedMealsManifest {
        let dataset: [String: Any] = ["name": "test", "createdAt": "2026-11-02", "example": example]
        let root: [String: Any] = ["schemaVersion": 1, "dataset": dataset, "meals": meals]
        let data = try JSONSerialization.data(withJSONObject: root)
        return try JSONDecoder().decode(WeighedMealsManifest.self, from: data)
    }

    private func problems(_ meals: [[String: Any]], resolveFile: ((String) -> URL?)? = nil) throws -> [String] {
        try decode(meals).validationProblems(resolveFile: resolveFile, lookup: WeighedFoodBase.lookup)
    }

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: Structure: schema, example, validator

    private func schemaDefinitions() throws -> [String: Any] {
        guard let folder = WeighedMealsLocation.sourceFolder() else { throw XCTSkip("Dossier Tests/Fixtures/WeighedMeals introuvable") }
        let data = try Data(contentsOf: folder.appendingPathComponent("manifest.schema.json"))
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(schema["$defs"] as? [String: Any])
    }

    /// The lists of allowed values in `manifest.schema.json` and in the Swift model must be the same lists.
    func testSchemaEnumsMatchTheSwiftVocabulary() throws {
        let definitions = try schemaDefinitions()
        for (name, values) in WeighedMealsVocabulary.bySchemaName {
            let definition = try XCTUnwrap(definitions[name] as? [String: Any], "définition « \(name) » absente du schéma")
            let allowed = try XCTUnwrap(definition["enum"] as? [String], "« \(name) » sans liste enum")
            XCTAssertEqual(Set(allowed), Set(values), "liste « \(name) » différente entre le schéma et le code")
            XCTAssertEqual(allowed.count, Set(allowed).count, "doublon dans la liste « \(name) » du schéma")
        }
    }

    func testTheExampleManifestFollowsTheModelAndIsNeverMeasured() throws {
        guard let folder = WeighedMealsLocation.sourceFolder() else { throw XCTSkip("Dossier Tests/Fixtures/WeighedMeals introuvable") }
        let data = try Data(contentsOf: folder.appendingPathComponent("meals.example.json"))
        let manifest = try JSONDecoder().decode(WeighedMealsManifest.self, from: data)
        XCTAssertTrue(manifest.dataset.isExample, "l'exemple doit être marqué example: true")
        XCTAssertEqual(manifest.meals.count, 1)
        let found = manifest.validationProblems(resolveFile: nil, lookup: WeighedFoodBase.lookup)
        XCTAssertEqual(found, [], "l'exemple doit respecter les règles de validation")
    }

    func testAValidDatasetHasNoProblem() throws {
        // Two photos of the same plate (same group) may sit in the same split.
        let found = try problems([
            mealObject("repas-a1", split: "train", group: "plat-a"),
            mealObject("repas-a2", split: "train", group: "plat-a"),
            mealObject("repas-b1", split: "test", group: "plat-b"),
        ])
        XCTAssertEqual(found, [])
    }

    func testTheSameGroupInTwoSplitsIsALeak() throws {
        let found = try problems([
            mealObject("repas-a1", split: "train", group: "poulet-riz"),
            mealObject("repas-a2", split: "test", group: "poulet-riz"),
        ])
        XCTAssertTrue(found.contains { $0.contains("fuite") && $0.contains("poulet-riz") }, "\(found)")
    }

    func testAPhotoWithoutConsentOrWithPeopleIsRefused() throws {
        let found = try problems([
            mealObject("sans-accord", rights: ["consent": false]),
            mealObject("avec-visage", rights: ["containsPeopleOrPersonalData": true]),
            mealObject("avec-gps", rights: ["exifLocationRemoved": false]),
            mealObject("pas-commercial", rights: ["commercialUseAllowed": false]),
        ])
        XCTAssertTrue(found.contains { $0.hasPrefix("sans-accord") && $0.contains("consentement") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("avec-visage") && $0.contains("personnes") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("avec-gps") && $0.contains("position") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("pas-commercial") && $0.contains("commercial") }, "\(found)")
    }

    func testALicensedPhotoNeedsItsLicenceAuthorAndSource() throws {
        let found = try problems([
            mealObject("libre-sans-source", rights: ["origin": "licensed-dataset", "license": "CC0"]),
            mealObject("libre-complete", rights: ["origin": "licensed-dataset", "license": "CC BY 4.0", "author": "A. Auteur",
                                                  "sourceURL": "https://commons.wikimedia.org/wiki/File:Exemple.jpg"]),
        ])
        XCTAssertTrue(found.contains { $0.hasPrefix("libre-sans-source") && $0.contains("auteur") }, "\(found)")
        XCTAssertFalse(found.contains { $0.hasPrefix("libre-complete") }, "\(found)")
    }

    func testTwoMealsCannotShareAPhoto() throws {
        let found = try problems([
            mealObject("repas-1", photo: ["file": "meme.jpg"]),
            mealObject("repas-2", photo: ["file": "meme.jpg"]),
        ])
        XCTAssertTrue(found.contains { $0.hasPrefix("repas-2") && $0.contains("déjà utilisée") }, "\(found)")
    }

    func testAPhotoPathCannotEscapeTheFolder() throws {
        let found = try problems([
            mealObject("chemin-sorti", photo: ["file": "../secret.jpg"]),
            mealObject("chemin-absolu", photo: ["file": "/etc/photo.jpg"]),
            mealObject("mauvais-format", photo: ["file": "photo.gif"]),
        ])
        XCTAssertEqual(found.filter { $0.contains("chemin de photo invalide") }.count, 3, "\(found)")
    }

    func testAWeightMustBeReadableOnTheScale() throws {
        let found = try problems([
            mealObject("pas-lisible", items: [itemObject("builtin.rice", name: "Riz blanc cuit", grams: 12.5)]),
            mealObject("lisible-au-dixieme", items: [itemObject("builtin.rice", name: "Riz blanc cuit", grams: 12.5)], weighing: ["resolutionG": 0.1]),
            mealObject("poids-nul", items: [itemObject("builtin.rice", name: "Riz blanc cuit", grams: 0)]),
        ])
        XCTAssertTrue(found.contains { $0.hasPrefix("pas-lisible") && $0.contains("multiple de la résolution") }, "\(found)")
        XCTAssertFalse(found.contains { $0.hasPrefix("lisible-au-dixieme") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("poids-nul") && $0.contains("poids hors") }, "\(found)")
    }

    func testFoodsMustExistAndTheirStateMustNotContradictTheTable() throws {
        let found = try problems([
            // « Riz blanc cuit » weighed raw: contradiction.
            mealObject("etat-contredit", items: [itemObject("builtin.rice", name: "Riz blanc cuit", grams: 100, state: "raw")]),
            mealObject("inconnu", items: [itemObject("builtin.nexistepas", grams: 100)]),
            mealObject("hors-table-sans-etiquette", items: [itemObject("off.3017620422003", name: "Pâte à tartiner", grams: 20)]),
            mealObject("hors-table-avec-etiquette", items: [
                itemObject("off.3017620422003", name: "Pâte à tartiner", grams: 20, state: "not-applicable",
                           per100: ["kcal": 539, "protein": 6.3, "carbs": 57.5, "fat": 30.9]),
            ]),
        ])
        XCTAssertTrue(found.contains { $0.hasPrefix("etat-contredit") && $0.contains("contredit") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("inconnu") && $0.contains("introuvable") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("hors-table-sans-etiquette") && $0.contains("introuvable") }, "\(found)")
        XCTAssertFalse(found.contains { $0.hasPrefix("hors-table-avec-etiquette") }, "\(found)")
    }

    func testAMealNeedsAVisibleFood() throws {
        let found = try problems([
            mealObject("que-cache", items: [itemObject("builtin.oliveoil", name: "Huile d'olive", grams: 10, state: "not-applicable", visible: false)]),
        ])
        XCTAssertTrue(found.contains { $0.hasPrefix("que-cache") && $0.contains("aucun aliment visible") }, "\(found)")
    }

    func testFilesAndChecksumsAreCheckedWhenAFolderIsGiven() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("weighed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let content = Data("pas une vraie photo".utf8)
        try content.write(to: folder.appendingPathComponent("presente.jpg"))
        let resolve: (String) -> URL? = { relative in
            let url = folder.appendingPathComponent(relative)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        let goodHash = WeighedMealsManifest.sha256Hex(content)
        let found = try problems([
            mealObject("ok", photo: ["file": "presente.jpg", "sha256": goodHash]),
            mealObject("absente", photo: ["file": "absente.jpg"]),
            mealObject("modifiee", photo: ["file": "presente.jpg", "sha256": String(repeating: "0", count: 64)]),
        ], resolveFile: resolve)
        XCTAssertFalse(found.contains { $0.hasPrefix("ok :") || $0.hasPrefix("ok/") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("absente") && $0.contains("introuvable") }, "\(found)")
        XCTAssertTrue(found.contains { $0.hasPrefix("modifiee") && $0.contains("SHA-256") }, "\(found)")
    }

    func testSHA256OfNothingIsTheKnownConstant() {
        XCTAssertEqual(WeighedMealsManifest.sha256Hex(Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    // MARK: Scoring against hand-computed values

    private func customFood(_ id: String, kcal: Double, protein: Double, carbs: Double, fat: Double) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: 0,
                 servingGrams: 100, servingName: "100 g", source: .custom, barcode: nil)
    }

    private func per100(_ food: FoodItem) -> [String: Any] {
        ["kcal": food.kcal, "protein": food.protein, "carbs": food.carbs, "fat": food.fat]
    }

    func testTheReferenceOfARecipePortionScalesTheIngredientsByTheCookedWeight() throws {
        // Ingredients (weighed raw): 400 g of beef (250 kcal, 20 P, 0 G, 18 L per 100 g) and 400 g of potato (80, 2, 18, 0.1).
        // Whole recipe: kcal 1000 + 320 = 1320, P 80 + 8 = 88, G 0 + 72 = 72, L 72 + 0.4 = 72.4. It weighs 600 g once cooked.
        // A portion of 150 g is 150 / 600 = 1/4 of it: 330 kcal, 22 P, 18 G, 18.1 L.
        let beefValues: [String: Double] = ["kcal": 250, "protein": 20, "carbs": 0, "fat": 18]
        let potatoValues: [String: Double] = ["kcal": 80, "protein": 2, "carbs": 18, "fat": 0.1]
        let beef: [String: Any] = ["foodID": "custom.boeuf", "foodName": "Boeuf", "grams": 400, "nutrientsPer100g": beefValues]
        let potato: [String: Any] = ["foodID": "custom.patate", "foodName": "Patate", "grams": 400, "nutrientsPer100g": potatoValues]
        let recipe: [String: Any] = ["totalCookedG": 600, "ingredients": [beef, potato]]
        let stew = itemObject("custom.pot-au-feu", name: "Pot-au-feu", grams: 150, state: "cooked", extra: ["recipe": recipe])
        let manifest = try decode([mealObject("pot-au-feu", items: [stew])])
        XCTAssertEqual(manifest.validationProblems(resolveFile: nil, lookup: WeighedFoodBase.lookup), [])
        let totals = try XCTUnwrap(WeighedMealScorer.reference(of: manifest.meals[0].items[0], lookup: WeighedFoodBase.lookup))
        XCTAssertEqual(totals.kcal, 330, accuracy: 1e-6)
        XCTAssertEqual(totals.protein, 22, accuracy: 1e-6)
        XCTAssertEqual(totals.carbs, 18, accuracy: 1e-6)
        XCTAssertEqual(totals.fat, 18.1, accuracy: 1e-6)
    }

    /// Rice 200 g, chicken 150 g and 10 g of oil that the photo cannot show are weighed. The scanner proposes broccoli 100 g,
    /// rice 150 g and chicken 180 g. Values per 100 g: rice 130 kcal / 2.5 P / 28 G / 0.3 L; chicken 165 / 31 / 0 / 3.6;
    /// oil 884 / 0 / 0 / 100; broccoli 34 / 2.8 / 7 / 0.4.
    func testScoringOfAMealAgainstHandComputedValues() throws {
        let rice = customFood("custom.riz", kcal: 130, protein: 2.5, carbs: 28, fat: 0.3)
        let chicken = customFood("custom.poulet", kcal: 165, protein: 31, carbs: 0, fat: 3.6)
        let oil = customFood("custom.huile", kcal: 884, protein: 0, carbs: 0, fat: 100)
        let broccoli = customFood("custom.brocoli", kcal: 34, protein: 2.8, carbs: 7, fat: 0.4)
        let manifest = try decode([mealObject("assiette", items: [
            itemObject(rice.id, name: "Riz", grams: 200, per100: per100(rice)),
            itemObject(chicken.id, name: "Poulet", grams: 150, per100: per100(chicken)),
            itemObject(oil.id, name: "Huile", grams: 10, state: "not-applicable", visible: false, per100: per100(oil)),
        ])])
        let meal = manifest.meals[0]
        let proposals = [
            MealProposal(food: broccoli, grams: 100, confidence: 0.9),
            MealProposal(food: rice, grams: 150, confidence: 0.8),
            MealProposal(food: chicken, grams: 180, confidence: 0.7),
        ]
        let score = try XCTUnwrap(WeighedMealScorer.score(meal: meal, proposals: proposals, lookup: { _, _ in nil }))

        // Reference: kcal 260 + 247.5 + 88.4 = 595.9; P 5 + 46.5 = 51.5; G 56; L 0.6 + 5.4 + 10 = 16; weight 360 g.
        XCTAssertEqual(score.referenceKcal, 595.9, accuracy: 1e-6)
        XCTAssertEqual(score.referenceProtein, 51.5, accuracy: 1e-6)
        XCTAssertEqual(score.referenceCarbs, 56, accuracy: 1e-6)
        XCTAssertEqual(score.referenceFat, 16, accuracy: 1e-6)
        XCTAssertEqual(score.truthGrams, 360, accuracy: 1e-6)
        // Recognition: broccoli is first and wrong; rice and chicken follow. The oil is hidden, so only 2 foods are expected.
        XCTAssertEqual(score.visibleExpected, 2)
        XCTAssertFalse(score.top1)
        XCTAssertTrue(score.top3)
        XCTAssertEqual(score.foundAt1, 0)
        XCTAssertEqual(score.foundAt3, 2)
        XCTAssertEqual(score.extraProposals, 1, "broccoli matches nothing that was weighed")
        // Quantities: rice 150 against 200 g (rank 1), chicken 180 against 150 g (rank 2).
        XCTAssertEqual(score.itemErrors.count, 2)
        let riceError = try XCTUnwrap(score.itemErrors.first { $0.foodID == rice.id })
        XCTAssertEqual(riceError.predictedGrams, 150)
        XCTAssertEqual(riceError.truthGrams, 200)
        XCTAssertEqual(riceError.rank, 1)
        let chickenError = try XCTUnwrap(score.itemErrors.first { $0.foodID == chicken.id })
        XCTAssertEqual(chickenError.predictedGrams, 180)
        XCTAssertEqual(chickenError.truthGrams, 150)
        // What the recap gives: 100 + 150 + 180 = 430 g; kcal 34 + 195 + 297 = 526; P 2.8 + 3.75 + 55.8 = 62.35; G 7 + 42 + 0 = 49;
        // L 0.4 + 0.45 + 6.48 = 7.33.
        XCTAssertEqual(score.predictedGrams, 430, accuracy: 1e-6)
        XCTAssertEqual(score.predictedKcal, 526, accuracy: 1e-6)
        XCTAssertEqual(score.predictedProtein, 62.35, accuracy: 1e-6)
        XCTAssertEqual(score.predictedCarbs, 49, accuracy: 1e-6)
        XCTAssertEqual(score.predictedFat, 7.33, accuracy: 1e-6)
        // Range of a photo estimate: 526 x 0.6 = 315.6 to 526 x 1.4 = 736.4, shown rounded outwards by 10: 310 to 740.
        XCTAssertEqual(score.rangeLow, 315.6, accuracy: 1e-6)
        XCTAssertEqual(score.rangeHigh, 736.4, accuracy: 1e-6)
        XCTAssertEqual(score.shownLow, 310, accuracy: 1e-6)
        XCTAssertEqual(score.shownHigh, 740, accuracy: 1e-6)
        // The weighed 595.9 kcal is inside the range shown.
        XCTAssertEqual(ScanMetrics.coverage(intervals: [(low: score.shownLow, high: score.shownHigh)], truths: [score.referenceKcal]), 1)
    }

    func testScoringWhenTheScannerProposesNothing() throws {
        let rice = customFood("custom.riz", kcal: 130, protein: 2.5, carbs: 28, fat: 0.3)
        let manifest = try decode([mealObject("rien", items: [itemObject(rice.id, name: "Riz", grams: 200, per100: per100(rice))])])
        let score = try XCTUnwrap(WeighedMealScorer.score(meal: manifest.meals[0], proposals: [], lookup: { _, _ in nil }))
        XCTAssertEqual(score.proposalCount, 0)
        XCTAssertFalse(score.top1)
        XCTAssertFalse(score.top5)
        XCTAssertEqual(score.extraProposals, 0)
        XCTAssertEqual(score.predictedKcal, 0)
        XCTAssertEqual(score.referenceKcal, 260, accuracy: 1e-6)
        XCTAssertEqual(score.shownLow, 0)
        XCTAssertEqual(score.shownHigh, 0)
        XCTAssertEqual(ScanMetrics.coverage(intervals: [(low: score.shownLow, high: score.shownHigh)], truths: [score.referenceKcal]), 0,
                       "an empty answer does not cover the weighed meal")
    }

    func testAnAcceptedAlternativeCountsAsRecognised() throws {
        let weighed = customFood("custom.riz-blanc", kcal: 130, protein: 2.5, carbs: 28, fat: 0.3)
        let proposed = customFood("cnf.1234", kcal: 129, protein: 2.7, carbs: 28, fat: 0.3)
        let manifest = try decode([mealObject("alternatif", items: [
            itemObject(weighed.id, name: "Riz blanc", grams: 100, per100: per100(weighed), extra: ["acceptedFoodIDs": ["cnf.1234"]]),
        ])])
        let score = try XCTUnwrap(WeighedMealScorer.score(
            meal: manifest.meals[0], proposals: [MealProposal(food: proposed, grams: 120, confidence: 0.8)], lookup: { _, _ in nil }))
        XCTAssertTrue(score.top1)
        XCTAssertEqual(score.foundAt1, 1)
        XCTAssertEqual(score.extraProposals, 0)
        XCTAssertEqual(score.itemErrors.first?.predictedGrams, 120)
    }

    func testTheSummaryRefusesToHideASmallSample() throws {
        let rice = customFood("custom.riz", kcal: 130, protein: 2.5, carbs: 28, fat: 0.3)
        let manifest = try decode([mealObject("seul", items: [itemObject(rice.id, name: "Riz", grams: 200, per100: per100(rice))])])
        let meal = manifest.meals[0]
        let score = try XCTUnwrap(WeighedMealScorer.score(
            meal: meal, proposals: [MealProposal(food: rice, grams: 150, confidence: 0.8)], lookup: { _, _ in nil }))
        let sink = WeighedMetricSink()
        let lines = WeighedMealsReport.summary([WeighedScoredMeal(meal: meal, score: score)], prefix: "essai", sink: sink)
        XCTAssertTrue(lines.contains { $0.contains("INDICATIFS") }, "one meal is far under the minimum")
        XCTAssertEqual(try XCTUnwrap(sink.values["essai.top1"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(sink.values["essai.gramsMAE"]), 50, accuracy: 1e-9, "150 g against 200 g")
        XCTAssertEqual(try XCTUnwrap(sink.values["essai.gramsBias"]), -50, accuracy: 1e-9)
        // 150 g of rice = 195 kcal against 260 weighed: error 65, bias -65, relative 25 %.
        XCTAssertEqual(try XCTUnwrap(sink.values["essai.kcalMAE"]), 65, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(sink.values["essai.kcalBias"]), -65, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(sink.values["essai.kcalRelative"]), 0.25, accuracy: 1e-9)
        XCTAssertNil(sink.values["essai.iou"], "no segmentation figure is ever invented")
    }

    // MARK: The measure itself

    /// Validates the real dataset when there is one.
    func testTheMeasuredDatasetIsValid() throws {
        guard case .ready(let dataset) = try WeighedMealsLocation.loadDataset() else {
            throw XCTSkip("Aucun repas pesé fourni (Tests/Fixtures/WeighedMeals/meals.json)")
        }
        let found = dataset.manifest.validationProblems(
            resolveFile: { WeighedMealsLocation.fileURL($0, folder: dataset.folder) }, lookup: WeighedFoodBase.lookup)
        XCTAssertEqual(found, [], "jeu de repas pesés invalide : \(found.joined(separator: " ; "))")
    }

    /// Runs the CURRENT scan on the weighed meals and attaches `SCAN-PRECISION-<date>.txt` (and its figures as .json).
    /// Without weighed meals it says so and passes: no figure is ever made up.
    func testEvaluateWeighedMeals() async throws {
        let day = WeighedMealsLocation.dayString()
        let name = "SCAN-PRECISION-\(day)"
        switch try WeighedMealsLocation.loadDataset() {
        case .absent(let reason):
            let text = [
                "SCAN-PRECISION \(day)",
                "Plateforme : \(Self.platform().text)",
                "",
                "AUCUNE MESURE DE PRÉCISION N'A ÉTÉ PRODUITE.",
                "Raison : \(reason).",
                "Sans repas pesé (photo + poids lu sur une balance de cuisine), aucun chiffre de précision n'existe : aucun n'est donné ici.",
                "Procédure : docs/scanner/Protocole-mesure.md ; format du jeu : Tests/Fixtures/WeighedMeals/README.md.",
            ].joined(separator: "\n")
            attach(text, name: name)
            print(text)
        case .ready(let dataset):
            try await evaluate(dataset, name: name, day: day)
        }
    }

    private func evaluate(_ dataset: WeighedLoadedDataset, name: String, day: String) async throws {
        let manifest = dataset.manifest
        let platform = Self.platform()
        let problems = manifest.validationProblems(
            resolveFile: { WeighedMealsLocation.fileURL($0, folder: dataset.folder) }, lookup: WeighedFoodBase.lookup)
        guard problems.isEmpty else {
            let header = ["SCAN-PRECISION \(day)", "Le jeu de repas pesés est INVALIDE : aucune mesure.", ""]
            attach((header + problems.map { "- \($0)" }).joined(separator: "\n"), name: name)
            XCTFail("Jeu de repas pesés invalide (\(problems.count) problème(s)) : voir la pièce jointe \(name)")
            return
        }

        var matcherRuns: [WeighedPhotoRun] = []
        var appRuns: [WeighedPhotoRun] = []
        let footprintBefore = WeighedMealsPipelines.footprintMB()
        for meal in manifest.meals {
            guard let url = WeighedMealsLocation.fileURL(meal.photo.file, folder: dataset.folder), let image = UIImage(contentsOfFile: url.path) else {
                let failed = WeighedPhotoRun(meal: meal, proposals: nil, failure: "photo illisible : \(meal.photo.file)", seconds: 0, footprintMB: nil)
                matcherRuns.append(failed)
                appRuns.append(failed)
                continue
            }
            matcherRuns.append(await WeighedMealsPipelines.measure(meal) { try WeighedMealsPipelines.wholePhoto(image) })
            appRuns.append(await WeighedMealsPipelines.measure(meal) { try await OnDeviceMealAnalyzer().analyzeMeal(image).proposals })
        }
        XCTAssertEqual(matcherRuns.count, manifest.meals.count)
        XCTAssertEqual(appRuns.count, manifest.meals.count)

        let sink = WeighedMetricSink()
        let state = SharedStore.shared.state(NutritionState.self)
        let models = WeighedMealsPipelines.bundledModels()
        var report: [String] = []
        report.append("SCAN-PRECISION \(day)")
        report.append("Généré : \(ISO8601DateFormatter().string(from: Date()))")
        report.append("Plateforme : \(platform.text)")
        if platform.isSimulator {
            report.append("AVERTISSEMENT : mesure faite sur SIMULATEUR. Les temps, la mémoire et le comportement de Vision ne sont PAS ceux d'un iPhone : ne jamais présenter ces chiffres comme des résultats iPhone.")
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        report.append("Application : Ardane \(version) (build \(build))")
        let revision = VNClassifyImageRequest.currentRevision
        let modelMB = models.bytes / 1_048_576
        let foodModels = FoodModelRecognizer.shared.isAvailable ? "actifs (segmenteur puis classifieur ; Vision en repli)" : "INDISPONIBLES (Vision seul)"
        report.append("Classifieur : modèles Core ML du scanner \(foodModels) ; Vision VNClassifyImageRequest, révision \(revision) ; modèles Core ML dans l'app : \(models.count) (\(modelMB) Mo)")
        let cnfState = NutrientFile.isEmpty ? "INDISPONIBLE dans ce paquet" : "disponible"
        let cnfSize = WeighedMealsPipelines.cnfBytes().map { "\($0 / 1_024) Ko" } ?? "taille inconnue"
        report.append("Tables : table intégrée (\(FoodDatabase.all.count) aliments) + Fichier canadien (\(cnfState), \(cnfSize))")
        let corrections = state.scanLearning.corrections.count
        let remembered = state.mealMemory.entries.count
        let coldNote = corrections == 0 && remembered == 0 ? " (à froid)" : " : CES CHIFFRES SONT INFLUENCÉS PAR L'HISTORIQUE, pas une mesure à froid"
        report.append("État personnel lu par le pipeline « app » : \(corrections) corrections, \(remembered) repas mémorisés" + coldNote)
        let perSplit = Dictionary(grouping: manifest.meals, by: { $0.split }).mapValues { $0.count }
        let splitText = ["train", "validation", "test"].map { "\($0) \(perSplit[$0] ?? 0)" }.joined(separator: ", ")
        let groupCount = Set(manifest.meals.map(\.groupID)).count
        report.append("Jeu : « \(manifest.dataset.name) » (\(manifest.dataset.createdAt)), \(manifest.meals.count) repas, \(groupCount) groupes ; " + splitText)
        report.append("Empreinte du jeu (SHA-256 de meals.json) : \(dataset.fingerprint)")
        report.append("Règles : les poids viennent de la balance du jeu ; les valeurs de référence sont calculées depuis les tables ; seuls les repas du jeu « test » donnent des chiffres publiables.")
        report.append("Mémoire du processus avant le jeu : \(WeighedMealsReport.number(footprintBefore, 0)) Mo")

        let pipelines: [(key: String, title: String, runs: [WeighedPhotoRun])] = [
            ("app", "Pipeline complet de l'app (OnDeviceMealAnalyzer : photo + objets/grille, mémoire visuelle, apprentissage)", appRuns),
            ("matcher", "Photo entière -> FoodLabelMatcher (table + Fichier canadien), sans apprentissage ni mémoire", matcherRuns),
        ]
        for pipeline in pipelines {
            report.append("")
            report.append("=== \(pipeline.title) ===")
            report += WeighedMealsReport.timing(pipeline.runs, prefix: pipeline.key, sink: sink)
            for split in ["test", "validation", "train"] {
                let subset = pipeline.runs.filter { $0.meal.split == split }
                guard !subset.isEmpty else { continue }
                let scored: [WeighedScoredMeal] = subset.compactMap { run in
                    guard let proposals = run.proposals,
                          let score = WeighedMealScorer.score(meal: run.meal, proposals: proposals, lookup: WeighedFoodBase.lookup) else { return nil }
                    return WeighedScoredMeal(meal: run.meal, score: score)
                }
                report.append("")
                report.append("--- jeu « \(split) » : \(subset.count) photos, \(scored.count) analysées")
                report += WeighedMealsReport.summary(scored, prefix: "\(pipeline.key).\(split)", sink: sink)
            }
        }

        let text = report.joined(separator: "\n")
        attach(text, name: name)
        print(text)
        let payload: [String: Any] = [
            "date": day, "platform": platform.text, "isSimulator": platform.isSimulator, "meals": manifest.meals.count,
            "dataset": manifest.dataset.name, "datasetSHA256": dataset.fingerprint, "metrics": sink.values,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let figures = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        figures.name = "\(name)-donnees"
        figures.lifetime = .keepAlways
        add(figures)
    }

    // MARK: Platform

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return Mirror(reflecting: info.machine).children.reduce(into: "") { text, element in
            if let value = element.value as? Int8, value != 0 { text.append(Character(UnicodeScalar(UInt8(value)))) }
        }
    }

    private static func platform() -> (text: String, isSimulator: Bool) {
        let system = "iOS \(UIDevice.current.systemVersion)"
        #if targetEnvironment(simulator)
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineIdentifier()
        return ("SIMULATEUR (\(model), \(system))", true)
        #else
        return ("iPhone/iPad réel (\(machineIdentifier()), \(system))", false)
        #endif
    }
}
