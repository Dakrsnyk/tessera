import Observation
import SwiftUI

/// The step-by-step tour shown after the first questions (and again from Réglages › Aide): it walks
/// through the app itself, tab by tab, lighting up what each step talks about. Every step can be
/// skipped, and the tour can be left at any time.
enum TutorialStep: String, CaseIterable, Identifiable {
    case welcome, daily, miniApps, info, create, studio, store, mine, homeScreen, finish
    var id: String { rawValue }

    /// The tab shown behind the step.
    var tab: Router.Tab {
        switch self {
        case .welcome, .daily, .miniApps, .info, .finish: .home
        case .create, .studio: .spaces
        case .store: .explore
        case .mine, .homeScreen: .mine
        }
    }

    /// What the step lights up on screen, if anything.
    var target: TutorialTarget? {
        switch self {
        case .daily: .daily
        case .miniApps: .miniApps
        case .info: .info
        case .create: .createSpace
        case .store: .storeHero
        case .mine: .myWidgets
        case .finish: .profile
        case .welcome, .studio, .homeScreen: nil
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .daily: "sun.max.fill"
        case .miniApps: "square.grid.2x2.fill"
        case .info: "person.text.rectangle.fill"
        case .create: "plus.square.on.square"
        case .studio: "paintbrush.pointed.fill"
        case .store: "bag.fill"
        case .mine: "rectangle.stack.fill"
        case .homeScreen: "iphone"
        case .finish: "checkmark.seal.fill"
        }
    }

    /// Where the step is, in the app's words (the tab, or the Studio).
    var place: String {
        switch self {
        case .welcome, .finish: "Tessera"
        case .daily, .miniApps, .info: "Accueil"
        case .create: "Créer"
        case .studio: "Studio"
        case .store: "Store"
        case .mine: "Mes widgets"
        case .homeScreen: "Écran d'accueil"
        }
    }

    func title(name: String) -> String {
        switch self {
        case .welcome: name.isEmpty ? "Bienvenue !" : "Bienvenue, \(name) !"
        case .daily: "Mon Quotidien"
        case .miniApps: "Tes mini-apps"
        case .info: "Mes informations"
        case .create: "Créer un widget"
        case .studio: "Le Studio"
        case .store: "Le Store"
        case .mine: "Mes widgets"
        case .homeScreen: "Sur ton écran d'accueil"
        case .finish: "À toi de jouer !"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            "Petit tour de Tessera en quelques étapes : ta journée, tes mini-apps, la création de widgets et le Studio. Passe une étape quand tu veux, ou quitte le tutoriel."
        case .daily:
            "Ta journée en un coup d'œil : météo, agenda, rappels et chiffres du jour, tirés de tes données. Touche un élément pour l'ouvrir."
        case .miniApps:
            "Nutrition, Fitness, Planning, Finances, Voyage… Chaque carte ouvre une app complète, et tes widgets affichent ce que tu y notes."
        case .info:
            "Tes réponses du début, modifiables à tout moment. Données une fois, elles servent à toutes tes mini-apps et à tous tes widgets."
        case .create:
            "Choisis un univers, la taille et tes widgets, puis « Personnaliser » les ouvre dans le Studio."
        case .studio:
            "Thème, style, couleur principale, palettes, fond, bordure : l'aperçu change en direct, et les flèches annulent ou rétablissent. Essaie :"
        case .store:
            "Des widgets prêts à l'emploi, des packs et des écrans d'accueil complets. Tout s'ouvre dans le Studio pour être personnalisé."
        case .mine:
            "Tous tes widgets enregistrés : modifie-les dans le Studio, duplique-les ou réunis-en plusieurs en un seul."
        case .homeScreen:
            "Tes widgets t'attendent dans la galerie de widgets d'iOS :"
        case .finish:
            "Ton profil et les Réglages sont ici, en haut à droite. Tu pourras y revoir ce tutoriel quand tu veux."
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
    case daily, miniApps, info, createSpace, storeHero, myWidgets, profile
}

/// Where each lit-up part is, in window coordinates. Shared by the tabs (each in its own navigation)
/// and the overlay drawn above them all.
@Observable
final class TutorialFrames {
    static let shared = TutorialFrames()

    private(set) var frames: [TutorialTarget: CGRect] = [:]

    func update(_ target: TutorialTarget, _ frame: CGRect) {
        if let old = frames[target], abs(old.minX - frame.minX) < 0.5, abs(old.minY - frame.minY) < 0.5,
           abs(old.width - frame.width) < 0.5, abs(old.height - frame.height) < 0.5 {
            return
        }
        frames[target] = frame
    }
}

extension View {
    /// Marks a part of the app the tutorial can light up (only while `condition` holds: the first of a list).
    func tutorialTarget(_ target: TutorialTarget, when condition: Bool = true) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            if condition { TutorialFrames.shared.update(target, frame) }
        }
    }
}
