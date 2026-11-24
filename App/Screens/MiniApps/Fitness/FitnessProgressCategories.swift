import SwiftUI

// MARK: - Categories of the Progress page

/// The families the Progress page files the exercises done under: chest, back, shoulders... A category
/// comes from the exercise's type, then from its first main muscle; an exercise the library doesn't
/// know goes to « Autres ».
enum ExerciseCategory: String, CaseIterable, Identifiable {
    case chest, back, shoulders, arms, legs, abs, fullBody, cardio, mobility, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: tr("Pectoraux")
        case .back: tr("Dos")
        case .shoulders: tr("Épaules")
        case .arms: tr("Bras")
        case .legs: tr("Jambes")
        case .abs: tr("Abdominaux")
        case .fullBody: tr("Corps entier")
        case .cardio: tr("Cardio")
        case .mobility: tr("Mobilité et étirements")
        case .other: tr("Autres")
        }
    }

    var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.climbing"
        case .shoulders: "figure.arms.open"
        case .arms: "dumbbell.fill"
        case .legs: "figure.step.training"
        case .abs: "figure.core.training"
        case .fullBody: "figure.cross.training"
        case .cardio: "heart.fill"
        case .mobility: "figure.flexibility"
        case .other: "ellipsis.circle.fill"
        }
    }

    /// The anatomy figure of the category (the body with its muscles in red), none for cardio, mobility and others.
    var anatomyID: String? {
        switch self {
        case .chest: MuscleGroup.chest.anatomyID
        case .back: MuscleGroup.back.anatomyID
        case .shoulders: MuscleGroup.shoulders.anatomyID
        case .arms: MuscleGroup.biceps.anatomyID
        case .legs: MuscleGroup.quads.anatomyID
        case .abs: MuscleGroup.abs.anatomyID
        case .fullBody: MuscleGroup.fullBody.anatomyID
        case .cardio, .mobility, .other: nil
        }
    }

    /// The category of an exercise of the library.
    static func of(_ info: ExerciseInfo) -> ExerciseCategory {
        switch info.type {
        case .stretching, .mobility: return .mobility
        case .cardio: return .cardio
        case .strength: break
        }
        switch info.primary.first {
        case .chest: return .chest
        case .back, .traps, .lowerBack: return .back
        case .shoulders: return .shoulders
        case .biceps, .triceps, .forearms: return .arms
        case .quads, .hamstrings, .glutes, .calves: return .legs
        case .abs, .obliques: return .abs
        case .fullBody: return .fullBody
        case .heart: return .cardio
        case nil: return .other
        }
    }
}

/// An exercise the person did, with her own numbers.
struct ProgressExercise: Identifiable, Hashable {
    /// What merges the names of the same exercise: the library id, else the name without accents or case.
    let key: String
    /// The library id when the exercise is known (opens its sheet), nil otherwise.
    let id: String?
    let name: String
    let category: ExerciseCategory
    /// The best set: its load (0 for bodyweight) and its reps.
    let bestWeight: Double
    let bestReps: Int
    let sessionCount: Int
    /// How much heavier the best set is than the first session's heaviest load (0 for bodyweight).
    let gain: Double
}

struct ProgressCategoryGroup: Identifiable, Hashable {
    let category: ExerciseCategory
    /// The most practised first.
    let exercises: [ProgressExercise]
    var id: String { category.rawValue }
    var sessionCount: Int { exercises.reduce(0) { $0 + $1.sessionCount } }
}

enum FitnessProgressCategories {
    /// The key of a set: its library id, else the id the name resolves to, else the normalized name.
    static func key(of set: SetLog) -> String {
        if let id = set.exerciseID ?? ExerciseLibrary.match(name: set.exercise)?.id { return id }
        return "name:" + ExerciseLibrary.normalized(set.exercise)
    }

    /// The exercises done, grouped by category (empty categories left out, in the order of `ExerciseCategory`).
    static func groups(_ state: FitnessState) -> [ProgressCategoryGroup] {
        struct Acc {
            var name: String
            var info: ExerciseInfo?
            var best: SetLog?
            var sessions = 0
            var firstTop: Double?
        }
        var byKey: [String: Acc] = [:]
        for session in FitnessMath.sessions(state).sorted(by: { $0.start < $1.start }) {
            var perKey: [String: [SetLog]] = [:]
            for set in session.sets { perKey[key(of: set), default: []].append(set) }
            for (k, sets) in perKey {
                var acc = byKey[k] ?? {
                    let id = sets[0].exerciseID ?? ExerciseLibrary.match(name: sets[0].exercise)?.id
                    let info = id.flatMap { ExerciseLibrary.info($0) }
                    return Acc(name: info?.name ?? sets[0].exercise, info: info)
                }()
                acc.sessions += 1
                if acc.firstTop == nil { acc.firstTop = sets.map(\.weight).max() ?? 0 }
                for set in sets where isBetter(set, than: acc.best) { acc.best = set }
                byKey[k] = acc
            }
        }
        var perCategory: [ExerciseCategory: [ProgressExercise]] = [:]
        for (k, acc) in byKey {
            guard let best = acc.best else { continue }
            let category = acc.info.map(ExerciseCategory.of) ?? .other
            let gain = best.weight > 0 ? max(0, best.weight - (acc.firstTop ?? best.weight)) : 0
            perCategory[category, default: []].append(
                ProgressExercise(key: k, id: acc.info?.id, name: acc.name, category: category,
                                 bestWeight: best.weight, bestReps: best.reps, sessionCount: acc.sessions, gain: gain))
        }
        return ExerciseCategory.allCases.compactMap { category in
            guard let list = perCategory[category], !list.isEmpty else { return nil }
            let sorted = list.sorted {
                $0.sessionCount != $1.sessionCount ? $0.sessionCount > $1.sessionCount : $0.name < $1.name
            }
            return ProgressCategoryGroup(category: category, exercises: sorted)
        }
    }

    /// A loaded set beats a bodyweight one; loaded sets compare by estimated one-rep max, bodyweight ones by reps.
    private static func isBetter(_ set: SetLog, than best: SetLog?) -> Bool {
        guard let best else { return true }
        if set.weight > 0 || best.weight > 0 {
            if (set.weight > 0) != (best.weight > 0) { return set.weight > 0 }
            return FitnessMath.oneRepMax(set) > FitnessMath.oneRepMax(best)
        }
        return set.reps > best.reps
    }
}

// MARK: - Text shared by the two pages

extension ProgressExercise {
    /// "62,5 × 8", or "15 reps" for the bodyweight.
    func bestText(in system: UnitSystem) -> String {
        if bestWeight > 0 { return "\(Units.loadNumber(kilograms: bestWeight, in: system)) × \(bestReps)" }
        let reps = String(bestReps)
        return tr("\(reps) reps")
    }
}

// MARK: - The page of a category

/// The exercises done in a category: each with its best set, its sessions and what it gained since the
/// start; a known exercise opens its sheet (demonstration, technique, history, chart).
struct FitnessProgressCategoryPage: View {
    let category: ExerciseCategory
    @Environment(AppModel.self) private var model

    var body: some View {
        let group = FitnessProgressCategories.groups(model.fitness).first { $0.category == category }
        MiniAppScroll {
            if !model.isPremium {
                PremiumLockCard(symbol: "chart.line.uptrend.xyaxis", title: tr("La progression est dans Premium"),
                                message: tr("Ton volume semaine après semaine, l'évolution de tes charges et tous tes records, exercice par exercice. Tes séances restent enregistrées : tout s'affiche dès que tu passes à Premium."))
            } else if let group {
                MiniRowsCard {
                    ForEach(Array(group.exercises.enumerated()), id: \.element.key) { index, exercise in
                        exerciseRow(exercise)
                        if index < group.exercises.count - 1 { MiniDivider() }
                    }
                }
            } else {
                EmptyStateView(symbol: category.symbol, title: tr("Rien dans cette catégorie"), message: tr("Les exercices que tu fais ici apparaîtront avec leurs records."))
                    .card()
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
    }

    private func exerciseRow(_ exercise: ProgressExercise) -> some View {
        let system = model.settings.unitSystem
        let detail: String
        if exercise.sessionCount > 1 && exercise.gain > 0 {
            let gain = Units.loadText(kilograms: exercise.gain, in: system)
            let count = String(exercise.sessionCount)
            detail = tr("+\(gain) depuis le début · \(count) séances")
        } else {
            detail = Fmt.plural(exercise.sessionCount, tr("séance"), tr("séances"))
        }
        let info = exercise.id.flatMap { ExerciseLibrary.info($0) }
        // The exercise's own demonstration, small and looping (CEO, 2026-11-23); the whole sheet one tap away.
        let row = DemoRow(demoID: info?.id, symbol: category.symbol, title: exercise.name, detail: detail,
                          value: exercise.bestText(in: system), showsChevron: info != nil)
        .accessibilityIdentifier("progress-exercise-\(exercise.id ?? exercise.key)")
        return Group {
            if let info {
                NavigationLink(value: HomeRoute.page(.fitnessExercise(info.id))) { row }
            } else {
                row
            }
        }
        .buttonStyle(.pressable)
    }
}
