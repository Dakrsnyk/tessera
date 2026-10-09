import Foundation
import Observation
import SwiftUI

struct EditorRequest: Identifiable {
    let id = UUID()
    /// The widgets edited together (several when a creation or a pack makes several at once).
    var designs: [WidgetDesign]
    var isNew: Bool
    /// The Studio section to open on (a `StudioSection` raw value), the content by default.
    var section: String? = nil

    init(design: WidgetDesign, isNew: Bool, section: String? = nil) {
        self.init(designs: [design], isNew: isNew, section: section)
    }

    init(designs: [WidgetDesign], isNew: Bool, section: String? = nil) {
        self.designs = designs
        self.isNew = isNew
        self.section = section
    }

    /// The first widget (a blank note if the list is empty, which a caller should never ask for).
    var design: WidgetDesign { designs.first ?? WidgetDesign.starter(for: .note) }
}

/// Pages of the Store, pushed from its sections.
enum StorePage: Hashable {
    case setups, combos, packs, collections
    case collection(String)
}

enum ContentScreen: String, Identifiable {
    case tasks, habits, hydration, money, weather, calendar
    var id: String { rawValue }
}

/// Navigation state: tabs, sheets and what a deep link should open.
@MainActor
@Observable
final class Router {
    enum Tab: Hashable {
        case home, spaces, explore, mine
    }

    var tab: Tab = .home
    var editor: EditorRequest?
    var isPaywallPresented = false
    var content: ContentScreen?
    var isAddGuidePresented = false
    /// The food scanner, opened from a Nutrition widget.
    var isFoodScanPresented = false
    /// The profile page (with every setting), opened from the Home tab.
    var isProfilePresented = false
    /// « Icône de l'app », opened by a long press on the icon (« Changer d'icône »).
    var isIconPickerPresented = false
    /// Widgets just created in a space, flying to « Mes widgets ».
    var saveFlight: SaveFlight?
    /// Test captures: a space creator to open, and Mes widgets in selection mode.
    var requestedCreator: Space?
    var startsSelection = false
    var startsFusion = false
    /// Créer opened on its « Écran verrouillé » category.
    var showsLockScreenCreator = false
    /// Set when a new widget is saved, so the guide opens once the editor has closed.
    var showsAddGuideAfterEditor = false
    var lastSavedName: String?
    var exploreCategory: WidgetCategory?
    var exploreSearchRequested = false
    /// Store: the pages pushed on top of it, and a setup to open (used by test captures).
    var storePath: [StorePage] = []
    var openedSetupID: String?
    /// Test captures: a pack to open in the Store, and its step-by-step setup.
    var openedPackID: String?
    var startsPackSetup = false
    /// Pages pushed on Home (« Mon Quotidien » and « Mes informations »).
    var homePath: [HomeRoute] = []
    /// Navigation inside the Espaces tab.
    var spacePath: [Space] = []
    /// The tutorial step on screen (after the first questions, or from Réglages › Aide).
    var tutorialStep: TutorialStep?

    /// Starts the tutorial from the beginning, on Home, with nothing open over it.
    func startTutorial() {
        editor = nil
        content = nil
        isPaywallPresented = false
        isProfilePresented = false
        isAddGuidePresented = false
        homePath = []
        spacePath = []
        storePath = []
        tab = .home
        tutorialStep = .welcome
    }

    func openSpace(_ space: Space) {
        editor = nil
        content = nil
        tab = .spaces
        spacePath = [space]
    }

    /// Opens a mini-app on Home, over « Mon Quotidien », with an optional page on top.
    func openApp(_ app: MiniApp, page: MiniAppPage? = nil) {
        editor = nil
        content = nil
        tab = .home
        var path: [HomeRoute] = [.app(app)]
        if let page { path.append(.page(page)) }
        homePath = path
    }

    func openEditor(_ design: WidgetDesign, isNew: Bool, section: String? = nil) {
        content = nil
        editor = EditorRequest(design: design, isNew: isNew, section: section)
    }

    func openExplore(category: WidgetCategory? = nil, search: Bool = false) {
        exploreCategory = category
        exploreSearchRequested = search
        tab = .explore
    }

    func handle(_ link: DeepLink, model: AppModel) {
        editor = nil
        isPaywallPresented = false
        isProfilePresented = false
        isFoodScanPresented = false
        content = nil
        switch link {
        case let .design(id):
            if let design = model.design(id: id) {
                openEditor(design, isNew: false)
            } else {
                tab = .mine
            }
        case .premium:
            isPaywallPresented = true
        case .tasks: content = .tasks
        case .habits: content = .habits
        case .hydration: content = .hydration
        case .money: content = .money
        case .weatherLocation: content = .weather
        case .calendarAccess: content = .calendar
        case .explore, .store: tab = .explore
        case .scanFood: isFoodScanPresented = true
        case let .space(id):
            if let space = Space(rawValue: id), let app = MiniApp(space: space), app.isBuilt {
                // A widget opens its mini-app: the loop widget → iPhone → mini-app.
                openApp(app)
            } else if let space = Space(rawValue: id) {
                openSpace(space)
            } else {
                tab = .spaces
            }
        }
    }
}
