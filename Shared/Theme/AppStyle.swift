import SwiftUI

/// The colors of one app style, in light and dark. Widgets keep their own themes.
struct AppStyle: Identifiable {
    let id: AppStyleID
    let tagline: String
    let accentLight: String
    let accentDark: String
    /// Screen background (behind cards and lists).
    let screenLight: String
    let screenDark: String
    /// Cards: white in light mode, a dark tint of the style in dark mode.
    let cardDark: String
    /// Text on an accent-colored fill, when the accent is too light for white.
    var inkOnDarkAccent = "FFFFFF"
    var fontDesign: Font.Design = .default

    var name: String { id.title }
    var accent: Color { Color(light: accentLight, dark: accentDark) }
    var screen: Color { Color(light: screenLight, dark: screenDark) }
    var card: Color { Color(light: "FFFFFF", dark: cardDark) }
    var onAccent: Color { Color(light: "FFFFFF", dark: inkOnDarkAccent) }

    static let all: [AppStyle] = [
        AppStyle(id: .tessera, tagline: tr("Jade et crème, l'original"), accentLight: "2F8F7A", accentDark: "3FA58D",
                 screenLight: "F3F1EC", screenDark: "0A0F0D", cardDark: "17201D"),
        AppStyle(id: .ocean, tagline: tr("Bleu franc, net et calme"), accentLight: "2563EB", accentDark: "4F80FF",
                 screenLight: "EEF2F9", screenDark: "070B16", cardDark: "141B2B"),
        AppStyle(id: .coral, tagline: tr("Chaleureux et vivant"), accentLight: "E4533D", accentDark: "F26A55",
                 screenLight: "FBF0EC", screenDark: "110A08", cardDark: "231815", fontDesign: .rounded),
        AppStyle(id: .lavender, tagline: tr("Doux et rêveur"), accentLight: "6D4AE8", accentDark: "8B6DFF",
                 screenLight: "F2F0FA", screenDark: "0B0914", cardDark: "1A1727", fontDesign: .rounded),
        AppStyle(id: .sand, tagline: tr("Doré, comme un soir d'été"), accentLight: "A26A18", accentDark: "E3AC4F",
                 screenLight: "F6F0E5", screenDark: "0F0C07", cardDark: "221D14", inkOnDarkAccent: "1A1408"),
        AppStyle(id: .graphite, tagline: tr("Noir et blanc, sans détour"), accentLight: "1C1C1E", accentDark: "D1D1D6",
                 screenLight: "F2F2F4", screenDark: "000000", cardDark: "1C1C1E", inkOnDarkAccent: "000000"),
        AppStyle(id: .forest, tagline: tr("Vert profond et naturel"), accentLight: "2B7A4B", accentDark: "3F9A63",
                 screenLight: "EEF3EE", screenDark: "070D09", cardDark: "16201A"),
        AppStyle(id: .rose, tagline: tr("Tendre et affirmé"), accentLight: "D13F72", accentDark: "E8588B",
                 screenLight: "FBEFF3", screenDark: "12080C", cardDark: "24161C", fontDesign: .rounded),
        AppStyle(id: .midnight, tagline: tr("Indigo, pour les couche-tard"), accentLight: "4B46C8", accentDark: "7571F2",
                 screenLight: "EFEFF8", screenDark: "06061A", cardDark: "15152E"),
        AppStyle(id: .neon, tagline: tr("Cyan électrique sur fond nuit"), accentLight: "0086A8", accentDark: "22D3EE",
                 screenLight: "EDF6F8", screenDark: "04080F", cardDark: "111C24", inkOnDarkAccent: "03161C"),
    ]

    static func style(_ id: AppStyleID) -> AppStyle {
        all.first { $0.id == id } ?? all[0]
    }

    /// The saved style, used before the first view applies the settings (launch screen).
    static var current: AppStyle = style(SharedStore.shared.settings.appStyle)
}

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension AppStyle: Equatable {
    static func == (lhs: AppStyle, rhs: AppStyle) -> Bool { lhs.id == rhs.id }
}

private struct AppStyleKey: EnvironmentKey {
    static let defaultValue: AppStyle = AppStyle.current
}

extension EnvironmentValues {
    /// The app style in use. Every fill below reads it, so a new style repaints the whole app at once.
    var appStyle: AppStyle {
        get { self[AppStyleKey.self] }
        set { self[AppStyleKey.self] = newValue }
    }
}

/// The style's backgrounds, resolved where they are drawn: they follow the style and light or dark
/// mode instantly, without rebuilding any screen.
struct AppFill: ShapeStyle {
    enum Kind {
        case screen, screenGradient, card, onAccent
    }

    let kind: Kind

    func resolve(in environment: EnvironmentValues) -> AnyShapeStyle {
        let style = environment.appStyle
        let dark = environment.colorScheme == .dark
        switch kind {
        case .screen: return AnyShapeStyle(Color(hex: dark ? style.screenDark : style.screenLight))
        case .screenGradient: return AnyShapeStyle(Self.depth(style, dark: dark))
        case .card: return AnyShapeStyle(Color(hex: dark ? style.cardDark : "FFFFFF"))
        case .onAccent: return AnyShapeStyle(Color(hex: dark ? style.inkOnDarkAccent : "FFFFFF"))
        }
    }

    /// The screen color with depth. Light mode: the style's accent color tints the top, fading into
    /// the screen color, a little deeper at the bottom. Dark mode: the card color at the top, sinking
    /// towards black at the bottom.
    static func depth(_ style: AppStyle, dark: Bool) -> LinearGradient {
        let base = dark ? style.screenDark : style.screenLight
        let top = dark ? mix(base, style.cardDark, 0.75) : mix(base, style.accentLight, 0.24)
        let bottom = dark ? mix(base, "000000", 0.58) : mix(base, "000000", 0.05)
        return LinearGradient(colors: [top, Color(hex: base), bottom], startPoint: .top, endPoint: .bottom)
    }

    private static func mix(_ hex: String, _ other: String, _ amount: Double) -> Color {
        func rgb(_ hex: String) -> (Double, Double, Double) {
            let value = UInt64(hex, radix: 16) ?? 0
            return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
        }
        let (r, g, b) = rgb(hex), (r2, g2, b2) = rgb(other)
        return Color(red: r + (r2 - r) * amount, green: g + (g2 - g) * amount, blue: b + (b2 - b) * amount)
    }
}

extension ShapeStyle where Self == AppFill {
    /// Screen color, flat (small fields, bars).
    static var screenFill: AppFill { AppFill(kind: .screen) }
    /// Whole-screen background (behind cards and lists): the screen color with a subtle vertical depth.
    static var screenGradient: AppFill { AppFill(kind: .screenGradient) }
    /// Cards and list rows.
    static var cardFill: AppFill { AppFill(kind: .card) }
    /// Text and symbols drawn on an accent-colored fill.
    static var onAccent: AppFill { AppFill(kind: .onAccent) }
}

extension View {
    /// Applies the chosen style: accent, backgrounds, font and light or dark mode.
    func appStyle(_ settings: AppSettings) -> some View {
        let style = AppStyle.style(settings.appStyle)
        return self
            .environment(\.appStyle, style)
            .tint(style.accent)
            .accentColor(style.accent)
            .fontDesign(style.fontDesign)
            .preferredColorScheme(settings.appearance.colorScheme)
    }

    /// Lists and forms on the style's background instead of the system gray.
    func styledList() -> some View {
        scrollContentBackground(.hidden)
            .background(.screenGradient)
    }
}
