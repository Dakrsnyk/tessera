import SwiftUI
import UIKit

/// The icons Tessera can take on the Home Screen: « Classique » by default, the glass ones picked in
/// « Icône de l'app » (Profil, or a long press on the icon, then « Changer d'icône »).
/// Each one is an icon set of the asset catalog, built as an alternate icon, with its picture
/// `IconPreview-<asset>`. They stay light in Dark Mode. They are drawn by scripts/app_icons.js.
struct AppIconChoice: Identifiable, Hashable {
    /// The icon set; « AppIcon » is the main icon.
    let asset: String
    let title: String

    var id: String { asset }
    /// What `setAlternateIconName` takes: nil for the main icon.
    var alternateName: String? { asset == Self.main ? nil : asset }
    var preview: String { "IconPreview-\(asset)" }

    static let main = "AppIcon"

    static let all: [AppIconChoice] = [
        AppIconChoice(asset: main, title: tr("Classique")),
        AppIconChoice(asset: "AppIcon-RedGlass", title: tr("Verre rouge")),
        AppIconChoice(asset: "AppIcon-Jade", title: tr("Verre jade")),
        AppIconChoice(asset: "AppIcon-Night", title: tr("Verre nuit")),
        AppIconChoice(asset: "AppIcon-Blue", title: tr("Verre bleu")),
        AppIconChoice(asset: "AppIcon-Ocean", title: tr("Verre océan")),
        AppIconChoice(asset: "AppIcon-Coral", title: tr("Verre corail")),
        AppIconChoice(asset: "AppIcon-Emerald", title: tr("Verre émeraude")),
        AppIconChoice(asset: "AppIcon-Amethyst", title: tr("Verre améthyste")),
        AppIconChoice(asset: "AppIcon-Amber", title: tr("Verre ambre")),
        AppIconChoice(asset: "AppIcon-Lagoon", title: tr("Verre lagon")),
        AppIconChoice(asset: "AppIcon-Raspberry", title: tr("Verre framboise")),
        AppIconChoice(asset: "AppIcon-Midnight", title: tr("Verre minuit")),
        AppIconChoice(asset: "AppIcon-Aurora", title: tr("Aurore boréale")),
        AppIconChoice(asset: "AppIcon-Sakura", title: tr("Verre sakura")),
        AppIconChoice(asset: "AppIcon-Forest", title: tr("Verre forêt")),
        AppIconChoice(asset: "AppIcon-Graphite", title: tr("Verre graphite")),
    ]
}

@MainActor
enum AppIconSwitcher {
    /// The icon set on the Home Screen now.
    static var current: String { UIApplication.shared.alternateIconName ?? AppIconChoice.main }

    /// Puts the icon on the Home Screen (iOS confirms it with its own message). False if it failed.
    static func apply(_ choice: AppIconChoice) async -> Bool {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else { return false }
        guard app.alternateIconName != choice.alternateName else { return true }
        do {
            try await app.setAlternateIconName(choice.alternateName)
            return true
        } catch {
            return false
        }
    }
}

/// The menu shown by a long press on Tessera's icon: « Changer d'icône ».
@MainActor
@Observable
final class QuickActions {
    static let shared = QuickActions()
    static let changeIcon = "com.dakrsnyk.tessera.change-icon"

    /// The action picked from the menu, waiting for the app to show it.
    var pending: String?

    /// Puts the actions in the menu (iOS keeps them until the next call).
    static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: changeIcon,
                localizedTitle: tr("Changer d'icône"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "app.badge"),
                userInfo: nil
            ),
        ]
    }
}

/// Receives the menu's action when it launches the app…
@MainActor
final class TesseraAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            QuickActions.shared.pending = item.type
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = TesseraSceneDelegate.self
        return configuration
    }
}

/// …and when the app was already open in the background.
@MainActor
final class TesseraSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        QuickActions.shared.pending = shortcutItem.type
        completionHandler(true)
    }
}
