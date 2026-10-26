import Foundation

/// One food of the recap shown after a scan, with the quantity that will be logged.
///
/// - `isEstimate` false: the food comes from a table or from the person (a product found by its
///   barcode, a food of the table, a custom food) and the quantity is theirs.
/// - `isEstimate` true: the food and its portion were guessed from a photo of a dish. The calories
///   and macronutrients are computed from the values of the food, for the estimated quantity.
struct ScanLine: Identifiable, Hashable {
    let id: UUID
    var food: FoodItem
    var grams: Double
    var isEstimate: Bool
    /// How sure the photo analysis is of the food (0 to 1). Nil for a food chosen by the person.
    var confidence: Double?
    /// The labels the photo analysis gave to this food, the food it proposed and the quantity it proposed.
    /// Empty / nil for a food that was not proposed by a photo. Kept to record what the person corrects.
    var detectedLabels: [String]
    var detectedFoodID: String?
    var initialGrams: Double?
    /// True while the quantity is the usual portion of the food, as proposed: the person did not set it.
    var quantityIsUsual: Bool
    /// True when the food or quantity comes from the habits learned from the person's corrections.
    var usesHabit: Bool

    init(
        id: UUID = UUID(), food: FoodItem, grams: Double, isEstimate: Bool = false, confidence: Double? = nil,
        detectedLabels: [String] = [], detectedFoodID: String? = nil, initialGrams: Double? = nil,
        quantityIsUsual: Bool = false, usesHabit: Bool = false
    ) {
        self.id = id
        self.food = food
        self.grams = grams
        self.isEstimate = isEstimate
        self.confidence = confidence
        self.detectedLabels = detectedLabels
        self.detectedFoodID = detectedFoodID
        self.initialGrams = initialGrams
        self.quantityIsUsual = quantityIsUsual
        self.usesHabit = usesHabit
    }

    var totals: NutritionTotals { food.nutrients(grams: grams) }

    /// How far off the line can be, as a share of its value: a packaged product or a quantity the person
    /// set is close to exact, the usual portion of a table food is a guess of the portion, a photo a
    /// guess of both.
    var uncertainty: Double {
        if isEstimate { return ScanUncertainty.photoEstimate }
        if quantityIsUsual && food.source != .openFoodFacts { return ScanUncertainty.usualPortion }
        return ScanUncertainty.weighed
    }

    /// True when the line must be shown as a range, never as one exact number.
    var showsRange: Bool { uncertainty > ScanUncertainty.weighed }

    var kcalRange: NutrientRange { ScanUncertainty.range(of: totals.kcal, ratio: uncertainty) }

    /// An estimate the analysis is not sure of.
    var isLowConfidence: Bool {
        guard isEstimate, let confidence else { return false }
        return confidence < ScanRecap.lowConfidence
    }

    /// « peu sûr » / « assez sûr »: the confidence in words, only for an estimate that has one.
    var confidenceWord: String? {
        guard isEstimate, confidence != nil else { return nil }
        return isLowConfidence ? tr("peu sûr") : tr("assez sûr")
    }
}

/// What a scan found, editable before it is logged: a product read from a barcode, or the foods
/// guessed from the photo of a dish. Pure logic with no view, so it can be tested; the screen only
/// shows it.
struct ScanRecap: Hashable {
    static let minGrams = 1.0
    static let maxGrams = 5_000.0
    /// Under this confidence an estimate is shown as « peu sûr ».
    static let lowConfidence = 0.5

    var lines: [ScanLine] = []
    /// True when the foods were proposed from the photo of a dish: validating then records the
    /// corrections of the person (`ScanLearning`).
    var isPhoto = false
    /// The visual fingerprint of the photo (never the photo): validating stores it with the foods kept, in
    /// `NutritionState.mealMemory`. Nil when the photo gave none.
    var featurePrint: [Float]?
    /// The date of the remembered meal the first lines come from (`MealMemory`), nil when none does.
    var memoryDate: Date?

    init(lines: [ScanLine] = []) {
        self.lines = lines
    }

    /// The foods guessed from a photo: each one an estimate, in its usual portion.
    init(proposals: [MealProposal], featurePrint: [Float]? = nil, memoryDate: Date? = nil) {
        isPhoto = true
        self.featurePrint = featurePrint
        self.memoryDate = memoryDate
        for proposal in proposals { add(proposal) }
    }

    /// « Comme ton repas du 12 octobre »: shown when the proposal comes from a similar remembered meal.
    var memoryNote: String? {
        guard let memoryDate else { return nil }
        let day = memoryDate.formatted(.dateTime.day().month(.wide).locale(Fmt.locale))
        return String(format: tr("Comme ton repas du %@"), locale: Fmt.locale, day)
    }

    /// One food chosen or found by its barcode, in its usual portion (not an estimate).
    init(food: FoodItem) {
        add(food)
    }

    // MARK: Editing

    /// A quantity kept between `minGrams` and `maxGrams`.
    static func clamped(_ grams: Double) -> Double {
        guard grams.isFinite else { return minGrams }
        return min(maxGrams, max(minGrams, grams))
    }

    private static func usualGrams(of food: FoodItem) -> Double {
        food.servingGrams > 0 ? food.servingGrams : 100
    }

    /// Adds a food (its usual portion unless `grams` is given). A food already in the recap is not added
    /// twice: its quantity grows. Returns the id of the line.
    @discardableResult
    mutating func add(
        _ food: FoodItem, grams: Double? = nil, isEstimate: Bool = false, confidence: Double? = nil,
        detectedLabels: [String] = [], detectedFoodID: String? = nil, initialGrams: Double? = nil, usesHabit: Bool = false
    ) -> UUID {
        let amount = Self.clamped(grams ?? Self.usualGrams(of: food))
        let line = ScanLine(
            food: food, grams: amount, isEstimate: isEstimate, confidence: confidence,
            detectedLabels: detectedLabels, detectedFoodID: detectedFoodID, initialGrams: initialGrams,
            quantityIsUsual: grams == nil, usesHabit: usesHabit
        )
        lines.append(line)
        lines = Self.merge(lines)
        return lines.first { $0.food.id == food.id }?.id ?? line.id
    }

    /// A food proposed from a photo, in the portion proposed, as an estimate.
    @discardableResult
    mutating func add(_ proposal: MealProposal) -> UUID {
        add(
            proposal.food, grams: proposal.grams, isEstimate: proposal.isEstimate, confidence: proposal.confidence,
            detectedLabels: proposal.label.map { [$0] } ?? [], detectedFoodID: proposal.detectedFoodID ?? proposal.food.id,
            initialGrams: Self.clamped(proposal.grams), usesHabit: proposal.usesHabit
        )
    }

    mutating func remove(_ id: UUID) {
        lines.removeAll { $0.id == id }
    }

    /// Another food for the same line, with the same quantity. The line stays an estimate if it was one
    /// (the quantity still is), but the confidence belonged to the food that was replaced. If the new
    /// food is already in the recap, the two lines become one.
    mutating func replace(_ id: UUID, with food: FoodItem) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].food = food
        lines[index].confidence = nil
        lines[index].usesHabit = false
        lines = Self.merge(lines)
    }

    /// The quantity of a line, kept between `minGrams` and `maxGrams`. A value that is not a number is ignored.
    mutating func setGrams(_ id: UUID, _ grams: Double) {
        guard grams.isFinite, let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].grams = Self.clamped(grams)
        lines[index].quantityIsUsual = false
    }

    // MARK: Reading

    var isEmpty: Bool { lines.isEmpty }

    var totals: NutritionTotals {
        lines.reduce(NutritionTotals()) { $0 + $1.totals }
    }

    /// True when something in the recap is a guess.
    var hasEstimate: Bool { lines.contains { $0.isEstimate } }

    /// True when the totals must be shown as a range (a guessed food, or a portion nobody set).
    var showsRange: Bool { lines.contains { $0.showsRange } }

    /// True when a food of the recap has a macronutrient its source did not give: the macros are a minimum.
    var isIncomplete: Bool { lines.contains { $0.food.hasUnknownMacros } }

    /// The calories as an interval, by where each line comes from (see `ScanUncertainty`).
    var kcalRange: NutrientRange {
        lines.reduce(NutrientRange(low: 0, high: 0)) { $0 + $1.kcalRange }
    }

    /// There is something to log, and every quantity is a real one.
    var canConfirm: Bool {
        !lines.isEmpty && lines.allSatisfy { $0.grams.isFinite && $0.grams >= Self.minGrams }
    }

    /// The recap with a food that appears on several lines kept once: the first line stays (id and place),
    /// the quantities are added, it is an estimate if one of the lines was, and it keeps the lowest confidence.
    var merged: ScanRecap {
        var result = ScanRecap(lines: Self.merge(lines))
        result.isPhoto = isPhoto
        result.featurePrint = featurePrint
        result.memoryDate = memoryDate
        return result
    }

    private static func merge(_ lines: [ScanLine]) -> [ScanLine] {
        var result: [ScanLine] = []
        for line in lines {
            guard let index = result.firstIndex(where: { $0.food.id == line.food.id }) else {
                result.append(line)
                continue
            }
            result[index].grams = clamped(result[index].grams + line.grams)
            result[index].isEstimate = result[index].isEstimate || line.isEstimate
            result[index].quantityIsUsual = false
            result[index].usesHabit = result[index].usesHabit || line.usesHabit
            for label in line.detectedLabels where !result[index].detectedLabels.contains(label) {
                result[index].detectedLabels.append(label)
            }
            if result[index].detectedFoodID == nil { result[index].detectedFoodID = line.detectedFoodID }
            switch (result[index].initialGrams, line.initialGrams) {
            case let (a?, b?): result[index].initialGrams = a + b
            case let (nil, b?): result[index].initialGrams = b
            default: break
            }
            switch (result[index].confidence, line.confidence) {
            case let (a?, b?): result[index].confidence = min(a, b)
            case let (nil, b?): result[index].confidence = b
            default: break
            }
        }
        return result
    }

    // MARK: Logging

    /// Writes every line into the journal (a food seen twice is written once) and returns how many
    /// entries were added. A food already logged less than `window` seconds around `date` is a double
    /// tap or the same barcode scanned again: it is skipped, like the quick add of the widgets. A
    /// `window` of 0 turns that off (a day that is not today, where every entry gets the same usual time).
    /// The entries are marked as coming from a scan; for a photo, what the analysis proposed and what the
    /// person kept is recorded in `state.scanLearning` (on this iPhone only).
    @discardableResult
    func commit(into state: inout NutritionState, meal: MealType, at date: Date, window: TimeInterval = NutritionState.quickAddWindow) -> Int {
        var logged = 0
        var remembered: [MealMemoryItem] = []
        let finalRecap = merged
        for line in finalRecap.lines where line.grams >= Self.minGrams {
            let foodID = line.food.id
            let isDoubleTap = window > 0 && state.entries.contains {
                $0.food.id == foodID && abs(date.timeIntervalSince($0.date)) < window
            }
            if isDoubleTap { continue }
            state.log(line.food, grams: line.grams, meal: meal, at: date, origin: .scan)
            if finalRecap.isPhoto {
                state.scanLearning.record(
                    ScanCorrection(
                        date: date, labels: line.detectedLabels, detectedFoodID: line.detectedFoodID,
                        initialGrams: line.initialGrams, validatedFoodID: line.food.id, validatedGrams: line.grams
                    ),
                    plausibleGramsRange: ScanLearning.plausibleGrams(for: line.food)
                )
                remembered.append(MealMemoryItem(foodID: line.food.id, grams: line.grams))
            }
            logged += 1
        }
        // The visual memory of the meal: the fingerprint and what was kept, never the photo.
        if finalRecap.isPhoto, let fingerprint = finalRecap.featurePrint, !remembered.isEmpty {
            state.mealMemory.record(date: date, featurePrint: fingerprint, items: remembered)
        }
        return logged
    }
}

// MARK: - Suggested lines

/// A food the photo cannot show but a dish often has (cooking oil, butter, sauce). Only proposed to the
/// person, who confirms it: it is never added to the recap on its own.
struct ScanSuggestion: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case oil, butter, sauce
    }

    let kind: Kind
    let food: FoodItem
    let grams: Double

    var id: String { kind.rawValue }
    var totals: NutritionTotals { food.nutrients(grams: grams) }

    var title: String {
        switch kind {
        case .oil: tr("Huile de cuisson ?")
        case .butter: tr("Beurre ?")
        case .sauce: tr("Sauce ?")
        }
    }
}

extension ScanRecap {
    /// Words of a food name (lowercase, French or English) that make an addition likely.
    private static let oilWords = ["fried", "fry", "frit", "saut", "roast", "rôti", "roti", "grill", "stir", "poêl", "poel", "wok", "vegetable", "légume", "legume", "rice", "riz"]
    private static let butterWords = ["toast", "bread", "pain", "potato", "pomme de terre", "steak", "fish", "poisson", "omelet", "omelette", "egg", "œuf", "oeuf", "pancake", "crêpe", "crepe"]
    private static let sauceWords = ["pasta", "pâtes", "pates", "spaghetti", "noodle", "pizza", "salad", "salade", "burger", "sandwich", "sushi"]

    /// Cooking fats and sauces to offer for a photo recap, never added by themselves. Only for a photo
    /// (a barcode product is complete), only for foods the recap does not have yet, and only when the name
    /// of a guessed food makes them likely. `foodByID`: the food of the table with this id.
    func suggestions(
        foodByID: (String) -> FoodItem? = { id in FoodDatabase.all.first { $0.id == id } }
    ) -> [ScanSuggestion] {
        guard isPhoto else { return [] }
        let names = lines.filter { $0.isEstimate }.map { $0.food.name.lowercased() }
        func likely(_ words: [String]) -> Bool {
            names.contains { name in words.contains { name.contains($0) } }
        }
        let candidates: [(kind: ScanSuggestion.Kind, id: String, grams: Double, isLikely: Bool)] = [
            (.oil, "builtin.oliveoil", 10, likely(Self.oilWords)),
            (.butter, "builtin.butter", 10, likely(Self.butterWords)),
            (.sauce, "builtin.mayo", 15, likely(Self.sauceWords)),
        ]
        var result: [ScanSuggestion] = []
        for candidate in candidates where candidate.isLikely {
            guard !lines.contains(where: { $0.food.id == candidate.id }), let food = foodByID(candidate.id) else { continue }
            result.append(ScanSuggestion(kind: candidate.kind, food: food, grams: candidate.grams))
        }
        return result
    }

    /// Adds a suggestion the person confirmed, as an estimate.
    mutating func accept(_ suggestion: ScanSuggestion) {
        add(suggestion.food, grams: suggestion.grams, isEstimate: true)
    }
}
