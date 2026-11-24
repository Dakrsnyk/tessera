import Foundation

/// The exercises of free-exercise-db (public domain: The Unlicense) beyond the ones written in `ExerciseLibrary`,
/// read once from Shared/Resources/ExerciseCatalog.json (built by scripts/exercises/build_catalog.py, 2026-11-23).
/// Each comes with its name in the 7 languages of the app (shown in the interface's language, every one of them
/// recognised when typed), its muscles, equipment (machines included), type and level, its movement, and the
/// built-in exercise whose hand-made demonstration it shows (`demoID`). The ids (« x-… ») are saved in the sets:
/// never rename one.
enum ExerciseCatalog {
    struct Entry: Decodable {
        let id: String
        /// Names by language: fr, en, es, de, it, pt-BR, ja.
        let n: [String: String]
        /// Other ways to write it (the dataset's English name, gym slang).
        let a: [String]
        let p: [String]
        let s: [String]
        let e: [String]
        let t: String
        let d: String
        let m: String
        let demo: String?
        /// Its own technique, by language (fr, en, es, de, it, pt-BR, ja), for a movement the family's doesn't describe.
        let tq: [String: Technique]?
    }

    struct Technique: Decodable {
        let start: String
        let steps: [String]
        let range: String
        let breathing: String
        let tips: [String]
        let mistakes: [String]
    }

    struct File: Decodable {
        let exercises: [Entry]
        /// Dataset names of exercises the app already had: more ways to recognise a built-in exercise.
        let extraAliases: [String: [String]]
        /// Exercises merged into another one by the triage (2026-11-23): their id → the exercise kept. A set saved with
        /// a merged id keeps counting for the exercise kept.
        var redirects: [String: String]? = nil
    }

    static let file: File? = {
        guard let url = Bundle.main.url(forResource: "ExerciseCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static let exercises: [ExerciseInfo] = (file?.exercises ?? []).compactMap { exercise($0, language: Localization.language) }

    static var extraAliases: [String: [String]] { file?.extraAliases ?? [:] }

    static var redirects: [String: String] { file?.redirects ?? [:] }

    /// The techniques written for kept imported exercises, in the interface's language (then English).
    static let techniques: [String: ExerciseTechnique] = {
        var out: [String: ExerciseTechnique] = [:]
        let language = Localization.language
        for entry in file?.exercises ?? [] {
            guard let table = entry.tq,
                  let t = table[language] ?? table[String(language.prefix(2))] ?? table["en"] ?? table["fr"],
                  !t.start.isEmpty, t.steps.count >= 2, !t.mistakes.isEmpty else { continue }
            out[entry.id] = ExerciseTechnique(start: t.start, steps: t.steps, range: t.range, breathing: t.breathing,
                                              tips: t.tips, mistakes: t.mistakes)
        }
        return out
    }()

    /// The name in the interface's language (« pt-BR », then « pt »), else English.
    static func name(_ names: [String: String], language: String) -> String? {
        names[language] ?? names[String(language.prefix(2))] ?? names["en"] ?? names["fr"]
    }

    static func exercise(_ entry: Entry, language: String) -> ExerciseInfo? {
        guard let name = name(entry.n, language: language),
              let type = ExerciseType(rawValue: entry.t),
              let difficulty = Difficulty(rawValue: entry.d),
              let pattern = MovementPattern(rawValue: entry.m) else { return nil }
        let primary = entry.p.compactMap(Muscle.init(rawValue:))
        let equipment = entry.e.compactMap(Equipment.init(rawValue:))
        guard !primary.isEmpty, !equipment.isEmpty else { return nil }
        // Every language's name is a way to find it: a person writing in English in a French app is understood.
        var aliases: [String] = []
        for alias in entry.a + entry.n.keys.sorted().compactMap({ entry.n[$0] }) where alias != name && !aliases.contains(alias) {
            aliases.append(alias)
        }
        return ExerciseInfo(id: entry.id, name: name, aliases: aliases, primary: primary,
                            secondary: entry.s.compactMap(Muscle.init(rawValue:)).filter { !primary.contains($0) },
                            equipment: equipment, type: type, difficulty: difficulty, pattern: pattern, cues: [], demoID: entry.demo)
    }
}
