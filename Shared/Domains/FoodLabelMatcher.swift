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

    var id: String { food.id }

    init(food: FoodItem, grams: Double, confidence: Double, isEstimate: Bool = true) {
        self.food = food
        self.grams = grams
        self.confidence = confidence
        self.isEstimate = isEstimate
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
/// - each label gives its best match, a food is proposed once, and at most `maximumProposals` are kept;
/// - the quantity is the usual portion of the food, and the proposal says it is an estimate.
enum FoodLabelMatcher {
    /// A label the classifier gave to an image, with its confidence (0 to 1).
    struct LabelScore: Hashable {
        var label: String
        var confidence: Double
    }

    /// Under this confidence a label is not used.
    static let minimumConfidence = 0.15
    static let maximumProposals = 5
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
        search: (String) -> [FoodItem] = { FoodDatabase.search($0) }
    ) -> [MealProposal] {
        guard limit > 0 else { return [] }
        var best: [String: MealProposal] = [:]
        for score in scores.sorted(by: { $0.confidence > $1.confidence }) {
            guard score.confidence.isFinite, score.confidence >= minimumConfidence else { continue }
            let useful = usefulWords(of: score.label)
            guard !useful.isEmpty else { continue }
            var confidence = score.confidence
            var match = search(useful.joined(separator: " ")).first
            if match == nil, useful.count > 1, let head = useful.last {
                match = search(head).first
                confidence *= partialMatchFactor
            }
            guard let food = match, confidence >= minimumConfidence else { continue }
            if let known = best[food.id], known.confidence >= confidence { continue }
            let grams = food.servingGrams > 0 ? food.servingGrams : 100
            best[food.id] = MealProposal(food: food, grams: grams, confidence: confidence)
        }
        let ordered = best.values.sorted {
            $0.confidence != $1.confidence ? $0.confidence > $1.confidence : $0.food.id < $1.food.id
        }
        return Array(ordered.prefix(limit))
    }
}
