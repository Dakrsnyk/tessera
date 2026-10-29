import Foundation

/// Everything to fill in when the app is set up in App Store Connect.
/// Product IDs must match the ones created there (and in Config/Ardane.storekit for local testing).
enum PremiumConfiguration {
    static let monthlyID = "com.dakrsnyk.ardane.premium.monthly"
    static let yearlyID = "com.dakrsnyk.ardane.premium.yearly"
    static let lifetimeID = "com.dakrsnyk.ardane.premium.lifetime"

    static var allProductIDs: [String] { [yearlyID, monthlyID, lifetimeID] }

    /// Required by Apple on the paywall. The hosted pages of ardane.app.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://ardane.app/privacy.html")!
    static var supportEmail: String { AppInfo.supportEmail }
    /// The app's numeric App Store ID, once published (« Noter Ardane » then opens the review page).
    static let appStoreID: String? = nil
}
