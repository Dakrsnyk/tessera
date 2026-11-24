import Foundation

/// Understands an exercise typed by hand (« Curl à la poulie », « Développé épaules (haltères) », « curl inversé
/// pronation ») and finds the exercise of the library it is, on the device, by its words (2026-11-23):
/// - accents, case and punctuation ignored, empty words dropped (à, la, de, with…), plurals made singular;
/// - the words of the gym written differently brought to one (poulie = câble = cable, pupitre = Larry Scott = preacher,
///   inversé = pronation = reverse, développé = press, soulevé de terre = deadlift…), in French and English;
/// - then the name or alias whose words fit best: all the typed words found in it (the fewest extra words win), or
///   all of its words found in what was typed, one typo allowed in a long word. Nothing close enough: nil, the
///   exercise stays the person's own.
/// `ExerciseLibrary.match(name:)` asks it after the exact names and aliases, and remembers the answer per name.
enum ExerciseMatcher {
    // MARK: Memory

    private static let lock = NSLock()
    private static var memory: [String: String?] = [:]

    /// The id found earlier for this normalized name: `.some(nil)` when none was.
    static func cached(_ key: String) -> String?? {
        lock.lock()
        defer { lock.unlock() }
        return memory[key]
    }

    static func remember(_ key: String, _ id: String?) {
        lock.lock()
        // Every name typed letter by letter goes through here: kept small.
        if memory.count >= 4_000 { memory.removeAll(keepingCapacity: true) }
        memory[key] = .some(id)
        lock.unlock()
    }

    /// Prepares the indexes away from the screen (they take a moment with 900 exercises in 7 languages).
    static func warmUp() {
        _ = exactIndex.count
        _ = index.count
    }

    // MARK: Exact names

    /// Every name, name without its detail in parentheses, and alias, normalized → the exercise: the built-in exercises
    /// first (names, then names without detail, then aliases), then the catalogue the same way. The first holder of a
    /// name keeps it, so a set that always counted for a built-in exercise keeps counting for it.
    private static let exactIndex: [String: String] = {
        var out: [String: String] = [:]
        func add(_ key: String, _ id: String) {
            if !key.isEmpty, out[key] == nil { out[key] = id }
        }
        let all = ExerciseLibrary.all
        let builtInCount = ExerciseLibrary.builtIn.count
        for list in [Array(all.prefix(builtInCount)), Array(all.dropFirst(builtInCount))] {
            for exercise in list { add(ExerciseLibrary.normalized(exercise.name), exercise.id) }
            for exercise in list { add(ExerciseLibrary.base(exercise.name), exercise.id) }
            for exercise in list {
                for alias in exercise.aliases { add(ExerciseLibrary.normalized(alias), exercise.id) }
            }
        }
        return out
    }()

    /// The exercise whose name or alias is exactly this normalized text.
    static func exact(_ key: String) -> String? { exactIndex[key] }

    // MARK: Words

    /// Words that say nothing about the exercise.
    static let emptyWords: Set<String> = [
        "a", "au", "aux", "de", "du", "des", "la", "le", "les", "l", "d", "en", "avec", "sur", "et", "un", "une", "pour", "par",
        "the", "with", "on", "of", "and", "to", "in", "an", "prise", "grip", "exercice", "exercise",
    ]

    /// Expressions of several words, made one word before anything else (normalized, without accents).
    static let phrases: [(String, String)] = [
        ("souleve de terre", "deadlift"), ("larry scott", "preacher"), ("pull up", "pullup"), ("pull ups", "pullup"),
        ("chin up", "chinup"), ("chin ups", "chinup"), ("push up", "pushup"), ("push ups", "pushup"),
        ("a un bras", "single"), ("un bras", "single"), ("one arm", "single"), ("single arm", "single"),
        ("a une jambe", "single"), ("une jambe", "single"), ("one leg", "single"), ("single leg", "single"),
        ("vis a vis", "crossover"), ("cable crossover", "crossover"),
        ("tirage vertical", "pulldown"), ("tirage poitrine", "pulldown"), ("tirage nuque", "pulldown"),
        ("lat pulldown", "pulldown"), ("pull down", "pulldown"), ("tirage horizontal", "row"),
        ("hip thrust", "hipthrust"), ("face pull", "facepull"), ("skull crusher", "skullcrusher"), ("barre au front", "skullcrusher"),
        ("good morning", "goodmorning"), ("kick back", "kickback"), ("presse a cuisses", "legpress"), ("presse a cuisse", "legpress"),
        ("leg press", "legpress"), ("prise serree", "close"), ("close grip", "close"), ("prise large", "wide"), ("wide grip", "wide"),
        ("prise neutre", "neutral"), ("neutral grip", "neutral"), ("barre guidee", "smith"), ("smith machine", "smith"),
    ]

    /// One word for the same thing (after the plural is taken off).
    static let synonyms: [String: String] = [
        "poulie": "cable", "cable": "cable",
        "haltere": "dumbbell", "dumbbell": "dumbbell", "db": "dumbbell", "halt": "dumbbell",
        "barre": "barbell", "barbell": "barbell", "bb": "barbell",
        "pupitre": "preacher", "preacher": "preacher",
        "marteau": "hammer", "hammer": "hammer",
        "incline": "incline", "inclinee": "incline", "inclined": "incline",
        "decline": "decline", "declinee": "decline", "declined": "decline",
        "developpe": "press", "developpee": "press", "press": "press", "presse": "press",
        "ecarte": "fly", "ecartee": "fly", "fly": "fly", "flye": "fly", "flie": "fly", "butterfly": "fly",
        "traction": "pullup", "pullup": "pullup",
        "rowing": "row", "row": "row",
        "sdt": "deadlift", "deadlift": "deadlift",
        "fente": "lunge", "lunge": "lunge",
        "mollet": "calf", "calf": "calf", "calve": "calf",
        "inverse": "reverse", "inversee": "reverse", "reverse": "reverse", "pronation": "reverse",
        "epaule": "shoulder", "shoulder": "shoulder", "militaire": "shoulder", "military": "shoulder", "overhead": "shoulder",
        "laterale": "lateral", "lateral": "lateral",
        "frontale": "front", "frontal": "front", "front": "front",
        "elevation": "raise", "raise": "raise",
        "pec": "chest", "pectoral": "chest", "pectorau": "chest", "chest": "chest",
        "abdo": "abs", "abdominal": "abs", "abdominau": "abs",
        "pompe": "pushup", "pushup": "pushup",
        "gainage": "plank", "planche": "plank", "plank": "plank",
        "assi": "seated", "seated": "seated", "debout": "standing", "standing": "standing",
        "unilateral": "single", "unilaterale": "single",
        "serree": "close", "large": "wide", "neutre": "neutral",
        "jambe": "leg", "leg": "leg",
        "elastique": "band", "band": "band", "kb": "kettlebell",
        "banc": "bench", "bench": "bench",
        "hanche": "hip", "fessier": "glute", "glute": "glute",
        "corde": "rope", "rope": "rope",
        "guidee": "smith",
        "allonge": "lying", "allongee": "lying", "lying": "lying",
    ]

    /// « Curl à la poulie (pronation) » → {curl, cable, reverse}
    static func words(_ text: String) -> Set<String> {
        let folded = ExerciseLibrary.normalized(text).lowercased()
        var line = " " + String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ").joined(separator: " ") + " "
        for (phrase, word) in phrases where line.contains(" \(phrase) ") {
            line = line.replacingOccurrences(of: " \(phrase) ", with: " \(word) ")
        }
        var out = Set<String>()
        for raw in line.split(separator: " ") {
            let word = String(raw)
            guard !emptyWords.contains(word) else { continue }
            let one = singular(word)
            out.insert(synonyms[one] ?? synonyms[word] ?? one)
        }
        return out
    }

    /// « curls » → « curl », « biceps » → « bicep », « jumeaux » → « jumeau »; short words and « press » stay.
    static func singular(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("s") && !word.hasSuffix("ss") { return String(word.dropLast()) }
        if word.hasSuffix("x") && word.count > 4 { return String(word.dropLast()) }
        return word
    }

    // MARK: Finding

    private struct Candidate {
        let id: String
        let words: Set<String>
        /// The equipment words of the exercise: typed but missing from this name, they still fit (« élévations
        /// latérales haltères » is « Élévations latérales », done with dumbbells).
        let equipment: Set<String>
    }

    static func equipmentWords(_ equipment: [Equipment]) -> Set<String> {
        var out = Set<String>()
        for tool in equipment {
            switch tool {
            case .dumbbells: out.insert("dumbbell")
            case .barbell: out.formUnion(["barbell", "ez"])
            case .cable: out.insert("cable")
            case .machine: out.formUnion(["machine", "smith"])
            case .kettlebell: out.insert("kettlebell")
            case .band: out.insert("band")
            case .bench: out.insert("bench")
            case .bodyweight, .pullUpBar, .other: break
            }
        }
        return out
    }

    /// Every name and alias of the library, as words, in the library's order (the built-in exercises first).
    private static let index: [Candidate] = {
        var out: [Candidate] = []
        for exercise in ExerciseLibrary.all {
            let equipment = equipmentWords(exercise.equipment)
            var seen: [Set<String>] = []
            for name in [exercise.name] + exercise.aliases {
                let set = words(name)
                guard !set.isEmpty, !seen.contains(set) else { continue }
                seen.append(set)
                out.append(Candidate(id: exercise.id, words: set, equipment: equipment))
            }
        }
        return out
    }()

    /// Words that make another exercise: a name and what was typed that differ by one of them are not the same exercise
    /// (« Curl inversé poulie » is not « Curl à la poulie », « Développé incliné » is not « Développé incliné haltères »).
    static let qualifiers: Set<String> = [
        "reverse", "incline", "decline", "single", "wide", "close", "neutral", "seated", "standing", "dumbbell", "barbell",
        "cable", "smith", "machine", "kettlebell", "band", "preacher", "hammer", "front", "lateral", "rope", "bench", "ez", "lying",
    ]

    /// How well the typed words fit one name: 1 is the same words, 0 does not fit.
    static func score(typed: Set<String>, name: Set<String>, equipment: Set<String> = []) -> Double {
        guard !typed.isEmpty, !name.isEmpty else { return 0 }
        if typed == name { return 1 }
        let typedFound = typed.filter { word in name.contains(word) || name.contains { close(word, $0) } }
        let nameCovered = name.filter { word in typed.contains(word) || typed.contains { close(word, $0) } }
        // A qualifier only on one side makes another exercise, except the exercise's own equipment typed by the person.
        let differing = typed.subtracting(typedFound).subtracting(equipment).union(name.subtracting(nameCovered))
        guard differing.isDisjoint(with: qualifiers) else { return 0 }
        let found = typedFound.count
        let covered = nameCovered.count
        if found == typed.count, typed.count >= 2 || name.count == 1 {
            return Double(typed.count) / Double(name.count)            // all typed words are in the name
        }
        if covered == name.count, name.count >= 2 {
            return 0.9 * Double(name.count) / Double(typed.count)      // the whole name is in what was typed
        }
        let shared = min(found, covered)
        guard shared >= 2 else { return 0 }
        let jaccard = Double(shared) / Double(typed.count + name.count - shared)
        return jaccard >= 0.6 ? 0.85 * jaccard : 0
    }

    /// The closest exercise for a name typed by hand, nil when none is close enough.
    static func closest(to text: String) -> ExerciseInfo? {
        let typed = words(text)
        guard !typed.isEmpty else { return nil }
        var best: (score: Double, id: String)?
        for candidate in index {
            let value = score(typed: typed, name: candidate.words, equipment: candidate.equipment)
            if value > (best?.score ?? 0) { best = (value, candidate.id) }   // equal: the earlier one (built-in first)
            if value == 1 { break }
        }
        guard let best, best.score >= 0.5 else { return nil }
        return ExerciseLibrary.info(best.id)
    }

    /// The same word with one letter wrong, missing or extra (words of 5 letters or more).
    static func close(_ a: String, _ b: String) -> Bool {
        guard a.count >= 5, b.count >= 5, abs(a.count - b.count) <= 1, a != b else { return a == b }
        let x = Array(a), y = Array(b)
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var current = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[y.count] <= 1
    }
}
