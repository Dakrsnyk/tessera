#if DEBUG
import Foundation

/// Test builds only (compiled out of Release): the Premium unlock switch in Réglages > Développeur.
extension AppModel {
    var isDebugPremiumOn: Bool {
        _ = premiumRevision
        return DebugPremium.isUnlocked
    }

    func setDebugPremium(_ unlocked: Bool) {
        DebugPremium.setUnlocked(unlocked)
        premiumRevision += 1
        scheduleWidgetReload()
    }
}
#endif
