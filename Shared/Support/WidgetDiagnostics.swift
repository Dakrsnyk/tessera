import Foundation
import UIKit

/// What the test builds show in Réglages > Développeur to explain missing widgets:
/// whether the installer kept the widget extension, and whether iOS ever launched it.
enum WidgetDiagnostics {
    static let lastLaunchKey = "widgetExtensionLastLaunch"
    /// Named pasteboards are shared by the app and its extensions even without an App Group.
    static let pasteboardName = UIPasteboard.Name("com.dakrsnyk.tessera.diagnostics")

    /// Called by the widget extension each time iOS starts it.
    static func recordLaunch() {
        UserDefaults(suiteName: AppGroup.identifier)?.set(Date(), forKey: lastLaunchKey)
        #if DEBUG
        let groups = SignedEntitlements.appGroups.joined(separator: ", ")
        UIPasteboard(name: pasteboardName, create: true)?.string = "\(Date().timeIntervalSince1970)|\(groups)"
        #endif
    }

    /// What the extension left on the diagnostics pasteboard: when it ran, and its signed App Groups.
    static var pasteboardLaunch: (date: Date, groups: String)? {
        guard let text = UIPasteboard(name: pasteboardName, create: false)?.string else { return nil }
        let parts = text.split(separator: "|", omittingEmptySubsequences: false)
        guard let first = parts.first, let seconds = Double(first) else { return nil }
        return (Date(timeIntervalSince1970: seconds), parts.count > 1 ? String(parts[1]) : "")
    }

    static var isExtensionInstalled: Bool {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return false }
        return FileManager.default.fileExists(atPath: plugins.appendingPathComponent("TesseraWidgets.appex").path)
    }

    static var lastLaunch: Date? {
        UserDefaults(suiteName: AppGroup.identifier)?.object(forKey: lastLaunchKey) as? Date
    }

    static var lastLaunchText: String {
        if AppGroup.isShared, let date = lastLaunch {
            return Fmt.format(date, template: "dMMMHHmm")
        }
        if let launch = pasteboardLaunch {
            let groups = launch.groups.isEmpty ? "aucun groupe" : launch.groups
            return "\(Fmt.format(launch.date, template: "dMMMHHmm")) (\(groups))"
        }
        return "Jamais"
    }

    /// App Groups in the code signature, then in the provisioning profile.
    static var groupsText: String {
        var signed: [String] = []
        #if DEBUG
        signed = SignedEntitlements.appGroups
        #endif
        let profile = ProvisioningProfile.appGroups()
        let hasProfile = ProvisioningProfile.entitlements() != nil
        return "signature : \(signed.isEmpty ? "aucun" : signed.joined(separator: ", ")) · profil : \(hasProfile ? (profile.isEmpty ? "aucun" : profile.joined(separator: ", ")) : "absent")"
    }

    static var sharedSpaceText: String {
        guard AppGroup.isShared else {
            return ProvisioningProfile.appGroups().isEmpty ? "Inactif (aucun groupe)" : "Inactif"
        }
        return AppGroup.identifier == AppGroup.declaredIdentifier ? "Actif" : "Actif (groupe de l'installation)"
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
