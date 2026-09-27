import SwiftUI

enum ThemeID: String, Codable, CaseIterable, Identifiable {
    case minimal, light, dark, monochrome
    case glass, aurora, elegant, digital, retro, futuristic, typography, colorful
    var id: String { rawValue }
}

/// A color that is either fixed, follows light/dark mode, or comes from the design's accent.
enum ThemeColor {
    case fixed(String, Double = 1)
    case adaptive(light: String, dark: String)
    case accent

    func resolve(accent: String) -> Color {
        switch self {
        case let .fixed(hex, opacity): Color(hex: hex).opacity(opacity)
        case let .adaptive(light, dark): Color(light: light, dark: dark)
        case .accent: Color(hex: accent)
        }
    }
}

enum ThemeBackground {
    case solid(ThemeColor)
    case gradient([String])
    case accentFill
}

struct WidgetTheme: Identifiable {
    let id: ThemeID
    let name: String
    let tagline: String
    let isPremium: Bool
    let background: ThemeBackground
    let primary: ThemeColor
    let secondary: ThemeColor
    /// Color used for rings, bars and highlights.
    let tint: ThemeColor
    /// Fill for inner surfaces (list rows, chips).
    let panel: ThemeColor
    let fontDesign: Font.Design
    let numberWeight: Font.Weight
    let titleWeight: Font.Weight
    let uppercaseLabels: Bool
    /// Whether text sits on a fixed dark background (used to pick status colors).
    let isDarkSurface: Bool?
}

enum ThemeCatalog {
    static let all: [WidgetTheme] = [
        WidgetTheme(
            id: .minimal, name: "Minimal", tagline: "Suit le mode clair ou sombre", isPremium: false,
            background: .solid(.adaptive(light: "FFFFFF", dark: "1C1C1E")),
            primary: .adaptive(light: "111114", dark: "F5F5F7"),
            secondary: .adaptive(light: "8A8A8E", dark: "98989F"),
            tint: .accent, panel: .adaptive(light: "F2F2F4", dark: "2A2A2D"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: nil
        ),
        WidgetTheme(
            id: .light, name: "Clair", tagline: "Toujours lumineux", isPremium: false,
            background: .solid(.fixed("F5F5F2")),
            primary: .fixed("16171A"), secondary: .fixed("7C7D82"),
            tint: .accent, panel: .fixed("E9E9E4"),
            fontDesign: .default, numberWeight: .medium, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: false
        ),
        WidgetTheme(
            id: .dark, name: "Sombre", tagline: "Toujours sombre", isPremium: false,
            background: .solid(.fixed("101114")),
            primary: .fixed("F2F2F4"), secondary: .fixed("8B8D93"),
            tint: .accent, panel: .fixed("1E2024"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .monochrome, name: "Monochrome", tagline: "Noir, blanc, rien d'autre", isPremium: false,
            background: .solid(.fixed("000000")),
            primary: .fixed("FFFFFF"), secondary: .fixed("7A7A7A"),
            tint: .fixed("FFFFFF"), panel: .fixed("1A1A1A"),
            fontDesign: .default, numberWeight: .light, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .glass, name: "Verre", tagline: "Translucide et lumineux", isPremium: true,
            background: .gradient(["6A85E0", "9C7FD6", "D98FB6"]),
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.74),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.18),
            fontDesign: .rounded, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: true
        ),
        WidgetTheme(
            id: .aurora, name: "Aurore", tagline: "Un dégradé bleu nuit vers turquoise", isPremium: true,
            background: .gradient(["1C2566", "2A6F9B", "3FB5A3"]),
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.72),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.14),
            fontDesign: .default, numberWeight: .bold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .elegant, name: "Élégant", tagline: "Serif et reflets dorés", isPremium: true,
            background: .solid(.fixed("13203A")),
            primary: .fixed("F3EBDD"), secondary: .fixed("B3A792"),
            tint: .fixed("C8A15A"), panel: .fixed("1D2B48"),
            fontDesign: .serif, numberWeight: .regular, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .digital, name: "Digital", tagline: "Écran à cristaux liquides", isPremium: true,
            background: .solid(.fixed("0A0F0B")),
            primary: .fixed("7CFFA0"), secondary: .fixed("3C8A54"),
            tint: .fixed("7CFFA0"), panel: .fixed("122017"),
            fontDesign: .monospaced, numberWeight: .medium, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .retro, name: "Rétro", tagline: "Papier chaud et typo ronde", isPremium: true,
            background: .solid(.fixed("F1E4C8")),
            primary: .fixed("2A1E14"), secondary: .fixed("8A6F55"),
            tint: .fixed("D4532A"), panel: .fixed("E6D5B1"),
            fontDesign: .rounded, numberWeight: .heavy, titleWeight: .bold,
            uppercaseLabels: true, isDarkSurface: false
        ),
        WidgetTheme(
            id: .futuristic, name: "Futuriste", tagline: "Néon cyan sur nuit profonde", isPremium: true,
            background: .gradient(["070B1F", "171046"]),
            primary: .fixed("E8F0FF"), secondary: .fixed("7F8BB5"),
            tint: .fixed("00E0FF"), panel: .fixed("00E0FF", 0.09),
            fontDesign: .monospaced, numberWeight: .light, titleWeight: .regular,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .typography, name: "Typo", tagline: "De grands chiffres, en serif", isPremium: true,
            background: .solid(.adaptive(light: "FFFFFF", dark: "0E0E10")),
            primary: .adaptive(light: "0E0E10", dark: "FAFAFA"),
            secondary: .adaptive(light: "85858A", dark: "8E8E93"),
            tint: .accent, panel: .adaptive(light: "F1F1F1", dark: "1D1D20"),
            fontDesign: .serif, numberWeight: .black, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: nil
        ),
        WidgetTheme(
            id: .colorful, name: "Couleur", tagline: "Ta couleur en plein fond", isPremium: true,
            background: .accentFill,
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.78),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.2),
            fontDesign: .rounded, numberWeight: .bold, titleWeight: .bold,
            uppercaseLabels: false, isDarkSurface: true
        ),
    ]

    static func theme(_ id: ThemeID) -> WidgetTheme {
        all.first { $0.id == id } ?? all[0]
    }

    static var free: [WidgetTheme] { all.filter { !$0.isPremium } }
}

/// Every color and font a widget view needs, resolved once from a design.
struct ResolvedStyle {
    var primary: Color
    var secondary: Color
    var accent: Color
    var track: Color
    var panel: Color
    var positive: Color
    var negative: Color
    var fontDesign: Font.Design
    var numberWeight: Font.Weight
    var titleWeight: Font.Weight
    var uppercaseLabels: Bool
    var alignment: ContentAlignment
    var showsTitle: Bool
    var showsDetails: Bool
    /// Text color readable on top of `accent`.
    var onAccent: Color
    /// Multicolor SF Symbols (weather) only look right on neutral backgrounds.
    var prefersMulticolorSymbols: Bool

    init(design: WidgetDesign) {
        let theme = design.theme
        let accentHex = design.accentHex
        var primary = theme.primary.resolve(accent: accentHex)
        var secondary = theme.secondary.resolve(accent: accentHex)
        var tint = theme.tint.resolve(accent: accentHex)
        var panel = theme.panel.resolve(accent: accentHex)
        var darkSurface = theme.isDarkSurface
        var tintHex: String? = {
            switch theme.tint {
            case let .fixed(hex, _): return hex
            case .accent: return accentHex
            case .adaptive: return nil
            }
        }()
        var neutral = [ThemeID.minimal, .light, .dark, .typography].contains(theme.id)

        // Themes filled with the accent must keep readable text on light accents.
        if case .accentFill = theme.background, ColorMath.isLight(accentHex) {
            primary = Color(hex: "16171A")
            secondary = Color(hex: "16171A").opacity(0.7)
            tint = primary
            tintHex = "16171A"
            panel = Color.black.opacity(0.08)
            darkSurface = false
        }

        switch design.background {
        case .theme:
            break
        case let .color(hex):
            let light = ColorMath.isLight(hex)
            primary = Color(hex: light ? "16171A" : "FFFFFF")
            secondary = light ? Color(hex: "16171A").opacity(0.6) : Color.white.opacity(0.7)
            panel = light ? Color.black.opacity(0.06) : Color.white.opacity(0.12)
            if case .fixed = theme.tint {} else {
                tint = Color(hex: accentHex)
                tintHex = accentHex
            }
            darkSurface = !light
            neutral = false
        case .gradient, .photo:
            primary = .white
            secondary = Color.white.opacity(0.75)
            tint = .white
            tintHex = "FFFFFF"
            panel = Color.white.opacity(0.16)
            darkSurface = true
            neutral = false
        }

        self.primary = primary
        self.secondary = secondary
        self.accent = tint
        self.track = secondary.opacity(0.25)
        self.panel = panel
        let onDark = darkSurface ?? false
        self.positive = onDark ? Color(hex: "5BD68A") : Color(hex: "1E9E57")
        self.negative = onDark ? Color(hex: "FF7A7A") : Color(hex: "D6364B")
        switch design.font {
        case .theme: self.fontDesign = theme.fontDesign
        case .standard: self.fontDesign = .default
        case .rounded: self.fontDesign = .rounded
        case .serif: self.fontDesign = .serif
        case .mono: self.fontDesign = .monospaced
        }
        self.numberWeight = theme.numberWeight
        self.titleWeight = theme.titleWeight
        self.uppercaseLabels = theme.uppercaseLabels
        self.alignment = design.alignment
        self.showsTitle = design.showsTitle
        self.showsDetails = design.showsDetails
        self.onAccent = (tintHex.map(ColorMath.isLight) ?? false) ? Color(hex: "16171A") : .white
        self.prefersMulticolorSymbols = neutral
    }

    func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: fontDesign)
    }

    func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: numberWeight, design: fontDesign).monospacedDigit()
    }

    var horizontalAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    var textAlignment: TextAlignment { alignment == .center ? .center : .leading }
    var frameAlignment: Alignment { alignment == .center ? .center : .leading }
}

/// Paints the background of a design: theme, flat color, accent gradient or photo.
struct DesignBackground: View {
    let design: WidgetDesign

    var body: some View {
        switch design.background {
        case .theme:
            themeBackground
        case let .color(hex):
            Color(hex: hex)
        case .gradient:
            LinearGradient(
                colors: [Color(hex: ColorMath.shade(design.accentHex, 0.18)), Color(hex: ColorMath.shade(design.accentHex, -0.45))],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case let .photo(name):
            if let image = ImageStore.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.28))
            } else {
                themeBackground
            }
        }
    }

    @ViewBuilder private var themeBackground: some View {
        switch design.theme.background {
        case let .solid(color):
            color.resolve(accent: design.accentHex)
        case let .gradient(hexes):
            LinearGradient(colors: hexes.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .accentFill:
            LinearGradient(
                colors: [Color(hex: design.accentHex), Color(hex: ColorMath.shade(design.accentHex, -0.12))],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
