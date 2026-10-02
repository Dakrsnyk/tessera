import Foundation

/// Everything to fill in when the app is set up in App Store Connect.
/// Product IDs must match the ones created there (and in Config/Tessera.storekit for local testing).
enum PremiumConfiguration {
    static let monthlyID = "com.dakrsnyk.tessera.premium.monthly"
    static let yearlyID = "com.dakrsnyk.tessera.premium.yearly"
    static let lifetimeID = "com.dakrsnyk.tessera.premium.lifetime"

    static var allProductIDs: [String] { [yearlyID, monthlyID, lifetimeID] }

    /// Required by Apple on the paywall. Replace with your hosted pages before submitting.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://claude.ai/artifact/M2hUyRzRz9zxoSMJ4PJ5X8")!
    static var supportEmail: String { AppInfo.supportEmail }
    /// The app's numeric App Store ID, once published (« Noter Tessera » then opens the review page).
    static let appStoreID: String? = nil
}
