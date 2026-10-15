import AppIntents
import Foundation
import Observation

/// Opens Ardane on the barcode scanner, from the « Scanner un aliment » control (iOS 18: Control Center,
/// the Lock Screen's buttons, the Action button). iOS opens the app only for an intent compiled in the app
/// and in the widget extension, as everything in Shared/ is: it brings the app forward (after Face ID on
/// the Lock Screen) and runs `perform()` there. Custom URL schemes can't be opened from a control
/// (`OpenURLIntent` takes universal links only), so the app reads `AppOpenRequests`.
struct OpenFoodScannerIntent: OpenIntent {
    static var title: LocalizedStringResource = "Scanner un aliment"
    static var isDiscoverable = false

    @Parameter(title: "Écran", default: .foodScanner)
    var target: ArdaneScreen

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        AppOpenRequests.shared.pending = target.link
        return .result()
    }
}

/// The screens an intent can open the app on.
enum ArdaneScreen: String, AppEnum {
    case foodScanner

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Écran")
    static var caseDisplayRepresentations: [ArdaneScreen: DisplayRepresentation] = [
        .foodScanner: DisplayRepresentation(title: "Scanner un aliment"),
    ]

    var link: DeepLink {
        switch self {
        case .foodScanner: .scanFood
        }
    }
}

/// A screen asked for by an intent run in the app's process. The app shows it (`Router.handle`) and
/// clears it; observed from launch, so a request made while the app starts isn't lost.
@MainActor
@Observable
final class AppOpenRequests {
    static let shared = AppOpenRequests()

    var pending: DeepLink?
}
