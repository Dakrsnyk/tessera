import Foundation

// The personal visual memory of the food scanner (chantier 22.3): what the classifier "sees" in a zone of a photo (its
// embedding, a vector of numbers, never the picture) is kept with the food the person finally validated for it. The next time
// a zone looks like something already validated, the remembered food weighs in the answer next to the model's own
// probabilities. Everything stays on this iPhone, in a file of the App Group container.
//
// Pure arithmetic and a small file store; Foundation only (this folder is also compiled in the widget extension).

/// One validated zone: the food the person kept (an identifier of the tables, or of their own foods), the embedding of the
/// zone (unit length, quantised to one byte per value to stay compact) and the day.
struct PersonalFoodEntry: Codable, Hashable, Sendable {
    var foodKey: String
    /// The unit vector times 127, one signed byte per value.
    var vector: Data
    var date: Date

    enum CodingKeys: String, CodingKey { case foodKey, vector, date }

    init(foodKey: String, vector: Data, date: Date) {
        self.foodKey = foodKey
        self.vector = vector
        self.date = date
    }

    /// Tolerant: a damaged field gives an entry that is never used (empty key or vector), never an error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        foodKey = c.value(.foodKey, "")
        vector = c.value(.vector, Data())
        date = c.value(.date, Date(timeIntervalSince1970: 0))
    }
}

/// The zones the person validated, and what they say about a new zone. At most `maximumEntries` in all and
/// `maximumPerFood` per food (the oldest go first).
struct PersonalFoodMemory: Codable, Hashable, Sendable {
    static let maximumEntries = 400
    static let maximumPerFood = 25
    /// A remembered zone counts as a neighbour from this cosine similarity. Réglage initial, non mesuré.
    static let minimumSimilarity = 0.80
    /// The memory looks at this many nearest neighbours.
    static let neighbourCount = 5
    /// The share of the memory in the answer when a neighbour is identical (similarity 1). Réglage initial, non mesuré.
    static let maximumWeight = 0.7

    var entries: [PersonalFoodEntry] = []

    enum CodingKeys: String, CodingKey { case entries }

    init(entries: [PersonalFoodEntry] = []) {
        self.entries = entries
    }

    /// Tolerant: a missing or wrong list is an empty memory.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = c.value(.entries, [])
    }

    var isEmpty: Bool { entries.isEmpty }

    // MARK: Vectors

    /// The vector scaled to length 1, or nil when it is empty, has a value that is not a number, or is all zeros.
    static func normalized(_ values: [Float]) -> [Float]? {
        guard !values.isEmpty else { return nil }
        var sum = 0.0
        for value in values {
            guard value.isFinite else { return nil }
            sum += Double(value) * Double(value)
        }
        guard sum > 1e-12 else { return nil }
        let norm = Float(sum.squareRoot())
        return values.map { $0 / norm }
    }

    /// A unit vector as one signed byte per value (value × 127).
    static func quantized(_ unit: [Float]) -> Data {
        Data(unit.map { value -> UInt8 in
            let scaled = max(-127, min(127, (value * 127).rounded()))
            return UInt8(bitPattern: Int8(scaled))
        })
    }

    /// The unit vector of a quantised one (nil when it is empty or all zeros).
    static func dequantized(_ data: Data) -> [Float]? {
        normalized(data.map { Float(Int8(bitPattern: $0)) / 127 })
    }

    private static func dot(_ a: [Float], _ b: [Float]) -> Double {
        var sum = 0.0
        for index in 0..<min(a.count, b.count) { sum += Double(a[index]) * Double(b[index]) }
        return sum
    }

    // MARK: Recording

    /// Keeps a zone with the food finally validated for it. An embedding that cannot be used, or a food without a key, is
    /// ignored. Entries of another size (the model changed) are dropped: they could never be compared again.
    mutating func record(foodKey: String, embedding: [Float], date: Date) {
        guard !foodKey.isEmpty, let unit = Self.normalized(embedding) else { return }
        let vector = Self.quantized(unit)
        entries.removeAll { $0.vector.count != vector.count }
        entries.append(PersonalFoodEntry(foodKey: foodKey, vector: vector, date: date))
        removeOldest(whileOver: Self.maximumPerFood) { $0.foodKey == foodKey }
        removeOldest(whileOver: Self.maximumEntries) { _ in true }
    }

    private mutating func removeOldest(whileOver limit: Int, where belongs: (PersonalFoodEntry) -> Bool) {
        while true {
            let indices = entries.indices.filter { belongs(entries[$0]) }
            guard indices.count > limit else { return }
            // The oldest date; the first of equal dates.
            guard let oldest = indices.min(by: { entries[$0].date != entries[$1].date ? entries[$0].date < entries[$1].date : $0 < $1 }) else { return }
            entries.remove(at: oldest)
        }
    }

    // MARK: Reading

    /// The probabilities of the model mixed with what the memory says about a zone with this embedding.
    ///
    /// - The neighbours are the `neighbourCount` closest remembered zones whose cosine similarity is at least
    ///   `minimumSimilarity` (entries of another size are ignored). Without any, the model's answer is returned as it is.
    /// - p_mem(food) = sum of the similarities of the neighbours of that food / sum of all their similarities.
    /// - α = `maximumWeight` × clamp((best similarity − threshold) / (1 − threshold), 0, 1).
    /// - p = (1 − α) p_model + α p_mem, over the union of the foods (a remembered food the model did not list may appear),
    ///   the most likely first (a tie keeps the model's order, then the memory's).
    func fused(model: [(key: String, probability: Double)], embedding: [Float]) -> [(key: String, probability: Double)] {
        guard !entries.isEmpty, let query = Self.normalized(embedding) else { return model }
        var neighbours: [(key: String, similarity: Double, date: Date)] = []
        for entry in entries where !entry.foodKey.isEmpty && entry.vector.count == query.count {
            guard let stored = Self.dequantized(entry.vector) else { continue }
            let similarity = Self.dot(query, stored)
            if similarity.isFinite, similarity >= Self.minimumSimilarity {
                neighbours.append((entry.foodKey, similarity, entry.date))
            }
        }
        guard !neighbours.isEmpty else { return model }
        neighbours.sort { $0.similarity != $1.similarity ? $0.similarity > $1.similarity : $0.date > $1.date }
        let nearest = Array(neighbours.prefix(Self.neighbourCount))
        let total = nearest.reduce(0) { $0 + $1.similarity }
        guard total > 0 else { return model }

        var fromMemory: [String: Double] = [:]
        for neighbour in nearest { fromMemory[neighbour.key, default: 0] += neighbour.similarity / total }
        let span = 1 - Self.minimumSimilarity
        let strength = min(1, max(0, (nearest[0].similarity - Self.minimumSimilarity) / span))
        let alpha = Self.maximumWeight * strength

        var order: [String] = []
        var fromModel: [String: Double] = [:]
        for item in model {
            if fromModel[item.key] == nil { order.append(item.key) }
            fromModel[item.key, default: 0] += item.probability
        }
        var listed = Set(order)
        for neighbour in nearest where !listed.contains(neighbour.key) {
            order.append(neighbour.key)
            listed.insert(neighbour.key)
        }
        var ranked: [(key: String, probability: Double, position: Int)] = []
        for (position, key) in order.enumerated() {
            let mixed = (1 - alpha) * (fromModel[key] ?? 0) + alpha * (fromMemory[key] ?? 0)
            ranked.append((key, mixed, position))
        }
        ranked.sort { $0.probability != $1.probability ? $0.probability > $1.probability : $0.position < $1.position }
        return ranked.map { (key: $0.key, probability: $0.probability) }
    }
}

// MARK: - File

/// The memory on the iPhone: one file in the App Group container (it can reach several hundred kilobytes, too much for
/// UserDefaults). Nothing leaves the device. A file that cannot be read yet (iPhone locked) is left alone, never replaced.
enum PersonalFoodMemoryStore {
    static let fileName = "PersonalFoodMemory.json"
    private static let lock = NSLock()

    static var defaultDirectory: URL {
        AppGroup.containerURL.appendingPathComponent("Tessera", isDirectory: true)
    }

    private static func fileURL(_ directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    private static func decoded(_ data: Data) -> PersonalFoodMemory? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(PersonalFoodMemory.self, from: data)
    }

    /// The saved memory; empty when there is none or it cannot be read.
    static func load(directory: URL = PersonalFoodMemoryStore.defaultDirectory) -> PersonalFoodMemory {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL(directory)) else { return PersonalFoodMemory() }
        return decoded(data) ?? PersonalFoodMemory()
    }

    /// Adds the zones the person validated (the food finally kept for each, corrected or not).
    static func record(
        _ items: [(foodKey: String, embedding: [Float])], date: Date,
        directory: URL = PersonalFoodMemoryStore.defaultDirectory
    ) {
        guard !items.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        let url = fileURL(directory)
        var memory = PersonalFoodMemory()
        if FileManager.default.fileExists(atPath: url.path) {
            // Present but unreadable (protected): leave it alone rather than replace it with a short memory.
            guard let data = try? Data(contentsOf: url) else { return }
            memory = decoded(data) ?? PersonalFoodMemory()
        }
        for item in items { memory.record(foodKey: item.foodKey, embedding: item.embedding, date: date) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(memory) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: SharedStore.writingOptions)
    }

    /// Forgets everything (to be called by a reset of what the scanner learned).
    static func clear(directory: URL = PersonalFoodMemoryStore.defaultDirectory) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL(directory))
    }
}

// MARK: - Zone hints

/// What the recap needs to know about a zone the models found: the food the models gave it (to find its line again), the
/// embedding to remember once the person validates, and the other foods the models thought of (one-tap replacements).
struct ScanZoneHint: Hashable {
    var detectedFoodID: String
    var embedding: [Float]?
    var alternatives: [FoodItem]

    init(detectedFoodID: String, embedding: [Float]?, alternatives: [FoodItem]) {
        self.detectedFoodID = detectedFoodID
        self.embedding = embedding
        self.alternatives = alternatives
    }
}
