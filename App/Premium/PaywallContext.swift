import SwiftUI

/// What the paywall opens for: the thing the person touched, shown first with what Premium unlocks
/// there (the widget as it will look, the setup, the months before…), then everything else Premium
/// adds. Without one, the general paywall (Profil, the Premium banner).
struct PaywallContext: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
    /// Widgets shown as they will look once unlocked.
    var designs: [WidgetDesign] = []
    /// The advantage of the list it belongs to, put first.
    var perk: PaywallPerk?
}

/// The advantages listed on the paywall.
enum PaywallPerk: CaseIterable {
    case widgets, smart, packs, styles, history, exercises, photo
}

extension PaywallContext {
    /// Widgets that use Premium: a widget, a style, a background, a font, colors.
    static func designs(_ designs: [WidgetDesign]) -> PaywallContext {
        let features = designs.flatMap(\.premiumFeatures).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let usesWidget = designs.contains { $0.partDesigns.contains { $0.kind.isPremium } }
        let usesPhotoOrFont = designs.contains { $0.background.isPremium || $0.font.isPremium }
        return PaywallContext(
            symbol: "sparkles",
            title: designs.count > 1 ? tr("Débloque ces widgets") : tr("Débloque ce widget"),
            detail: features.isEmpty ? tr("Il utilise des réglages de Premium.") : features.prefix(4).joined(separator: " · "),
            designs: designs,
            perk: usesWidget ? .widgets : (usesPhotoOrFont ? .photo : .styles)
        )
    }

    /// More widgets than the free plan keeps (photo and quote widgets are unlimited).
    static var designLimit: PaywallContext {
        PaywallContext(
            symbol: "square.stack.3d.up.fill",
            title: tr("Plus de \(AppModel.freeDesignLimit) widgets"),
            detail: tr("La version gratuite garde \(AppModel.freeDesignLimit) widgets, et autant de photos et de citations que tu veux. Avec Premium, enregistre tous les widgets que tu veux, et garde tes variantes.")
        )
    }

    /// More habits than the free plan follows.
    static var habitLimit: PaywallContext {
        PaywallContext(
            symbol: "repeat",
            title: tr("Plus de \(AppModel.freeHabitLimit) habitudes"),
            detail: tr("La version gratuite suit \(AppModel.freeHabitLimit) habitudes. Avec Premium, suis-en autant que tu veux, sur tes widgets aussi.")
        )
    }

    /// The months before, in Finances.
    static var financesHistory: PaywallContext {
        PaywallContext(
            symbol: "calendar.badge.clock",
            title: tr("Tes mois passés"),
            detail: tr("Tout ce que tu notes est gardé. Premium affiche les mois d'avant et l'évolution de tes finances sur six mois."),
            perk: .history
        )
    }

    /// The exercise library of Fitness: every exercise, its sheet and the person's data on it.
    static var exerciseLibrary: PaywallContext {
        PaywallContext(
            symbol: "books.vertical.fill",
            title: tr("Toute la bibliothèque d'exercices"),
            detail: tr("\(ExerciseLibrary.all.count) exercices avec leur démonstration, leur technique, leurs alternatives et tes performances sur chacun. Tes séances et tes propres exercices restent gratuits."),
            perk: .exercises
        )
    }

    /// The progress of Fitness: the volume over the weeks, the evolution of the loads and the records.
    static var fitnessProgress: PaywallContext {
        statistics(tr("La progression est dans Premium"),
                   detail: tr("Ton volume semaine après semaine, l'évolution de tes charges et tous tes records, exercice par exercice. Tes séances restent enregistrées : tout s'affiche dès que tu passes à Premium."))
    }

    /// The detailed statistics of a mini-app.
    static func statistics(_ title: String, detail: String) -> PaywallContext {
        PaywallContext(symbol: "chart.xyaxis.line", title: title, detail: detail, perk: .history)
    }

    /// A ready-made Home Screen of the Store.
    static func setup(_ name: String, designs: [WidgetDesign]) -> PaywallContext {
        PaywallContext(
            symbol: "rectangle.3.group.fill",
            title: tr("L'accueil « \(name) »"),
            detail: tr("\(Fmt.plural(designs.count, tr("widget"), tr("widgets"))) prêts à poser d'un coup, avec leurs styles."),
            designs: designs,
            perk: .packs
        )
    }

    /// A pack of the Store.
    static func pack(_ name: String, designs: [WidgetDesign]) -> PaywallContext {
        PaywallContext(
            symbol: "bag.fill",
            title: tr("Le pack « \(name) »"),
            detail: tr("\(Fmt.plural(designs.count, tr("widget"), tr("widgets"))) assortis, à personnaliser et ajouter ensemble."),
            designs: designs,
            perk: .packs
        )
    }
}
