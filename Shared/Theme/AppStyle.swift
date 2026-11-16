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

    /// The twelve colors of the app: each gives an accent (light and dark) and, from its hue, the backgrounds
    /// around it, in the proportions of the former hand-made styles.
    static let all: [AppStyle] = [
        palette(.cobalt, tr("Bleu profond, net et franc"), light: "244FC1", dark: "7094FF"),
        palette(.sapphire, tr("Bleu acier, sobre et élégant"), light: "245B8F", dark: "68B5F5"),
        palette(.iceBlue, tr("Frais et lumineux"), light: "398FA8", dark: "75DDF5"),
        palette(.aqua, tr("Turquoise vif, comme l'eau claire"), light: "008C95", dark: "45DDE0"),
        palette(.jade, tr("Vert jade, l'original"), light: "268577", dark: "65D5BC"),
        palette(.pistachio, tr("Vert tendre et naturel"), light: "718C42", dark: "B8D987"),
        palette(.olive, tr("Vert doré, terreux et calme"), light: "77752B", dark: "C7C36A"),
        palette(.amber, tr("Chaud, comme un soir d'été"), light: "B86A13", dark: "FFB454"),
        palette(.ruby, tr("Rouge intense, plein de vie"), light: "C62845", dark: "FF6B81", fontDesign: .rounded),
        palette(.rose, tr("Tendre et affirmé"), light: "C04472", dark: "FF83B2", fontDesign: .rounded),
        palette(.orchid, tr("Doux et raffiné"), light: "9854B8", dark: "D5A0F5", fontDesign: .rounded),
        palette(.amethyst, tr("Violet profond, pour les couche-tard"), light: "6841A5", dark: "B69AFF"),
        palette(.sable, tr("Beige chaud, comme du papier"), light: "7B5D34", dark: "E3C08A"),
        // A neutral color: its backgrounds keep only 22 % of the hue's saturation. Deep graphite in light, near-white silver
        // in dark (PDG, 2026-11-16: the former pale grey-blue looked dull next to Saphir).
        palette(.slate, tr("Gris ardoise, sobre et net"), light: "2B323D", dark: "E6EBF2", saturation: 0.22),
    ]

    private static func palette(_ id: AppStyleID, _ tagline: String, light: String, dark: String,
                                fontDesign: Font.Design = .default, saturation: Double = 1) -> AppStyle {
        let hue = hsl(light).h
        return AppStyle(id: id, tagline: tagline, accentLight: light, accentDark: dark,
                        screenLight: hex(h: hue, s: 0.42 * saturation, l: 0.945),
                        screenDark: hex(h: hue, s: 0.45 * saturation, l: 0.055),
                        cardDark: hex(h: hue, s: 0.35 * saturation, l: 0.115),
                        // A light accent in dark mode (pastel) carries dark text, a deep one carries white.
                        inkOnDarkAccent: luminance(dark) > 0.35 ? hex(h: hue, s: 0.5 * saturation, l: 0.07) : "FFFFFF",
                        fontDesign: fontDesign)
    }

    private static func hsl(_ hex: String) -> (h: Double, s: Double, l: Double) {
        let value = UInt64(hex, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255, g = Double((value >> 8) & 0xFF) / 255, b = Double(value & 0xFF) / 255
        let high = max(r, g, b), low = min(r, g, b), l = (high + low) / 2, delta = high - low
        guard delta > 0 else { return (0, 0, l) }
        let s = delta / (1 - abs(2 * l - 1))
        var h: Double
        if high == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if high == g { h = (b - r) / delta + 2 }
        else { h = (r - g) / delta + 4 }
        h *= 60
        if h < 0 { h += 360 }
        return (h, s, l)
    }

    private static func hex(h: Double, s: Double, l: Double) -> String {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let parts: (Double, Double, Double)
        switch Int(h / 60) % 6 {
        case 0: parts = (c, x, 0)
        case 1: parts = (x, c, 0)
        case 2: parts = (0, c, x)
        case 3: parts = (0, x, c)
        case 4: parts = (x, 0, c)
        default: parts = (c, 0, x)
        }
        func byte(_ v: Double) -> Int { min(255, max(0, Int(((v + m) * 255).rounded()))) }
        return String(format: "%02X%02X%02X", byte(parts.0), byte(parts.1), byte(parts.2))
    }

    /// Relative luminance (0 black, 1 white) of an sRGB hex color.
    static func luminance(_ hex: String) -> Double {
        let value = UInt64(hex, radix: 16) ?? 0
        func linear(_ shift: UInt64) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
    }

    static func style(_ id: AppStyleID) -> AppStyle {
        all.first { $0.id == id } ?? all[0]
    }

    /// The style drawn for a saved choice: Saphir for a free plan whatever is saved.
    static func style(_ id: AppStyleID, isPremium: Bool) -> AppStyle {
        style(id.effective(isPremium: isPremium))
    }

    /// The style drawn now from the stored settings and Premium status (Live Activities, launch screen).
    static func stored() -> AppStyle {
        let store = SharedStore.shared
        return style(store.settings.appStyle, isPremium: store.premium.isPremium())
    }

    /// The saved style, used before the first view applies the settings (launch screen).
    static var current: AppStyle = stored()
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

    /// Since the « Cristal » redesign (2026-11-15) the fills come from the style's Cristal palette
    /// (`CristalPalette`). `AppStyle` itself is unchanged: Live Activities still read its fields.
    func resolve(in environment: EnvironmentValues) -> AnyShapeStyle {
        let palette = CristalPalette.of(environment.appStyle.id)
        let dark = environment.colorScheme == .dark
        switch kind {
        case .screen: return AnyShapeStyle(Color(hex: palette.hex("bg", dark: dark)))
        case .screenGradient: return AnyShapeStyle(Self.depth(palette, dark: dark))
        case .card: return AnyShapeStyle(Color(hex: palette.hex("panelSolid", dark: dark)))
        case .onAccent: return AnyShapeStyle(Color(hex: palette.hex("onPrimary", dark: dark)))
        }
    }

    /// The Cristal background on a single layer, for the places that need a shape style: the first
    /// wash tints the top, the second the bottom. Whole screens use `cristalScreen()` (the two washes
    /// at their place).
    static func depth(_ palette: CristalPalette, dark: Bool) -> LinearGradient {
        let base = palette.hex("bg", dark: dark)
        let top = mix(base, palette.hex("na", dark: dark), 0.55)
        let bottom = mix(base, palette.hex("nb", dark: dark), 0.45)
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
    func appStyle(_ settings: AppSettings, isPremium: Bool = SharedStore.shared.premium.isPremium()) -> some View {
        let style = AppStyle.style(settings.appStyle, isPremium: isPremium)
        // The action color is the Cristal one: the style's accent, darkened where needed to read on its own tint.
        let action = CristalPalette.of(style.id).primaryColor
        return self
            .environment(\.appStyle, style)
            .tint(action)
            .accentColor(action)
            .fontDesign(style.fontDesign)
            .preferredColorScheme(settings.appearance.colorScheme)
    }
}
