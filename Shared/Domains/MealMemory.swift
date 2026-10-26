import Foundation

/// A food and a quantity the person validated for a meal.
struct MealMemoryItem: Codable, Hashable {
    var foodID: String
    var grams: Double

    enum CodingKeys: String, CodingKey { case foodID, grams }

    init(foodID: String, grams: Double) {
        self.foodID = foodID
        self.grams = grams
    }

    /// Tolerant: a missing field takes a harmless value, never an error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        foodID = c.value(.foodID, "")
        grams = c.value(.grams, 0)
    }
}

/// One meal remembered from a photo: the visual fingerprint of the photo (a vector of numbers computed by
/// Vision on the iPhone, never the photo itself) and what the person validated for it.
///
/// On disk the fingerprint is packed (a scale and one byte per number, in base64): 200 meals stay small in
/// the file the widgets read. The packing loses a little precision, which does not matter for a distance.
struct MealMemoryEntry: Codable, Hashable {
    var date: Date
    var featurePrint: [Float]
    var items: [MealMemoryItem]

    enum CodingKeys: String, CodingKey { case date, featurePrint, items }

    init(date: Date, featurePrint: [Float], items: [MealMemoryItem]) {
        self.date = date
        self.featurePrint = featurePrint
        self.items = items
    }

    /// Tolerant: a fingerprint written packed or as a plain list is read; anything else gives an empty
    /// fingerprint (the entry is then dropped by `MealMemory`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.value(.date, Date(timeIntervalSince1970: 0))
        items = c.value(.items, [])
        let packed: String? = c.optional(.featurePrint)
        if let packed {
            featurePrint = Self.unpack(packed)
        } else {
            featurePrint = c.value(.featurePrint, [Float]())
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(Self.pack(featurePrint), forKey: .featurePrint)
        try c.encode(items, forKey: .items)
    }

    // MARK: Packing

    /// 4 bytes (the largest absolute value, as a Float, little endian) then one signed byte per number.
    static func pack(_ values: [Float]) -> String {
        let scale = values.map { abs($0) }.filter { $0.isFinite }.max() ?? 0
        var bytes: [UInt8] = []
        bytes.reserveCapacity(4 + values.count)
        let bits = scale.bitPattern
        for shift in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8((bits >> UInt32(shift)) & 0xFF)) }
        for value in values {
            let unit = (scale > 0 && value.isFinite) ? max(-1, min(1, value / scale)) : 0
            bytes.append(UInt8(bitPattern: Int8((unit * 127).rounded())))
        }
        return Data(bytes).base64EncodedString()
    }

    static func unpack(_ text: String) -> [Float] {
        guard let data = Data(base64Encoded: text), data.count > 4 else { return [] }
        let bytes = [UInt8](data)
        var bits: UInt32 = 0
        for index in 0..<4 { bits |= UInt32(bytes[index]) << UInt32(8 * index) }
        let scale = Float(bitPattern: bits)
        guard scale.isFinite, scale > 0 else { return [] }
        return bytes.dropFirst(4).map { Float(Int8(bitPattern: $0)) / 127 * scale }
    }
}

/// The meals the person validated from a photo, kept on this iPhone to recognise a similar plate later.
/// Pure logic (no Vision): the fingerprints are computed by the app.
///
/// - A proposal exists only when at least `minimumAgreeing` close meals contain the same food. One similar
///   meal never decides, and when nothing agrees there is no proposal: nothing is ever invented.
/// - At most `maximumEntries` meals are kept, the oldest go first.
struct MealMemory: Codable, Hashable {
    static let maximumEntries = 200
    static let minimumAgreeing = 2
    /// How many close meals are looked at.
    static let neighbourCount = 5
    /// The largest distance (0 identical to 1 opposite, see `distance`) at which two meals are « close ».
    /// Prudent on purpose: a proposal that never appears costs nothing, a wrong one costs trust.
    static let maximumDistance = 0.2
    /// A fingerprint longer than this is refused (Vision's are 2048 numbers); keeps the file small.
    static let maximumPrintSize = 4_096
    /// A quantity outside this range is not remembered.
    static let gramsRange: ClosedRange<Double> = 1...5_000

    var entries: [MealMemoryEntry] = []

    enum CodingKeys: String, CodingKey { case entries }

    init() {}

    /// Tolerant: missing entries are an empty memory; an entry without a usable fingerprint is dropped.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decoded: [MealMemoryEntry] = c.value(.entries, [])
        entries = Array(decoded.filter { Self.isUsable($0.featurePrint) }.suffix(Self.maximumEntries))
    }

    // MARK: Distance

    private static func isUsable(_ fingerprint: [Float]) -> Bool {
        norm(fingerprint) != nil
    }

    /// The length of the vector, nil when it is empty, not finite or all zeros.
    private static func norm(_ vector: [Float]) -> Double? {
        guard !vector.isEmpty else { return nil }
        var sum = 0.0
        for value in vector {
            guard value.isFinite else { return nil }
            sum += Double(value) * Double(value)
        }
        let length = sum.squareRoot()
        return length > 0 ? length : nil
    }

    /// The distance between two fingerprints: both are scaled to length 1 (so only the shape counts, not
    /// the size of the numbers) and the euclidean distance is halved, which gives 0 (the same) to 1 (opposite).
    /// Nil when the fingerprints cannot be compared (different sizes, empty, not finite, zeros).
    static func distance(_ a: [Float], _ b: [Float]) -> Double? {
        guard a.count == b.count, let na = norm(a), let nb = norm(b) else { return nil }
        var sum = 0.0
        for index in a.indices {
            let delta = Double(a[index]) / na - Double(b[index]) / nb
            sum += delta * delta
        }
        return min(1, sum.squareRoot() / 2)
    }

    // MARK: Recording

    /// Remembers a validated meal. Nothing is kept for a fingerprint that cannot be used, or when no food
    /// has a plausible quantity. A food seen twice in the meal is kept once (quantities added).
    mutating func record(date: Date, featurePrint: [Float], items: [MealMemoryItem]) {
        guard Self.isUsable(featurePrint), featurePrint.count <= Self.maximumPrintSize else { return }
        var kept: [MealMemoryItem] = []
        for item in items where !item.foodID.isEmpty && item.grams.isFinite && item.grams > 0 {
            if let index = kept.firstIndex(where: { $0.foodID == item.foodID }) {
                kept[index].grams += item.grams
            } else {
                kept.append(item)
            }
        }
        kept = kept.filter { Self.gramsRange.contains($0.grams) }
        guard !kept.isEmpty else { return }
        entries.append(MealMemoryEntry(date: date, featurePrint: featurePrint, items: kept))
        if entries.count > Self.maximumEntries {
            entries.removeFirst(entries.count - Self.maximumEntries)
        }
    }

    // MARK: Reading

    /// The remembered meals closest to a fingerprint, the closest first, only those within `maximumDistance`.
    func nearest(
        to featurePrint: [Float], limit: Int = MealMemory.neighbourCount, maximumDistance: Double = MealMemory.maximumDistance
    ) -> [(entry: MealMemoryEntry, distance: Double)] {
        guard limit > 0 else { return [] }
        var found: [(entry: MealMemoryEntry, distance: Double)] = []
        for entry in entries {
            guard let d = Self.distance(featurePrint, entry.featurePrint), d <= maximumDistance else { continue }
            found.append((entry, d))
        }
        found.sort { $0.distance < $1.distance }
        return Array(found.prefix(limit))
    }

    /// What the person usually has on a plate that looks like this one, with the date of the most recent
    /// meal that agrees. Only foods found in at least `minimumAgreeing` close meals; the quantity is the
    /// median of those meals. Nil when fewer than two meals are close or none of their foods agree.
    func suggestionWithDate(for featurePrint: [Float]) -> (items: [MealMemoryItem], date: Date)? {
        let neighbours = nearest(to: featurePrint)
        guard neighbours.count >= Self.minimumAgreeing else { return nil }
        var grams: [String: [Double]] = [:]
        for neighbour in neighbours {
            // Once per meal, even if the food is listed twice.
            for id in Set(neighbour.entry.items.map(\.foodID)) {
                let total = neighbour.entry.items.filter { $0.foodID == id }.reduce(0) { $0 + $1.grams }
                grams[id, default: []].append(total)
            }
        }
        let agreeing = grams.filter { $0.value.count >= Self.minimumAgreeing }
        guard !agreeing.isEmpty else { return nil }
        let items = agreeing
            .sorted { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }
            .map { MealMemoryItem(foodID: $0.key, grams: Self.median($0.value)) }
        var latest: Date?
        for neighbour in neighbours where neighbour.entry.items.contains(where: { item in agreeing[item.foodID] != nil }) {
            if latest == nil || neighbour.entry.date > latest! { latest = neighbour.entry.date }
        }
        guard let date = latest else { return nil }
        return (items, date)
    }

    func suggestion(for featurePrint: [Float]) -> [MealMemoryItem]? {
        suggestionWithDate(for: featurePrint)?.items
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}
