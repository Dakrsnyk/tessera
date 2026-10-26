import Foundation

/// A food proposed from the photo of a dish. Never a measure: the food is a guess from what the image
/// seems to show, and the quantity is the usual portion of that food (`isEstimate`). Calories and
/// macronutrients come from the values of the food table, for that quantity.
struct MealProposal: Identifiable, Hashable {
    let food: FoodItem
    let grams: Double
    /// How sure the analysis is of the food, from 0 to 1.
    let confidence: Double
    let isEstimate: Bool
    /// The label of the analysis this food was found for (cleaned), and the food the table gave for it
    /// before the person's habits were applied. Kept to record what the person corrects.
    let label: String?
    let detectedFoodID: String?
    /// True when the food or the quantity comes from what the person usually keeps (`ScanLearning`).
    let usesHabit: Bool
    /// The same food in its other cooking state (raw for a cooked proposal, or the reverse), when the
    /// tables have both. The default is the cooked one, for a dish that is served.
    let alternative: FoodItem?
    /// The dish this line is a component of (« Sandwich »), nil for a food named by itself.
    let dishName: String?
    /// True for a component of a dish that is often absent (a sauce, a garnish): the person keeps or drops it.
    let isOptional: Bool

    var id: String { food.id }

    init(food: FoodItem, grams: Double, confidence: Double, isEstimate: Bool = true,
         label: String? = nil, detectedFoodID: String? = nil, usesHabit: Bool = false,
         alternative: FoodItem? = nil, dishName: String? = nil, isOptional: Bool = false) {
        self.food = food
        self.grams = grams
        self.confidence = confidence
        self.isEstimate = isEstimate
        self.label = label
        self.detectedFoodID = detectedFoodID
        self.usesHabit = usesHabit
        self.alternative = alternative
        self.dishName = dishName
        self.isOptional = isOptional
    }

    var totals: NutritionTotals { food.nutrients(grams: grams) }
}

/// Turns what an image classifier sees (labels with a confidence, like « pizza » 0.62 or « plate » 0.80)
/// into foods of the local tables. Pure logic: no Vision, no UIKit, so it can be tested. The classifier
/// itself lives in the app (`OnDeviceMealAnalyzer`).
///
/// - labels that are not food (person, table, plate, cutlery, kitchen…) are ignored, as are the labels
///   too generic to name a food (« food », « fruit »…);
/// - a label under the confidence threshold is dropped;
/// - a label gives its best match (synonyms first, then its words); a dish becomes editable lines
///   (`DishTemplate`); a food is proposed once, and at most `maximumProposals` are kept;
/// - the quantity is the usual portion of the food, and the proposal says it is an estimate.
enum FoodLabelMatcher {
    /// A label the classifier gave to an image, with its confidence (0 to 1).
    struct LabelScore: Hashable {
        var label: String
        var confidence: Double
    }

    /// Under this confidence a label is not used.
    static let minimumConfidence = 0.15
    static let maximumProposals = 10
    /// A food found only through the last word of a longer label (« chocolate cake » → « cake ») is less
    /// sure than a food found with the whole label.
    static let partialMatchFactor = 0.6

    /// Words of labels that name a person, a thing around the food, a place or a whole family of foods
    /// (too vague to be one food): a label made only of these words is never turned into a food. Searching
    /// them would find unrelated foods (« pan » → pancake, « bar » → granola bar, « fruit » → fruit yogurt).
    static let ignoredWords: Set<String> = [
        // People
        "person", "people", "man", "men", "woman", "women", "adult", "child", "children", "boy", "girl", "baby", "kid",
        "human", "face", "head", "hand", "hands", "finger", "fingers", "arm", "skin", "portrait", "selfie", "crowd", "smile",
        // Around the food
        "plate", "plates", "dish", "dishes", "dishware", "bowl", "bowls", "cup", "cups", "mug", "glass", "glasses", "bottle",
        "jar", "container", "tray", "platter", "saucer", "tableware", "cutlery", "silverware", "utensil", "utensils",
        "fork", "knife", "spoon", "spatula", "chopsticks", "napkin", "placemat", "tablecloth", "table", "tables", "tabletop",
        "furniture", "chair", "desk", "counter", "countertop", "kitchen", "kitchenware", "cookware", "pan", "pans", "pot",
        "pots", "frying", "oven", "stove",
        // Places and surroundings
        "restaurant", "cafe", "bar", "diner", "dining", "room", "indoor", "indoors", "outdoor", "outdoors", "interior",
        "market", "store", "shop", "supermarket", "grocery", "wall", "floor", "window", "building", "sky", "cloud", "plant",
        "flower", "tree", "grass", "wood", "wooden", "paper", "water",
        // Looks of the photo
        "close", "closeup", "macro", "texture", "pattern",
        // Too generic to be one food
        "food", "foods", "meal", "meals", "dinner", "lunch", "breakfast", "brunch", "cuisine", "recipe", "ingredient",
        "ingredients", "produce", "snack", "snacks", "fast", "baked", "goods", "dessert", "desserts", "sweets", "sweet",
        "fruit", "fruits", "vegetable", "vegetables", "meat", "seafood", "dairy", "junk", "healthy", "organic", "natural",
        "fresh", "raw", "cooked", "homemade",
    ]

    /// « hot_dog » → « hot dog »: lowercase, separators as spaces.
    static func cleaned(_ label: String) -> String {
        label.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmed
    }

    /// The words of a label.
    static func words(of label: String) -> [String] {
        cleaned(label).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// True when nothing in the label can name a food (only ignored or very short words).
    static func isIgnored(_ label: String) -> Bool {
        usefulWords(of: label).isEmpty
    }

    /// The words left once the ignored ones and the very short ones are dropped.
    static func usefulWords(of label: String) -> [String] {
        words(of: label).filter { $0.count >= 3 && !ignoredWords.contains($0) }
    }

    /// The foods proposed for a set of labels, the most confident first.
    /// `search`: the foods whose name matches a text, the best match first (the food table, then the
    /// Canadian Nutrient File in the app).
    static func proposals(
        from scores: [LabelScore],
        minimumConfidence: Double = FoodLabelMatcher.minimumConfidence,
        limit: Int = FoodLabelMatcher.maximumProposals,
        learning: ScanLearning = ScanLearning(),
        resolve: (String) -> FoodItem? = { _ in nil },
        search: (String) -> [FoodItem] = { FoodDatabase.search($0) },
        useDishKnowledge: Bool = true
    ) -> [MealProposal] {
        guard limit > 0 else { return [] }
        var best: [String: MealProposal] = [:]
        func keep(_ proposal: MealProposal) {
            if let known = best[proposal.food.id], known.confidence >= proposal.confidence { return }
            best[proposal.food.id] = proposal
        }
        for score in scores.sorted(by: { $0.confidence > $1.confidence }) {
            guard score.confidence.isFinite, score.confidence >= minimumConfidence else { continue }
            let preferred = learning.preferredFoodID(forLabel: score.label).flatMap(resolve)
            // A dish (« sandwich », « pizza ») becomes editable lines, unless the person usually keeps a
            // food of their own for this label.
            if useDishKnowledge, preferred == nil, let template = DishTemplate.template(forLabel: score.label) {
                let lines = templateLines(template, score: score, minimumConfidence: minimumConfidence,
                                          learning: learning, search: search)
                if !lines.isEmpty {
                    lines.forEach(keep)
                    continue
                }
            }
            let useful = usefulWords(of: score.label)
            guard !useful.isEmpty else { continue }
            var confidence = score.confidence
            let found = find(label: score.label, useful: useful, useDishKnowledge: useDishKnowledge, search: search)
            var match = found?.food
            var alternative = found?.alternative
            if found?.isPartial == true { confidence *= partialMatchFactor }
            let detectedID = match?.id
            var usesHabit = false
            // The food the person usually keeps for this label wins, but only once it is reliable.
            if let preferred {
                if preferred.id != detectedID { usesHabit = true }
                match = preferred
                alternative = nil
                confidence = max(confidence, score.confidence)
            }
            guard let food = match, confidence >= minimumConfidence else { continue }
            if let known = best[food.id], known.confidence >= confidence { continue }
            // The usual quantity of the person for this food, once it is reliable, else the usual portion.
            var grams = food.servingGrams > 0 ? food.servingGrams : 100
            if let usual = learning.usualGrams(forFoodID: food.id), usual.isFinite, usual > 0 {
                grams = usual
                usesHabit = true
            }
            keep(MealProposal(
                food: food, grams: grams, confidence: confidence,
                label: cleaned(score.label), detectedFoodID: detectedID, usesHabit: usesHabit,
                alternative: alternative
            ))
        }
        let ordered = best.values.sorted {
            $0.confidence != $1.confidence ? $0.confidence > $1.confidence : $0.food.id < $1.food.id
        }
        return Array(ordered.prefix(limit))
    }

    // MARK: Dish templates

    /// A dish is less sure than a food named by the classifier: it is a guess of what is on the plate.
    static let templateFactor = 0.9
    /// An optional component (a sauce, a garnish) is less sure than the base of the dish.
    static let optionalFactor = 0.6

    /// The lines of a dish: one per component found in the tables, the usual portion of the dish for each.
    /// Nothing is frozen: every line is an estimate the person can edit or drop.
    private static func templateLines(
        _ template: DishTemplate, score: LabelScore, minimumConfidence: Double,
        learning: ScanLearning, search: (String) -> [FoodItem]
    ) -> [MealProposal] {
        var lines: [MealProposal] = []
        for (index, component) in template.components.enumerated() {
            var found: Found?
            for query in component.foodQuery.split(separator: "|") {
                let text = String(query)
                found = pick(from: lookup(text, search), query: text, isPartial: false, search: search)
                if found != nil { break }
            }
            guard let found else { continue }
            // The first components (the base of the dish) are the surest.
            var confidence = score.confidence * templateFactor * max(0.5, 1 - 0.03 * Double(index))
            if component.isOptional { confidence *= optionalFactor }
            guard confidence >= minimumConfidence else { continue }
            var grams = component.grams
            var usesHabit = false
            if let usual = learning.usualGrams(forFoodID: found.food.id), usual.isFinite, usual > 0 {
                grams = usual
                usesHabit = true
            }
            lines.append(MealProposal(
                food: found.food, grams: grams, confidence: confidence,
                label: cleaned(score.label), detectedFoodID: found.food.id, usesHabit: usesHabit,
                alternative: found.alternative, dishName: template.name, isOptional: component.isOptional
            ))
        }
        return lines
    }

    // MARK: Finding a food for a label

    /// A food found for a label, with the other cooking state of the same food when the table has both.
    private struct Found {
        var food: FoodItem
        var alternative: FoodItem?
        var isPartial: Bool
    }

    /// The best food for a label: its synonyms first, then its words (all, then the last one with less
    /// confidence).
    private static func find(label: String, useful: [String], useDishKnowledge: Bool, search: (String) -> [FoodItem]) -> Found? {
        let full = useful.joined(separator: " ")
        if useDishKnowledge {
            var queries = FoodSynonyms.queries(forLabel: label)
            if FoodSynonyms.key(for: full) != FoodSynonyms.key(for: label) {
                queries += FoodSynonyms.queries(forLabel: full)
            }
            for query in queries {
                if let found = pick(from: lookup(query, search), query: query, isPartial: false, search: search) { return found }
            }
        }
        if let found = pick(from: search(full), query: full, isPartial: false, search: search) { return found }
        guard useful.count > 1, let head = useful.last else { return nil }
        if useDishKnowledge {
            for query in FoodSynonyms.queries(forLabel: head) {
                if let found = pick(from: lookup(query, search), query: query, isPartial: true, search: search) { return found }
            }
        }
        return pick(from: search(head), query: head, isPartial: true, search: search)
    }

    /// The foods for a search; « id:builtin.xxx » names a food of the built-in table directly.
    private static func lookup(_ query: String, _ search: (String) -> [FoodItem]) -> [FoodItem] {
        if query.hasPrefix("id:") { return FoodDatabase.item(String(query.dropFirst(3))).map { [$0] } ?? [] }
        return search(query)
    }

    /// The first result that really answers the query, cooked rather than raw.
    private static func pick(from results: [FoodItem], query: String, isPartial: Bool, search: (String) -> [FoodItem]) -> Found? {
        let candidates = results.filter { accepts($0, forQuery: query) }
        guard let first = candidates.first else { return nil }
        let (food, alternative) = cookedChoice(first, among: candidates, search: search)
        return Found(food: food, alternative: alternative, isPartial: isPartial)
    }

    /// False when a short word of the query is only the start of a longer, unrelated word of the name
    /// (« pie » → « pied de porc », « corn » → « corned beef »). A plural is fine (« egg » → « eggs »).
    /// A name that does not contain the word at all (found through another name) is kept.
    static func accepts(_ food: FoodItem, forQuery query: String) -> Bool {
        let nameWords = wordList(FoodDatabase.normalized(food.name))
        for token in wordList(FoodDatabase.normalized(query)) where token.count >= 3 && token.count <= 4 {
            let starting = nameWords.filter { $0.hasPrefix(token) }
            if starting.isEmpty { continue }
            let isWholeWord = starting.contains { $0 == token || $0 == token + "s" || $0 == token + "x" || $0 == token + "es" }
            if !isWholeWord { return false }
        }
        return true
    }

    private static func wordList(_ text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    // MARK: Raw and cooked

    enum CookingState { case raw, cooked }

    private static let rawWords: Set<String> = ["cru", "crue", "crus", "crues", "raw"]
    private static let cookedWords: Set<String> = [
        "cuit", "cuite", "cuits", "cuites", "bouilli", "bouillie", "bouillis", "bouillies", "roti", "rotie", "rotis", "roties",
        "grille", "grillee", "grilles", "grillees", "braise", "braisee", "poele", "poelee", "vapeur",
        "cooked", "roasted", "boiled", "grilled", "baked", "steamed", "broiled", "braised",
    ]
    private static let linkWords: Set<String> = ["de", "du", "des", "la", "le", "les", "et", "au", "aux", "d", "a", "en", "with", "and", "of"]

    /// Raw or cooked, read from the name of the food; nil when the name says neither (bread, milk, a dish).
    static func cookingState(of food: FoodItem) -> CookingState? {
        let words = wordList(FoodDatabase.normalized(food.name))
        if words.contains(where: { rawWords.contains($0) }) { return .raw }
        if words.contains(where: { cookedWords.contains($0) }) { return .cooked }
        return nil
    }

    /// The name of the food without its cooking words: the first two words tell if two foods are the same
    /// food in two states.
    private static func baseKey(of food: FoodItem) -> String {
        wordList(FoodDatabase.normalized(food.name))
            .filter { !rawWords.contains($0) && !cookedWords.contains($0) && !linkWords.contains($0) }
            .prefix(2).joined(separator: " ")
    }

    /// For a served dish the cooked version is the default; the other state, when the table has it, is
    /// kept as the alternative.
    private static func cookedChoice(_ first: FoodItem, among candidates: [FoodItem], search: (String) -> [FoodItem]) -> (FoodItem, FoodItem?) {
        guard let state = cookingState(of: first) else { return (first, nil) }
        let key = baseKey(of: first)
        guard !key.isEmpty else { return (first, nil) }
        func sameFood(_ other: FoodItem, _ wanted: CookingState) -> Bool {
            other.id != first.id && cookingState(of: other) == wanted && baseKey(of: other) == key
        }
        switch state {
        case .cooked:
            return (first, candidates.first { sameFood($0, .raw) })
        case .raw:
            if let cooked = candidates.first(where: { sameFood($0, .cooked) }) { return (cooked, first) }
            for suffix in ["cuit", "cooked"] {
                if let cooked = search(key + " " + suffix).first(where: { sameFood($0, .cooked) }) { return (cooked, first) }
            }
            return (first, nil)
        }
    }
}
