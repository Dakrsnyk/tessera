#if DEBUG
import Foundation

/// Development and test builds only: every Premium feature is unlocked by default so the whole
/// catalog can be tried without a purchase. The switch lives in Réglages > Développeur.
///
/// This file is compiled out of Release builds (App Store, TestFlight): there, Premium comes from
/// StoreKit alone. `scripts/check_release_safety.py` fails the CI if this type is referenced outside `#if DEBUG`.
enum DebugPremium {
    private static let key = "debugPremiumDisabled"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static var isUnlocked: Bool {
        !defaults.bool(forKey: key)
    }

    static func setUnlocked(_ unlocked: Bool) {
        defaults.set(!unlocked, forKey: key)
    }
}
#endif
