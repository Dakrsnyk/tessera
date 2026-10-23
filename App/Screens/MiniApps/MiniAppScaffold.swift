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

/// The frame of a mini-app screen in the « Signature » style: a band of the app's color behind the header (the
/// week selector and the essential figure of the day), then a calm sheet with the rest (the complementary
/// content by order of importance, the settings last), and the main action floating above the tab bar. Every
/// mini-app uses it, so they read the same way: selector, essential, complementary, settings.
struct MiniAppScaffold<Header: View, Sheet: View>: View {
    let colorHex: String
    var action: MiniFloatingAction?
    /// Less room between the header and the sheet, for a screen whose first block must sit right under the selector.
    var compact = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let sheet: () -> Sheet
    @Environment(\.colorScheme) private var scheme

    private var accent: Color { Color(hex: colorHex) }

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
                .background(alignment: .top) { band }
                VStack(alignment: .leading, spacing: 22) {
                    sheet()
                }
                .padding(.horizontal, 20)
                .padding(.top, compact ? 18 : 26)
                .padding(.bottom, action == nil ? 40 : 130)
                .frame(maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
                .background(alignment: .top) { sheetShape }
                .overlay(alignment: .top) {
                    Capsule().fill(Color.primary.opacity(0.15)).frame(width: 38, height: 4).padding(.top, 8)
                }
            }
        }
        .background(.screenGradient)
        .screenshotScroll()
        .overlay(alignment: .bottom) {
            if let action {
                MiniFloatingButton(action: action).padding(.bottom, 12)
            }
        }
        .environment(\.miniAccent, accent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// The color of the app, fading into the sheet: stronger on a dark screen than on a light one.
    private var band: some View {
        let colors: [Color] = scheme == .dark
            ? [accent.opacity(0.55), accent.opacity(0.22), Color.clear]
            : [accent.opacity(0.34), accent.opacity(0.12), Color.clear]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .top)
    }

    private var sheetShape: some View {
        UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
            .fill(scheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.65))
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.1), radius: 14, y: -6)
    }
}

/// The floating main action of a mini-app: a capsule in the app's color. A double tap runs it once.
private struct MiniFloatingButton: View {
    let action: MiniFloatingAction
    @State private var tapGuard = TapGuard()

    var body: some View {
        Button {
            tapGuard.run(action.action)
        } label: {
            Label(action.title, systemImage: action.symbol)
                .font(.headline)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 24)
                .frame(minHeight: 50)
                .background(Color(hex: action.colorHex), in: Capsule())
                .shadow(color: Color(hex: action.colorHex).opacity(0.45), radius: 12, y: 6)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(action.identifier ?? "mini-floating-action")
    }
}

/// The essential figure of a mini-app on its band: a small caps label, the big figure, a line under it. The
/// text takes the screen's own color (white on a dark screen), so it reads on the band.
struct MiniHero: View {
    let label: String
    let value: String
    var caption: String?
    var valueSize: CGFloat = 54

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1)
                .opacity(0.75)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
