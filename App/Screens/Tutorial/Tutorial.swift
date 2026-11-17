import Observation
import SwiftUI

/// The step-by-step tour shown after the first questions (and again from Réglages › Aide): it walks
/// through the app itself, tab by tab, lighting up what each step talks about. Every step can be
/// skipped, and the tour can be left at any time.
enum TutorialStep: String, CaseIterable, Identifiable {
    // The order of the cases is the order of the tour: the path of a widget, from the app to the Home Screen
    // (the day, Créer, the Studio, Mes widgets, the Home Screen), then the Store for the ready-made ones.
    // The screenshots open « tutorial-<name> ».
    case welcome, daily, create, studio, mine, homeScreen, store, finish
    var id: String { rawValue }

    /// The tab shown behind the step.
    var tab: Router.Tab {
        switch self {
        case .welcome, .daily, .finish: .home
        case .create, .studio: .spaces
        case .store: .explore
        case .mine, .homeScreen: .mine
        }
    }

    /// What the step can light up, by preference: each entry is one part or several that are lit together (their
    /// union). The first entry that fits whole on screen wins; when none fits (or none is on screen), nothing is lit
    /// and the card sits in the middle. A part that is too tall is thus replaced by a smaller one.
    var targets: [[TutorialTarget]] {
        switch self {
        case .daily: [[.daily], [.dailyHeader, .dailyNutrition, .dailyFitness], [.dailyHeader, .dailyNutrition], [.dailyHeader]]
        case .create: [[.createSpace]]
        case .mine: [[.myWidgets]]
        case .store: [[.storeAisles]]
        case .finish: [[.profile]]
        case .welcome, .studio, .homeScreen: []
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .daily: "sun.max.fill"
        case .create: "plus.square.on.square"
        case .studio: "paintbrush.pointed.fill"
        case .store: "bag.fill"
        case .mine: "rectangle.stack.fill"
        case .homeScreen: "iphone"
        case .finish: "checkmark.seal.fill"
        }
    }

    /// Where the step is, in the app's words (the tab, or the Studio). The first name arrives here, on « Mon Quotidien »,
    /// beside the slide's icon: « Bonjour Mathys » (just « Bonjour » when it isn't known).
    func place(name: String) -> String {
        switch self {
        case .welcome, .finish: tr("Ardane")
        case .daily: name.isEmpty ? tr("Bonjour") : tr("Bonjour \(name)")
        case .create: tr("Créer")
        case .studio: tr("Studio")
        case .store: tr("Store")
        case .mine: tr("Mes widgets")
        case .homeScreen: tr("Écran d'accueil")
        }
    }

    var title: String {
        switch self {
        case .welcome: tr("Bienvenue !")
        case .daily: tr("Mon Quotidien")
        case .create: tr("Créer un widget")
        case .studio: tr("Le Studio")
        case .store: tr("Le Store")
        case .mine: tr("Mes widgets")
        case .homeScreen: tr("Sur ton écran d'accueil")
        case .finish: tr("À toi de jouer !")
        }
    }

    var message: String {
        switch self {
        case .welcome:
            tr("Ardane en une minute : tu notes ta journée dans les mini-apps, et tes widgets l'affichent sur ton écran d'accueil. Passe une étape ou quitte le tutoriel quand tu veux.")
        case .daily:
            tr("Ta journée d'un coup d'œil. Touche une carte pour ouvrir sa mini-app ; un appui long la déplace ou change sa taille.")
        case .create:
            tr("Choisis d'abord la taille, puis la catégorie, puis un ou plusieurs widgets : ils sont réunis en un seul widget. Le Studio sert ensuite à le personnaliser.")
        case .studio:
            tr("Contenu, thème, style, couleurs, fond, bordure : l'aperçu change en direct, et les flèches annulent ou rétablissent. Essaie :")
        case .store:
            tr("Pas envie de partir de zéro ? Des widgets prêts à l'emploi, des packs, des écrans d'accueil complets et des fonds d'écran. Tout s'ouvre dans le Studio pour être personnalisé.")
        case .mine:
            tr("Tous tes widgets enregistrés : modifie-les dans le Studio, duplique-les, ajoute-les à ton écran ou réunis-en plusieurs en un seul.")
        case .homeScreen:
            tr("Tes widgets t'attendent dans la galerie de widgets d'iOS :")
        case .finish:
            tr("Ton profil et les Réglages sont ici, en haut à droite : rappels, Premium, sauvegarde. Tu pourras y revoir ce tutoriel quand tu veux.")
        }
    }

    var next: TutorialStep? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}

/// Parts of the app the tour lights up. Each reports where it is on screen (`tutorialTarget`).
enum TutorialTarget: String {
    /// Mon Quotidien whole, the first size of Créer, the aisles of the Store, the widget in the middle of Mes widgets
    /// (or its empty state), the profile button.
    case daily, createSpace, storeAisles, myWidgets, profile
    /// Inside Mon Quotidien: its title row and the Nutrition and Fitness cards.
    case dailyHeader, dailyNutrition, dailyFitness
}

/// Where each lit-up part is, in window coordinates. Shared by the tabs (each in its own navigation)
/// and the overlay drawn above them all.
@Observable
final class TutorialFrames {
    static let shared = TutorialFrames()

    private(set) var frames: [TutorialTarget: CGRect] = [:]
    /// The corner radius of each part, so the outline follows the part's own corners.
    private(set) var radii: [TutorialTarget: CGFloat] = [:]
    /// Height of the card, written by the overlay, read by the scrolling (not observed).
    @ObservationIgnored var cardHeight: CGFloat = 260

    /// The part, or the union of several parts lit together; nil as long as one of them isn't on screen yet.
    func candidate(for group: [TutorialTarget]) -> TutorialLayout.Candidate? {
        guard !group.isEmpty else { return nil }
        var union: CGRect?
        var radius: CGFloat = 0
        for target in group {
            guard let frame = frames[target], !frame.isEmpty else { return nil }
            union = union.map { $0.union(frame) } ?? frame
            radius = max(radius, radii[target] ?? TutorialLayout.defaultRadius)
        }
        return union.map { TutorialLayout.Candidate(frame: $0, radius: radius) }
    }

    func update(_ target: TutorialTarget, _ frame: CGRect, radius: CGFloat = TutorialLayout.defaultRadius) {
        if radii[target] != radius { radii[target] = radius }
        if let old = frames[target], abs(old.minX - frame.minX) < 0.5, abs(old.minY - frame.minY) < 0.5,
           abs(old.width - frame.width) < 0.5, abs(old.height - frame.height) < 0.5 {
            return
        }
        frames[target] = frame
    }
}

extension View {
    /// Marks a part of the app the tutorial can light up (only while `condition` holds: the first of a list).
    /// `radius` is the part's own corner radius: the outline follows it.
    func tutorialTarget(_ target: TutorialTarget, radius: CGFloat = TutorialLayout.defaultRadius, when condition: Bool = true) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            if condition { TutorialFrames.shared.update(target, frame, radius: radius) }
        }
    }
}
