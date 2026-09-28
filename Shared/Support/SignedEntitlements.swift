#if DEBUG
import Foundation

// Test builds only: reads the entitlements of the running app or extension from its code signature,
// to find the App Group a sideloading tool actually granted (it may rename it, e.g. with a Team ID
// prefix). SecTask is private on iOS, so it never ships in the App Store build.

@_silgen_name("SecTaskCreateFromSelf")
private func secTaskCreateFromSelf(_ allocator: CFAllocator?) -> AnyObject?

@_silgen_name("SecTaskCopyValueForEntitlement")
private func secTaskCopyValueForEntitlement(_ task: AnyObject, _ entitlement: CFString, _ error: UnsafeMutableRawPointer?) -> AnyObject?

enum SignedEntitlements {
    static func value(_ key: String) -> Any? {
        guard let task = secTaskCreateFromSelf(nil) else { return nil }
        return secTaskCopyValueForEntitlement(task, key as CFString, nil)
    }

    static var appGroups: [String] {
        value("com.apple.security.application-groups") as? [String] ?? []
    }
}
#endif
