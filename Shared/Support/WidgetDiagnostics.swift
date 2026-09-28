import Foundation

/// What the test builds show in Réglages > Développeur to explain missing widgets:
/// whether the installer kept the widget extension, and whether iOS ever launched it.
enum WidgetDiagnostics {
    static let lastLaunchKey = "widgetExtensionLastLaunch"

    static var isExtensionInstalled: Bool {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return false }
        return FileManager.default.fileExists(atPath: plugins.appendingPathComponent("TesseraWidgets.appex").path)
    }

    static var lastLaunch: Date? {
        UserDefaults(suiteName: AppGroup.identifier)?.object(forKey: lastLaunchKey) as? Date
    }

    static var lastLaunchText: String {
        guard let date = lastLaunch else { return "Jamais" }
        return Fmt.format(date, template: "dMMMHHmm")
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
