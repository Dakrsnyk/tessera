import SwiftUI
import WidgetKit

/// A ready-made combined widget in the Store: several widgets of one category in a medium or a large
/// widget, following the same rules as merging widgets in « Mes widgets » (see `Fusion`).
struct StoreCombo: Identifiable {
    struct Part {
        let kind: WidgetKind
        let size: WidgetFormat
        var template: String?
    }

    let id: String
    let name: String
    let tagline: String
    let parts: [Part]
    let theme: ThemeID
    let accent: String

    var comboParts: [ComboPart] {
        parts.map { part in
            let base = part.template.flatMap { TemplateCatalog.template($0) }?.makeDesign()
                ?? TemplateCatalog.template(for: part.kind)?.makeDesign()
                ?? WidgetDesign.starter(for: part.kind)
            return ComboPart(kind: part.kind, options: base.options, name: part.kind.title, size: part.size)
        }
    }

    var format: WidgetFormat { ComboLayout.format(comboParts) ?? .medium }
    var family: WidgetFamily { format.family }
    var category: WidgetCategory { parts[0].kind.category }

    func makeDesign() -> WidgetDesign {
        let comboParts = comboParts
        var options = DesignOptions()
        options.parts = comboParts
        return WidgetDesign(
            name: name,
            kind: comboParts[0].kind,
            themeID: theme,
            accentHex: accent,
            options: options,
            format: ComboLayout.format(comboParts)
        )
    }

    var isPremium: Bool { makeDesign().usesPremiumFeatures }

    /// « 2 widgets · Nutrition »
    var summary: String { tr("\(parts.count) widgets · \(category.title)") }
}

enum StoreComboCatalog {
    private static func combo(_ id: String, _ name: String, _ tagline: String, _ theme: ThemeID, _ accent: String,
                              _ parts: [StoreCombo.Part]) -> StoreCombo {
        StoreCombo(id: id, name: name, tagline: tagline, parts: parts, theme: theme, accent: accent)
    }

    private static func s(_ kind: WidgetKind, _ template: String? = nil) -> StoreCombo.Part {
        StoreCombo.Part(kind: kind, size: .small, template: template)
    }

    private static func m(_ kind: WidgetKind, _ template: String? = nil) -> StoreCombo.Part {
        StoreCombo.Part(kind: kind, size: .medium, template: template)
    }

    static let all: [StoreCombo] = mediums + larges

    /// Two small widgets side by side, in a medium widget.
    static let mediums: [StoreCombo] = [
        combo("jour-annee", tr("Jour et année"), tr("Où en est ta journée, et ton année."), .minimal, "2F8F7A",
              [s(.progress, "progress-day"), s(.progress, "progress-year")]),
        combo("heure-mois", tr("L'heure et le mois"), tr("L'heure d'un côté, le calendrier de l'autre."), .monochrome, "6B7280",
              [s(.clock), s(.calendar)]),
        combo("semaine-lune", tr("Semaine et lune"), tr("Ta semaine et la phase de la lune."), .dark, "8C6CFF",
              [s(.weekView), s(.moonPhase)]),
        combo("meteo-soleil", tr("Météo et soleil"), tr("Le temps qu'il fait et les heures de soleil."), .light, "F2A33A",
              [s(.weather), s(.sunCycle)]),
        combo("pluie-vent", tr("Pluie, vent et UV"), tr("Faut-il un parapluie, ou de la crème ?"), .glass, "3366FF",
              [s(.rainNext), s(.windUV)]),
        combo("calories-macros", tr("Calories et macros"), tr("Ce qu'il te reste à manger, et comment."), .glass, "2F8F7A",
              [s(.caloriesLeft), s(.macros)]),
        combo("proteines-repas", tr("Protéines et prochain repas"), tr("Ton objectif de protéines et ce qui vient."), .light, "F2A33A",
              [s(.proteinLeft), s(.nextMeal)]),
        combo("seance-regularite", tr("Séance et régularité"), tr("La séance du jour et ta semaine d'entraînement."), .dark, "FF6B57",
              [s(.todaysWorkout), s(.trainingStreak)]),
        combo("serie-repos", tr("Série et repos"), tr("La prochaine série et le temps de repos."), .futuristic, "3366FF",
              [s(.nextSet), s(.restTimer)]),
        combo("reste-epargne", tr("Reste du mois et épargne"), tr("Ce qu'il te reste, et ce que tu mets de côté."), .light, "2F8F7A",
              [s(.budgetLeft), s(.savingsGoal)]),
        combo("depense-factures", tr("Dépense et factures"), tr("Note une dépense, vois les factures qui arrivent."), .colorful, "FF6B57",
              [s(.quickExpense), s(.billsUpcoming)]),
        combo("eau-serie", tr("Eau et série"), tr("Tes verres d'eau et ta série d'habitudes."), .minimal, "3366FF",
              [s(.hydration), s(.habitStreak)]),
        combo("taches-top3", tr("Tâches et top 3"), tr("Ta liste et tes trois priorités du jour."), .light, "2F8F7A",
              [s(.tasks), s(.priorities)]),
        combo("focus-echeance", tr("Focus et échéance"), tr("Une séance de focus et la prochaine date limite."), .futuristic, "3366FF",
              [s(.focus), s(.deadline)]),
        combo("cours-examen", tr("Cours et examen"), tr("Le prochain cours et le prochain examen."), .minimal, "F2588F",
              [s(.nextClass), s(.nextExam)]),
        combo("fiche-session", tr("Fiche et session"), tr("Une fiche à réviser et l'avancement de ta session."), .retro, "F2A33A",
              [s(.flashcard, "flashcard-retro"), s(.semesterProgress)]),
        combo("depart-vol", tr("Départ et vol"), tr("Les jours avant le départ, et ton vol."), .aurora, "3366FF",
              [s(.tripCountdown, "trip-aurora"), s(.flight)]),
        combo("sur-place", tr("Heure et devise sur place"), tr("L'heure là-bas et combien ça coûte ici."), .retro, "F2A33A",
              [s(.localTime), s(.currency)]),
        combo("ventes-objectif", tr("Ventes et objectif"), tr("Les ventes du jour et l'objectif du mois."), .elegant, "F2A33A",
              [s(.revenueToday), s(.revenueGoal)]),
        combo("benefice-mrr", tr("Bénéfice et MRR"), tr("Ce que tu gagnes, et ce qui revient chaque mois."), .dark, "2F8F7A",
              [s(.profit), s(.mrr)]),
        combo("anniv-ferie", tr("Anniversaire et jour férié"), tr("Les deux prochaines dates à fêter."), .light, "F2588F",
              [s(.birthday), s(.holiday)]),
        combo("entretien-carburant", tr("Entretien et carburant"), tr("Le prochain entretien et ta consommation."), .dark, "6B7280",
              [s(.nextService), s(.fuelStats)]),
        combo("portefeuille-variation", tr("Portefeuille et variation"), tr("Ton portefeuille et ce qui bouge le plus."), .futuristic, "3366FF",
              [s(.portfolio), s(.topMover)]),
        combo("crypto-marche", tr("Bitcoin et marché"), tr("Le cours du bitcoin et le marché crypto."), .digital, "2F8F7A",
              [s(.crypto, "crypto-dark"), s(.marketOverview)]),
    ]

    /// Four small widgets, two medium ones, or one medium and two small, in a large widget.
    static let larges: [StoreCombo] = [
        combo("le-temps", tr("Le temps qui passe"), tr("L'heure, le mois, l'année et les vacances."), .minimal, "F2A33A",
              [s(.clock), s(.calendar), s(.progress, "progress-year"), s(.countdown, "countdown-holidays")]),
        combo("routine", tr("Routine du jour"), tr("Tes habitudes, ton eau et ta série."), .minimal, "8C6CFF",
              [m(.habits), s(.hydration), s(.habitStreak)]),
        combo("nutrition-complete", tr("Nutrition complète"), tr("Calories, macros, protéines et série de suivi."), .light, "2F8F7A",
              [s(.caloriesLeft), s(.macros), s(.proteinLeft), s(.nutritionStreak)]),
        combo("repas-calories", tr("Repas et calories"), tr("Tes repas du jour, tes calories et tes macros."), .glass, "F2A33A",
              [m(.mealsToday), s(.caloriesLeft), s(.macros)]),
        combo("salle", tr("Salle de sport"), tr("Série, repos, régularité et records."), .dark, "FF6B57",
              [s(.nextSet), s(.restTimer), s(.trainingStreak), s(.personalRecords)]),
        combo("seance-volume", tr("Séance et volume"), tr("La séance du jour et le volume de la semaine."), .futuristic, "3366FF",
              [m(.todaysWorkout), m(.weeklyVolume)]),
        combo("budget-mois", tr("Budget du mois"), tr("Tes dépenses, ce qu'il reste et ton épargne."), .light, "FF6B57",
              [m(.spendingByCategory), s(.budgetLeft), s(.savingsGoal)]),
        combo("mon-argent", tr("Mon argent"), tr("Reste, épargne, valeur nette et dépense rapide."), .colorful, "2F8F7A",
              [s(.budgetLeft), s(.savingsGoal), s(.netWorth), s(.quickExpense)]),
        combo("journee-productive", tr("Journée productive"), tr("Tes tâches, ton top 3 et une séance de focus."), .light, "2F8F7A",
              [m(.tasks), s(.priorities), s(.focus)]),
        combo("tout-le-ciel", tr("Tout le ciel"), tr("La météo, le soleil et la pluie à venir."), .aurora, "3366FF",
              [m(.weather), s(.sunCycle), s(.rainNext)]),
        combo("ma-session", tr("Ma session"), tr("L'horaire du jour, le prochain examen et la session."), .retro, "F2A33A",
              [m(.timetable), s(.nextExam), s(.semesterProgress)]),
        combo("en-voyage", tr("En voyage"), tr("Heure, devise, météo et prochaine activité."), .aurora, "3366FF",
              [s(.localTime), s(.currency), s(.destinationWeather), s(.nextActivity)]),
        combo("mon-entreprise", tr("Mon entreprise"), tr("Tes ventes sur 30 jours, l'objectif et le bénéfice."), .elegant, "F2A33A",
              [m(.revenueTrend), s(.revenueGoal), s(.profit)]),
        combo("ma-voiture", tr("Ma voiture"), tr("Ce qu'elle coûte, son entretien et son kilométrage."), .dark, "6B7280",
              [m(.carCost), s(.nextService), s(.mileage)]),
        combo("mes-placements", tr("Mes placements"), tr("Ton portefeuille, sa répartition et ce qui bouge."), .futuristic, "8C6CFF",
              [m(.portfolio), s(.allocation), s(.topMover)]),
        combo("monde-semaine", tr("Le monde et ma semaine"), tr("Tes fuseaux horaires et ta semaine."), .futuristic, "3366FF",
              [m(.worldClock, "world-futuristic"), m(.weekView)]),
    ]

    static func combo(_ id: String) -> StoreCombo? {
        all.first { $0.id == id }
    }

    /// The combinations of the categories the person is interested in, in the order they were picked.
    static func preferred(_ categories: [WidgetCategory]) -> [StoreCombo] {
        categories.flatMap { category in all.filter { $0.category == category } }
    }
}

// MARK: - Views

/// A combined widget in a Store shelf, at a given height, with its name and what it holds.
struct ComboCard: View {
    let combo: StoreCombo
    var height: CGFloat = 150
    let isPremiumUser: Bool

    var body: some View {
        let design = combo.makeDesign()
        let width = height * combo.family.aspectRatio
        VStack(alignment: .leading, spacing: 8) {
            WidgetPreview(design: design, family: combo.family, payload: SamplePayload.make(for: design), width: width)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(combo.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(combo.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if combo.isPremium && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(combo.name), \(combo.summary)"))
        .accessibilityHint(Text(tr("Ouvre l'éditeur")))
    }
}

/// Every combination, medium or large, grouped by category.
struct StoreCombosView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var size: SizeFilter = .all

    enum SizeFilter: String, CaseIterable, Identifiable {
        case all, medium, large
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: tr("Toutes")
            case .medium: tr("Moyennes")
            case .large: tr("Grandes")
            }
        }
    }

    private var shown: [StoreCombo] {
        StoreComboCatalog.all.filter { combo in
            switch size {
            case .all: true
            case .medium: combo.format == .medium
            case .large: combo.format == .large
            }
        }
    }

    private struct Group: Identifiable {
        let category: WidgetCategory
        let combos: [StoreCombo]
        var id: WidgetCategory { category }
    }

    /// Categories in the person's order of interest first, then the catalog order.
    private var groups: [Group] {
        let preferred = model.profile.preferredCategories
        let order = preferred + WidgetCategory.allCases.filter { !preferred.contains($0) }
        return order.compactMap { category -> Group? in
            let combos = shown.filter { $0.category == category }
            return combos.isEmpty ? nil : Group(category: category, combos: combos)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                Text(tr("Plusieurs widgets réunis en un seul, pour tout voir d'un coup d'œil. Touche-en un pour le personnaliser."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker(tr("Taille"), selection: $size) {
                    ForEach(SizeFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        Label(group.category.title, systemImage: group.category.symbol)
                            .font(.headline)
                            .foregroundStyle(Color(hex: group.category.colorHex))
                        ForEach(group.combos) { combo in
                            Button {
                                router.openEditor(combo.makeDesign(), isNew: true)
                            } label: {
                                ComboRow(combo: combo, isPremiumUser: model.isPremium)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(.screenGradient)
        .screenshotScroll()
        .navigationTitle(tr("Combinaisons"))
        .navigationBarTitleDisplayMode(.large)
    }
}

/// A combination across the page: the widget at full width, its name and tagline.
private struct ComboRow: View {
    let combo: StoreCombo
    let isPremiumUser: Bool

    var body: some View {
        let design = combo.makeDesign()
        VStack(alignment: .leading, spacing: 8) {
            WidgetPreview(design: design, family: combo.family, payload: SamplePayload.make(for: design))
                .frame(maxWidth: combo.format == .large ? 300 : .infinity)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(combo.name)
                        .font(.subheadline.weight(.semibold))
                    Text(combo.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if combo.isPremium && !isPremiumUser {
                    PremiumBadge(compact: true)
                } else {
                    GetLabel()
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(tr("Ouvre l'éditeur")))
    }
}

/// The « Obtenir » capsule of the Store.
struct GetLabel: View {
    var title = tr("Obtenir")

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}
