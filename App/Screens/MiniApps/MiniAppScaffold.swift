import SwiftUI

/// The color of the mini-app on screen, for the pieces that borrow it (the bar before a section title).
private struct MiniAccentKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    var miniAccent: Color? {
        get { self[MiniAccentKey.self] }
        set { self[MiniAccentKey.self] = newValue }
    }
}

/// A button floating above the tab bar: the one main action of a mini-app (« Scanner », « Commencer », « Dépense »).
struct MiniFloatingAction {
    let title: String
    let symbol: String
    let colorHex: String
    /// The accessibility identifier the UI tests look for (the screen's own, not a generic one).
    var identifier: String? = nil
    let action: () -> Void
}

/// The frame of a mini-app screen in the Cristal style: a soft wash of the app's color at the top of the page
/// (behind the header: the week selector and the essential figure of the day, both on glass), then the rest on
/// panels straight on the background (the complementary content by order of importance, the settings last), and
/// the main action floating above the tab bar. Inside, the action color is the mini-app's own. Every mini-app
/// uses it, so they read the same way: selector, essential, complementary, settings.
struct MiniAppScaffold<Header: View, Sheet: View>: View {
    let colorHex: String
    var action: MiniFloatingAction?
    /// Less room between the header and the content, for a screen whose first block must sit right under the selector.
    var compact = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let sheet: () -> Sheet
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appStyle) private var style

    private var palette: CristalPalette { CristalPalette.of(style.id) }
    /// The app's color as a category, and its strong version (readable with white), which becomes the page's action color.
    private var accent: Color { palette.category(colorHex) }
    private var strong: Color { palette.strong(colorHex) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, compact ? 4 : 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .top) { wash }
                VStack(alignment: .leading, spacing: 22) {
                    sheet()
                }
                .padding(.horizontal, 20)
                .padding(.top, compact ? 18 : 26)
                .padding(.bottom, action == nil ? 40 : 130)
                .frame(maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
            }
        }
        .cristalScreen()
        .screenshotScroll()
        .tint(strong)
        .accentColor(strong)
        .overlay(alignment: .bottom) {
            if let action {
                MiniFloatingButton(action: action).padding(.bottom, 12)
            }
        }
        .environment(\.miniAccent, accent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// The color of the app as a soft radial wash, centered at the top of the screen and fading out by 380 pt.
    private var wash: some View {
        let color = accent.opacity(scheme == .dark ? 0.22 : 0.30)
        return GeometryReader { proxy in
            // The scroll content starts under the navigation bar: the wash reaches up past it (and past a pull
            // down), so that it is centered on the top edge of the screen.
            let extra: CGFloat = 400
            let radius: CGFloat = 380
            let total = extra + radius
            RadialGradient(colors: [color, color.opacity(0)], center: UnitPoint(x: 0.5, y: extra / total),
                           startRadius: 0, endRadius: radius)
                .frame(width: proxy.size.width, height: total)
                .offset(y: -extra)
                .allowsHitTesting(false)
        }
    }
}

/// The floating main action of a mini-app: a capsule in the app's strong color (readable ink: white in light mode,
/// dark on the lighter color of dark mode, chosen by contrast). A double tap runs it once.
private struct MiniFloatingButton: View {
    let action: MiniFloatingAction
    @State private var tapGuard = TapGuard()
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strong = CristalPalette.of(style.id).strongHex(action.colorHex)
        let hex = scheme == .dark ? strong.dark : strong.light
        Button {
            tapGuard.run(action.action)
        } label: {
            Label(action.title, systemImage: action.symbol)
                .font(.headline)
                .foregroundStyle(Color.readableInk(on: hex))
                .padding(.horizontal, 24)
                .frame(minHeight: 50)
                .background(Color(hex: hex), in: Capsule())
                .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(action.identifier ?? "mini-floating-action")
    }
}

/// The essential figure of a mini-app on its wash, on a glass card: a small caps label, the big figure, a line under it.
struct MiniHero: View {
    let label: String
    let value: String
    var caption: String?
    var valueSize: CGFloat = 54
    @Environment(\.appStyle) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.system(size: valueSize, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristalGlass(in: RoundedRectangle(cornerRadius: CristalPalette.of(style.id).radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
