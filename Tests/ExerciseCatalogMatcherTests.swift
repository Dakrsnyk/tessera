import XCTest
@testable import Ardane

/// Requests of 2026-11-23: the extended exercise catalogue (free-exercise-db, public domain) and the exercises typed by hand
/// understood as an exercise of the library, so that every one gets its statistics, its sheet and a demonstration.
final class ExerciseCatalogMatcherTests: XCTestCase {
    // MARK: Catalogue

    func testTheCatalogueIsLoadedWithTheBuiltInExercisesFirst() {
        let all = ExerciseLibrary.all
        XCTAssertGreaterThanOrEqual(ExerciseCatalog.exercises.count, 75, "The distinct movements kept by the triage")
        XCTAssertGreaterThanOrEqual(all.count, 240)
        XCTAssertEqual(Array(all.prefix(ExerciseLibrary.builtIn.count)).map(\.id), ExerciseLibrary.builtIn.map(\.id),
                       "The 163 written exercises keep their place")
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "Each exercise once")
        XCTAssertTrue(ExerciseCatalog.exercises.allSatisfy { $0.id.hasPrefix("x-") })
        XCTAssertTrue(ExerciseCatalog.exercises.contains { $0.equipment.contains(.machine) }, "Machines included")
    }

    func testEveryCatalogueExerciseHasADemonstrationAndATechnique() throws {
        for exercise in ExerciseCatalog.exercises {
            if let source = exercise.demoID {
                XCTAssertNotNil(ExerciseLibrary.builtIn.first { $0.id == source }, exercise.id)
            }
            XCTAssertNotNil(ExerciseDemos.demo(for: exercise.id), exercise.id)
            XCTAssertNotNil(ExerciseCatalog.techniques[exercise.id], "\(exercise.id): its own explanation")
        }
    }

    /// The triage (CEO, 2026-11-23): a variant merged into another exercise leads there, by its id and by its name.
    func testAMergedExerciseLeadsToTheExerciseKept() throws {
        let kept = try XCTUnwrap(ExerciseCatalog.redirects["x-kettlebell-pirate-ships"])
        XCTAssertEqual(ExerciseLibrary.info("x-kettlebell-pirate-ships")?.id, kept, "A set saved with the old id keeps its exercise")
        XCTAssertEqual(ExerciseLibrary.canonical("x-kettlebell-pirate-ships"), kept)
        XCTAssertEqual(ExerciseLibrary.canonical("bench-press"), "bench-press")
        XCTAssertFalse(ExerciseCatalog.exercises.contains { $0.id == "x-kettlebell-pirate-ships" }, "No longer listed")
        XCTAssertEqual(ExerciseLibrary.match(name: "Bateau pirate kettlebell")?.id, kept, "Its name is an alias of the kept one")
    }

    func testANameInEachLanguage() throws {
        let entry = try XCTUnwrap(ExerciseCatalog.file?.exercises.first)
        for language in ["fr", "en", "es", "de", "it", "pt-BR", "ja"] {
            XCTAssertEqual(ExerciseCatalog.name(entry.n, language: language), entry.n[language], language)
        }
        XCTAssertEqual(ExerciseCatalog.name(entry.n, language: "ko"), entry.n["en"], "A language the app doesn't have: English")
        let info = try XCTUnwrap(ExerciseCatalog.exercise(entry, language: "fr"))
        XCTAssertEqual(info.name, entry.n["fr"])
        XCTAssertTrue(info.aliases.contains(entry.n["en"] ?? ""), "The other languages are aliases")
    }

    func testEachNameLeadsToOneExerciseInEachLanguage() throws {
        let entries = try XCTUnwrap(ExerciseCatalog.file?.exercises)
        for language in ["fr", "en", "es", "de", "it", "pt-BR", "ja"] {
            let names = entries.compactMap { $0.n[language].map(ExerciseLibrary.normalized) }
            XCTAssertEqual(names.count, entries.count, language)
            XCTAssertEqual(Set(names).count, names.count, "\(language): a name repeats")
        }
    }

    // MARK: Words

    func testTheWordsOfAName() {
        XCTAssertEqual(ExerciseMatcher.words("Curl à la poulie (pronation)"), ["curl", "cable", "reverse"])
        XCTAssertEqual(ExerciseMatcher.words("Développé épaules (haltères)"), ExerciseMatcher.words("dumbbell shoulder press"))
        XCTAssertEqual(ExerciseMatcher.words("Curl au pupitre"), ExerciseMatcher.words("Larry Scott curl"))
        XCTAssertEqual(ExerciseMatcher.words("Soulevé de terre"), ["deadlift"])
        XCTAssertTrue(ExerciseMatcher.close("squatt", "squat"))
        XCTAssertFalse(ExerciseMatcher.close("curl", "carl"), "Short words must be exact")
    }

    // MARK: Exercises typed by hand

    /// The names of the CEO's Progress page (2026-11-23) that had no statistics: saved in French, read on an iPhone in English.
    func testTheExercisesOfTheProgressPageAreRecognised() {
        let expected = [
            "Curl à la poulie": "cable-curl", "Curl au pupitre": "preacher-curl", "Curl concentration": "concentration-curl",
            "Curl incliné": "incline-curl", "Curl inversé (pronation)": "reverse-curl", "Curl marteau": "hammer-curl",
            "Développé couché (barre)": "bench-press", "Développé épaules (haltères)": "db-shoulder-press",
            "Développé incliné (haltères)": "incline-db", "Écarté à la poulie (vis-à-vis)": "cable-fly",
        ]
        for (name, id) in expected {
            XCTAssertEqual(ExerciseLibrary.match(name: name)?.id, id, name)
        }
    }

    func testNamesWrittenDifferentlyAreUnderstood() {
        XCTAssertEqual(ExerciseLibrary.match(name: "Cable curl")?.id, "cable-curl", "Another language")
        XCTAssertEqual(ExerciseLibrary.match(name: "hammer curls")?.id, "hammer-curl", "Plural")
        XCTAssertEqual(ExerciseLibrary.match(name: "curl biceps haltères")?.id, "db-curl", "Extra words")
        XCTAssertEqual(ExerciseLibrary.match(name: "squatt bulgare")?.id, "bulgarian-split", "A typo")
        XCTAssertEqual(ExerciseLibrary.match(name: "SDT")?.id, "deadlift", "Gym slang")
        XCTAssertNotNil(ExerciseLibrary.match(name: "curl poulie corde"), "An exercise of the catalogue")
    }

    /// Code review, 2026-11-23: a word that makes another exercise is never ignored, and the built-in exercises keep
    /// their names and aliases (a saved set keeps counting for the exercise it always counted for).
    func testAnotherExerciseIsNeverTakenForThisOne() {
        XCTAssertNotEqual(ExerciseLibrary.match(name: "Curl inversé poulie")?.id, "cable-curl", "Reverse is another curl")
        XCTAssertNotEqual(ExerciseLibrary.match(name: "Curl poulie basse allongé")?.id, "cable-curl", "Lying is another curl")
        XCTAssertEqual(ExerciseLibrary.match(name: "élévations latérales haltères")?.id, "lateral-raise", "Its own equipment, typed")
        XCTAssertEqual(ExerciseLibrary.match(name: "Développé incliné")?.id, "incline-bench")
        XCTAssertEqual(ExerciseLibrary.match(name: "cable crossover")?.id, "cable-fly", "A built-in alias stays with its exercise")
        XCTAssertEqual(ExerciseMatcher.score(typed: ["curl", "cable", "reverse"], name: ["curl", "cable"]), 0)
        XCTAssertGreaterThan(ExerciseMatcher.score(typed: ["lateral", "raise", "dumbbell"], name: ["lateral", "raise"], equipment: ["dumbbell"]), 0.5)
    }

    func testAnInventedNameStaysThePersonsOwn() {
        XCTAssertNil(ExerciseLibrary.match(name: "Mon exercice inventé"))
        XCTAssertNil(ExerciseLibrary.match(name: "zzzz"))
        XCTAssertNil(ExerciseLibrary.match(name: ""))
    }

    func testAnswersAreRemembered() {
        let first = ExerciseLibrary.match(name: "Curl à la poulie")?.id
        XCTAssertEqual(ExerciseMatcher.cached(ExerciseLibrary.normalized("Curl à la poulie")), .some(first))
        XCTAssertEqual(ExerciseLibrary.match(name: "Curl à la poulie")?.id, first)
    }

    func testASetTypedByHandCountsForItsExercise() {
        var state = FitnessState()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        state.startSession(Routine(name: "Bras", exercises: [ExerciseTemplate(name: "Curl à la poulie", sets: 1, reps: 12, weight: 40)]), at: start)
        _ = state.completeNextSet(at: start.addingTimeInterval(60))
        state.finishActive(at: start.addingTimeInterval(120))
        let cable = ExerciseLibrary.info("cable-curl")!
        XCTAssertEqual(FitnessMath.history(of: cable, state).count, 1, "Its history, its chart and its records")
    }
}
