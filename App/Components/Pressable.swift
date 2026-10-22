import SwiftUI

/// Feedback at the very moment of a touch: the button dims and shrinks a little while it is pressed. The
/// « plain » style shows nothing, so a tap on a card or a row felt dead until the next screen came. With
/// « Reduce Motion » only the dimming stays.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration)
    }

    private struct PressedLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.78 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// `.buttonStyle(.pressable)`: like « plain » (no tint, no chrome) with a visible press.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Ignores a second call that comes too soon after the first: a double tap on a button that adds, saves or
/// moves something runs the action once. Kept in the view's `@State`.
@MainActor
final class TapGuard {
    private var last: Date?

    /// Runs `action` unless the last run was less than `interval` seconds before `now`. True when it ran.
    @discardableResult
    func run(at now: Date = Date(), within interval: TimeInterval = 0.5, _ action: () -> Void) -> Bool {
        if let last, now.timeIntervalSince(last) < interval { return false }
        last = now
        action()
        return true
    }
}
