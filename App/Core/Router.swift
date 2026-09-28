import Foundation
import Observation
import SwiftUI

struct EditorRequest: Identifiable {
    let id = UUID()
    var design: WidgetDesign
    var isNew: Bool
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
        case home, spaces, explore, mine, settings
    }

    var tab: Tab = .home
    var editor: EditorRequest?
    var isPaywallPresented = false
    var content: ContentScreen?
    var isAddGuidePresented = false
    /// Set when a new widget is saved, so the guide opens once the editor has closed.
    var showsAddGuideAfterEditor = false
    var lastSavedName: String?
    var exploreCategory: WidgetCategory?
    var exploreSearchRequested = false
    /// Navigation inside the Espaces tab.
    var spacePath: [Space] = []

    func openSpace(_ space: Space) {
        editor = nil
        content = nil
        tab = .spaces
        spacePath = [space]
    }

    func openEditor(_ design: WidgetDesign, isNew: Bool) {
        content = nil
        editor = EditorRequest(design: design, isNew: isNew)
    }

    func openExplore(category: WidgetCategory? = nil, search: Bool = false) {
        exploreCategory = category
        exploreSearchRequested = search
        tab = .explore
    }

    func handle(_ link: DeepLink, model: AppModel) {
        editor = nil
        isPaywallPresented = false
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
        case let .space(id):
            if let space = Space(rawValue: id) {
                openSpace(space)
            } else {
                tab = .spaces
            }
        }
    }
}
