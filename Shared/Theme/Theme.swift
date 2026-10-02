import SwiftUI

enum ThemeID: String, Codable, CaseIterable, Identifiable {
    case minimal, light, dark, monochrome
    case glass, aurora, elegant, digital, retro, futuristic, typography, colorful
    // Widget Studio styles: each one also sets a composition (layout, shapes, border, depth, texture…).
    case modern, card, soft, compact
    case liquidGlass, premium, gradient, neon, editorial, magazine, dashboard, bold, data, luxury, sport, business
    case terminal, blueprint, pastel, paper, brutalist, carbon, vapor, chalk, mist
    var id: String { rawValue }
}

/// A color that is either fixed, follows light/dark mode, or comes from the design's accent.
enum ThemeColor {
    case fixed(String, Double = 1)
    case adaptive(light: String, dark: String)
    case accent
    /// The accent, see-through.
    case accentFaded(Double)

    func resolve(accent: String) -> Color {
        switch self {
        case let .fixed(hex, opacity): Color(hex: hex).opacity(opacity)
        case let .adaptive(light, dark): Color(light: light, dark: dark)
        case .accent: Color(hex: accent)
        case let .accentFaded(opacity): Color(hex: accent).opacity(opacity)
        }
    }

    /// The color, repainted in the hue of `recolor` when the main color tints the whole style.
    func resolve(accent: String, recolor: String?, surface: Bool = false) -> Color {
        guard let recolor else { return resolve(accent: accent) }
        switch self {
        case let .fixed(hex, opacity):
            return Color(hex: ColorMath.recolor(hex, to: recolor, surface: surface)).opacity(opacity)
        case let .adaptive(light, dark):
            return Color(light: ColorMath.recolor(light, to: recolor, surface: surface), dark: ColorMath.recolor(dark, to: recolor, surface: surface))
        case .accent, .accentFaded:
            return resolve(accent: accent)
        }
    }

    /// Whether the color is a gray, a white or a black (which a main color only tints).
    var isNeutral: Bool {
        switch self {
        case let .fixed(hex, _): ColorMath.hsl(hex).s < 0.14
        case let .adaptive(light, _): ColorMath.hsl(light).s < 0.14
        case .accent, .accentFaded: false
        }
    }
}

enum ThemeBackground {
    case solid(ThemeColor)
    case gradient([String])
    case accentFill
    /// A vivid gradient of the accent.
    case accentGradient
    /// Frosted glass tinted with a color (nil: the accent).
    case glass(String?)

    /// Backgrounds made of the accent: text must stay readable on light accents.
    var followsAccent: Bool {
        switch self {
        case .accentFill, .accentGradient, .glass(nil): true
        default: false
        }
    }
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
    /// The composition the style starts from: layout, shapes, border, depth, texture, icons…
    /// Every setting can then be changed in the Studio.
    var preset: StyleOptions = StyleOptions()
}

enum ThemeCatalog {
    static let all: [WidgetTheme] = classicThemes + studioThemes

    /// The first twelve styles, unchanged.
    static let classicThemes: [WidgetTheme] = [
        WidgetTheme(
            id: .minimal, name: tr("Minimal"), tagline: tr("Suit le mode clair ou sombre"), isPremium: false,
            background: .solid(.adaptive(light: "FFFFFF", dark: "1C1C1E")),
            primary: .adaptive(light: "111114", dark: "F5F5F7"),
            secondary: .adaptive(light: "8A8A8E", dark: "98989F"),
            tint: .accent, panel: .adaptive(light: "F2F2F4", dark: "2A2A2D"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: nil
        ),
        WidgetTheme(
            id: .light, name: tr("Clair"), tagline: tr("Toujours lumineux"), isPremium: false,
            background: .solid(.fixed("F5F5F2")),
            primary: .fixed("16171A"), secondary: .fixed("7C7D82"),
            tint: .accent, panel: .fixed("E9E9E4"),
            fontDesign: .default, numberWeight: .medium, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: false
        ),
        WidgetTheme(
            id: .dark, name: tr("Sombre"), tagline: tr("Toujours sombre"), isPremium: false,
            background: .solid(.fixed("101114")),
            primary: .fixed("F2F2F4"), secondary: .fixed("8B8D93"),
            tint: .accent, panel: .fixed("1E2024"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .monochrome, name: tr("Monochrome"), tagline: tr("Noir, blanc, rien d'autre"), isPremium: false,
            background: .solid(.fixed("000000")),
            primary: .fixed("FFFFFF"), secondary: .fixed("7A7A7A"),
            tint: .fixed("FFFFFF"), panel: .fixed("1A1A1A"),
            fontDesign: .default, numberWeight: .light, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .glass, name: tr("Verre"), tagline: tr("Translucide et lumineux"), isPremium: true,
            background: .gradient(["6A85E0", "9C7FD6", "D98FB6"]),
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.74),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.18),
            fontDesign: .rounded, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: true
        ),
        WidgetTheme(
            id: .aurora, name: tr("Aurore"), tagline: tr("Un dégradé bleu nuit vers turquoise"), isPremium: true,
            background: .gradient(["1C2566", "2A6F9B", "3FB5A3"]),
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.72),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.14),
            fontDesign: .default, numberWeight: .bold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .elegant, name: tr("Élégant"), tagline: tr("Serif et reflets dorés"), isPremium: true,
            background: .solid(.fixed("13203A")),
            primary: .fixed("F3EBDD"), secondary: .fixed("B3A792"),
            tint: .fixed("C8A15A"), panel: .fixed("1D2B48"),
            fontDesign: .serif, numberWeight: .regular, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .digital, name: tr("Digital"), tagline: tr("Écran à cristaux liquides"), isPremium: true,
            background: .solid(.fixed("0A0F0B")),
            primary: .fixed("7CFFA0"), secondary: .fixed("3C8A54"),
            tint: .fixed("7CFFA0"), panel: .fixed("122017"),
            fontDesign: .monospaced, numberWeight: .medium, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .retro, name: tr("Rétro"), tagline: tr("Papier chaud et typo ronde"), isPremium: true,
            background: .solid(.fixed("F1E4C8")),
            primary: .fixed("2A1E14"), secondary: .fixed("8A6F55"),
            tint: .fixed("D4532A"), panel: .fixed("E6D5B1"),
            fontDesign: .rounded, numberWeight: .heavy, titleWeight: .bold,
            uppercaseLabels: true, isDarkSurface: false
        ),
        WidgetTheme(
            id: .futuristic, name: tr("Futuriste"), tagline: tr("Néon cyan sur nuit profonde"), isPremium: true,
            background: .gradient(["070B1F", "171046"]),
            primary: .fixed("E8F0FF"), secondary: .fixed("7F8BB5"),
            tint: .fixed("00E0FF"), panel: .fixed("00E0FF", 0.09),
            fontDesign: .monospaced, numberWeight: .light, titleWeight: .regular,
            uppercaseLabels: true, isDarkSurface: true
        ),
        WidgetTheme(
            id: .typography, name: tr("Typo"), tagline: tr("De grands chiffres, en serif"), isPremium: true,
            background: .solid(.adaptive(light: "FFFFFF", dark: "0E0E10")),
            primary: .adaptive(light: "0E0E10", dark: "FAFAFA"),
            secondary: .adaptive(light: "85858A", dark: "8E8E93"),
            tint: .accent, panel: .adaptive(light: "F1F1F1", dark: "1D1D20"),
            fontDesign: .serif, numberWeight: .black, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: nil
        ),
        WidgetTheme(
            id: .colorful, name: tr("Couleur"), tagline: tr("Ta couleur en plein fond"), isPremium: true,
            background: .accentFill,
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.78),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.2),
            fontDesign: .rounded, numberWeight: .bold, titleWeight: .bold,
            uppercaseLabels: false, isDarkSurface: true
        ),
    ]

    private static func preset(_ change: (inout StyleOptions) -> Void) -> StyleOptions {
        var options = StyleOptions()
        change(&options)
        return options
    }

    /// Styles that change the composition too, not only the colors.
    static let studioThemes: [WidgetTheme] = [
        WidgetTheme(
            id: .modern, name: tr("Moderne"), tagline: tr("Net, doux, pastilles d'icônes"), isPremium: false,
            background: .solid(.adaptive(light: "FFFFFF", dark: "17181B")),
            primary: .adaptive(light: "101114", dark: "F4F4F6"),
            secondary: .adaptive(light: "84858B", dark: "9A9BA1"),
            tint: .accent, panel: .adaptive(light: "F1F2F5", dark: "24262B"),
            fontDesign: .default, numberWeight: .bold, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: nil,
            preset: preset { $0.iconStyle = .circle; $0.shape = .soft; $0.iconFamily = .filled }
        ),
        WidgetTheme(
            id: .card, name: tr("Carte"), tagline: tr("Le contenu posé sur une carte"), isPremium: false,
            background: .solid(.adaptive(light: "E9ECF1", dark: "0B0C0F")),
            primary: .adaptive(light: "15171C", dark: "F2F3F5"),
            secondary: .adaptive(light: "7D828C", dark: "979BA3"),
            tint: .accent, panel: .adaptive(light: "FFFFFF", dark: "1E2026"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: nil,
            preset: preset { $0.shape = .panel; $0.depth = .soft; $0.shadowOpacity = 0.25 }
        ),
        WidgetTheme(
            id: .soft, name: tr("Doux"), tagline: tr("Formes rondes, tons tendres"), isPremium: false,
            background: .solid(.adaptive(light: "F6F1FA", dark: "201C27")),
            primary: .adaptive(light: "2E2438", dark: "F3EEF8"),
            secondary: .adaptive(light: "8D7F99", dark: "A99DB5"),
            tint: .accent, panel: .adaptive(light: "ECE3F4", dark: "2E2838"),
            fontDesign: .rounded, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: nil,
            preset: preset { $0.shape = .soft; $0.iconStyle = .circle; $0.chartThickness = 1.3 }
        ),
        WidgetTheme(
            id: .compact, name: tr("Compact"), tagline: tr("Plus d'infos, moins d'espace"), isPremium: false,
            background: .solid(.adaptive(light: "FFFFFF", dark: "141416")),
            primary: .adaptive(light: "111114", dark: "F5F5F7"),
            secondary: .adaptive(light: "8A8A8E", dark: "98989F"),
            tint: .accent, panel: .adaptive(light: "F2F2F4", dark: "232326"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: nil,
            preset: preset { $0.density = .dense; $0.titleScale = 0.9; $0.valueScale = 0.9; $0.iconStyle = .none; $0.shape = .square }
        ),
        WidgetTheme(
            id: .liquidGlass, name: tr("Liquid Glass"), tagline: tr("Verre liquide et reflets"), isPremium: true,
            background: .glass(nil),
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.76),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.18),
            fontDesign: .rounded, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: true,
            preset: preset {
                $0.border = .solid; $0.borderHex = "FFFFFF"; $0.borderWidth = 1; $0.borderOpacity = 0.45
                $0.depth = .soft; $0.shape = .soft; $0.iconStyle = .circle
            }
        ),
        WidgetTheme(
            id: .premium, name: tr("Premium"), tagline: tr("Graphite, argent, fin liseré"), isPremium: true,
            background: .gradient(["2B2E35", "0C0D10"]),
            primary: .fixed("F2F2F4"), secondary: .fixed("9B9DA4"),
            tint: .accent, panel: .fixed("FFFFFF", 0.07),
            fontDesign: .default, numberWeight: .medium, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset {
                $0.border = .gradient; $0.borderWidth = 1.2; $0.depth = .floating; $0.iconStyle = .outline; $0.tracking = 0.8
            }
        ),
        WidgetTheme(
            id: .gradient, name: tr("Dégradé"), tagline: tr("Ta couleur en dégradé vif"), isPremium: true,
            background: .accentGradient,
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.78),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.2),
            fontDesign: .rounded, numberWeight: .bold, titleWeight: .bold,
            uppercaseLabels: false, isDarkSurface: true,
            preset: preset { $0.depth = .soft; $0.iconStyle = .circle; $0.shape = .soft }
        ),
        WidgetTheme(
            id: .neon, name: tr("Néon"), tagline: tr("Lueurs roses sur fond noir"), isPremium: true,
            background: .solid(.fixed("07030F")),
            primary: .fixed("FFE9F7"), secondary: .fixed("B07FA3"),
            tint: .fixed("FF2DAA"), panel: .fixed("FF2DAA", 0.1),
            fontDesign: .rounded, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.border = .glow; $0.borderWidth = 1.5; $0.depth = .glow; $0.chartThickness = 1.3; $0.iconStyle = .outline }
        ),
        WidgetTheme(
            id: .editorial, name: tr("Éditorial"), tagline: tr("Serif, papier et capitales"), isPremium: true,
            background: .solid(.fixed("F7F3EA")),
            primary: .fixed("151412"), secondary: .fixed("7A746A"),
            tint: .accent, panel: .fixed("ECE6D8"),
            fontDesign: .serif, numberWeight: .regular, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: false,
            preset: preset {
                $0.layout = .vertical; $0.tracking = 1.4; $0.shape = .square; $0.iconStyle = .none
                $0.valueScale = 1.15; $0.titleScale = 0.95; $0.monospacedNumbers = false
            }
        ),
        WidgetTheme(
            id: .magazine, name: tr("Magazine"), tagline: tr("Un grand chiffre, comme une une"), isPremium: true,
            background: .solid(.adaptive(light: "FFFFFF", dark: "111111")),
            primary: .adaptive(light: "0D0D0D", dark: "FAFAFA"),
            secondary: .adaptive(light: "7F7F7F", dark: "8F8F8F"),
            tint: .accent, panel: .adaptive(light: "F2F2F2", dark: "1F1F1F"),
            fontDesign: .serif, numberWeight: .black, titleWeight: .bold,
            uppercaseLabels: true, isDarkSurface: nil,
            preset: preset { $0.layout = .minimal; $0.valueScale = 1.3; $0.tracking = 2; $0.iconStyle = .none; $0.monospacedNumbers = false }
        ),
        WidgetTheme(
            id: .dashboard, name: tr("Tableau de bord"), tagline: tr("Petites cartes, tout d'un coup d'œil"), isPremium: true,
            background: .solid(.fixed("0F172A")),
            primary: .fixed("E2E8F0"), secondary: .fixed("8391A7"),
            tint: .accent, panel: .fixed("1E293B"),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.layout = .cards; $0.density = .dense; $0.iconStyle = .square; $0.shape = .rounded }
        ),
        WidgetTheme(
            id: .bold, name: tr("Audacieux"), tagline: tr("Chiffres énormes, couleur pleine"), isPremium: true,
            background: .accentFill,
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.8),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.22),
            fontDesign: .default, numberWeight: .black, titleWeight: .heavy,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.valueScale = 1.25; $0.tracking = 0.8; $0.iconStyle = .none; $0.layout = .minimal }
        ),
        WidgetTheme(
            id: .data, name: tr("Data"), tagline: tr("Grille, mono et courbes"), isPremium: true,
            background: .solid(.fixed("0B0E13")),
            primary: .fixed("E6EDF3"), secondary: .fixed("7D8590"),
            tint: .accent, panel: .fixed("161B22"),
            fontDesign: .monospaced, numberWeight: .medium, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.layout = .data; $0.texture = .grid; $0.textureOpacity = 0.22; $0.iconStyle = .square; $0.chart = .line }
        ),
        WidgetTheme(
            id: .luxury, name: tr("Luxe"), tagline: tr("Noir profond et or"), isPremium: true,
            background: .gradient(["171512", "050505"]),
            primary: .fixed("F5E7C1"), secondary: .fixed("A8946A"),
            tint: .fixed("D4AF37"), panel: .fixed("D4AF37", 0.08),
            fontDesign: .serif, numberWeight: .light, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.border = .double; $0.borderWidth = 1.2; $0.iconStyle = .outline; $0.tracking = 1.2; $0.monospacedNumbers = false }
        ),
        WidgetTheme(
            id: .sport, name: tr("Sport"), tagline: tr("Noir et jaune fluo, énergie"), isPremium: true,
            background: .solid(.fixed("0E0E0E")),
            primary: .fixed("FFFFFF"), secondary: .fixed("9A9A9A"),
            tint: .fixed("C6FF00"), panel: .fixed("1C1C1C"),
            fontDesign: .rounded, numberWeight: .heavy, titleWeight: .bold,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.layout = .progress; $0.valueScale = 1.1; $0.iconStyle = .circle; $0.chartThickness = 1.5; $0.shape = .capsule }
        ),
        WidgetTheme(
            id: .business, name: tr("Business"), tagline: tr("Marine, sobre et aligné"), isPremium: true,
            background: .solid(.fixed("0E2A47")),
            primary: .fixed("FFFFFF"), secondary: .fixed("9FB3C8"),
            tint: .accent, panel: .fixed("FFFFFF", 0.08),
            fontDesign: .default, numberWeight: .semibold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset {
                $0.layout = .data; $0.border = .solid; $0.borderWidth = 1; $0.borderOpacity = 0.22
                $0.shape = .square; $0.iconStyle = .square
            }
        ),
        WidgetTheme(
            id: .terminal, name: tr("Terminal"), tagline: tr("Ta couleur sur noir, lignes d'écran"), isPremium: true,
            background: .solid(.fixed("0A0A0A")),
            primary: .accent, secondary: .accentFaded(0.62),
            tint: .accent, panel: .accentFaded(0.1),
            fontDesign: .monospaced, numberWeight: .regular, titleWeight: .regular,
            uppercaseLabels: false, isDarkSurface: true,
            preset: preset { $0.texture = .lines; $0.textureOpacity = 0.35; $0.titleCase = .lower; $0.iconStyle = .none; $0.chart = .sparkline; $0.shape = .square }
        ),
        WidgetTheme(
            id: .blueprint, name: tr("Plan"), tagline: tr("Bleu d'architecte et grille"), isPremium: true,
            background: .solid(.fixed("1D4E89")),
            primary: .fixed("FFFFFF"), secondary: .fixed("BFD4EE"),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.1),
            fontDesign: .monospaced, numberWeight: .medium, titleWeight: .medium,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset {
                $0.texture = .grid; $0.textureOpacity = 0.45; $0.border = .dashed; $0.borderWidth = 1; $0.borderOpacity = 0.6
                $0.iconStyle = .outline; $0.iconFamily = .outlined; $0.chartFill = false
            }
        ),
        WidgetTheme(
            id: .pastel, name: tr("Pastel"), tagline: tr("Couleurs de dragée"), isPremium: true,
            background: .solid(.adaptive(light: "FFF1E6", dark: "2B2422")),
            primary: .adaptive(light: "4A3B35", dark: "F6EAE3"),
            secondary: .adaptive(light: "9C8A82", dark: "B8A69E"),
            tint: .accent, panel: .adaptive(light: "FDE2D0", dark: "3A302C"),
            fontDesign: .rounded, numberWeight: .bold, titleWeight: .semibold,
            uppercaseLabels: false, isDarkSurface: nil,
            preset: preset { $0.shape = .soft; $0.iconStyle = .circle; $0.chartThickness = 1.4; $0.layout = .horizontal }
        ),
        WidgetTheme(
            id: .paper, name: tr("Papier"), tagline: tr("Papier crème et encre"), isPremium: true,
            background: .solid(.fixed("F4EFE6")),
            primary: .fixed("2B2B2B"), secondary: .fixed("7C766C"),
            tint: .fixed("B23A2E"), panel: .fixed("EAE3D6"),
            fontDesign: .serif, numberWeight: .semibold, titleWeight: .medium,
            uppercaseLabels: false, isDarkSurface: false,
            preset: preset { $0.texture = .paper; $0.textureOpacity = 0.6; $0.iconFamily = .outlined; $0.monospacedNumbers = false }
        ),
        WidgetTheme(
            id: .brutalist, name: tr("Brutaliste"), tagline: tr("Bord épais, noir sur blanc"), isPremium: true,
            background: .solid(.fixed("FFFFFF")),
            primary: .fixed("000000"), secondary: .fixed("000000", 0.62),
            tint: .accent, panel: .fixed("000000", 0.06),
            fontDesign: .monospaced, numberWeight: .heavy, titleWeight: .bold,
            uppercaseLabels: true, isDarkSurface: false,
            preset: preset {
                $0.border = .solid; $0.borderHex = "000000"; $0.borderWidth = 4; $0.shape = .square
                $0.iconStyle = .square; $0.layout = .split
            }
        ),
        WidgetTheme(
            id: .carbon, name: tr("Carbone"), tagline: tr("Fibre sombre et relief"), isPremium: true,
            background: .gradient(["262626", "0F0F0F"]),
            primary: .fixed("EDEDED"), secondary: .fixed("8C8C8C"),
            tint: .accent, panel: .fixed("FFFFFF", 0.06),
            fontDesign: .default, numberWeight: .bold, titleWeight: .semibold,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.texture = .diagonal; $0.textureOpacity = 0.3; $0.depth = .embossed; $0.iconStyle = .circle }
        ),
        WidgetTheme(
            id: .vapor, name: tr("Vapor"), tagline: tr("Rose et bleu rétro-futur"), isPremium: true,
            background: .gradient(["FF6AD5", "8795E8"]),
            primary: .fixed("FFFFFF"), secondary: .fixed("FFFFFF", 0.8),
            tint: .fixed("FFFFFF"), panel: .fixed("FFFFFF", 0.2),
            fontDesign: .rounded, numberWeight: .heavy, titleWeight: .bold,
            uppercaseLabels: true, isDarkSurface: true,
            preset: preset { $0.texture = .grid; $0.textureOpacity = 0.3; $0.depth = .glow; $0.shadowHex = "FFFFFF"; $0.iconStyle = .outline; $0.layout = .graph }
        ),
        WidgetTheme(
            id: .chalk, name: tr("Ardoise"), tagline: tr("Tableau noir et craie"), isPremium: true,
            background: .solid(.fixed("2F3B35")),
            primary: .fixed("F2F2EA"), secondary: .fixed("B5BDB5"),
            tint: .fixed("F6E27A"), panel: .fixed("FFFFFF", 0.08),
            fontDesign: .rounded, numberWeight: .medium, titleWeight: .medium,
            uppercaseLabels: false, isDarkSurface: true,
            preset: preset { $0.texture = .grain; $0.textureOpacity = 0.5; $0.border = .dashed; $0.borderWidth = 1.5; $0.borderOpacity = 0.35; $0.iconFamily = .outlined }
        ),
        WidgetTheme(
            id: .mist, name: tr("Brume"), tagline: tr("Pâle, léger, presque translucide"), isPremium: true,
            background: .gradient(["F8FAFD", "DCE3EC"]),
            primary: .fixed("1E2833"), secondary: .fixed("6B7785"),
            tint: .accent, panel: .fixed("FFFFFF", 0.6),
            fontDesign: .default, numberWeight: .light, titleWeight: .medium,
            uppercaseLabels: false, isDarkSurface: false,
            preset: preset {
                $0.texture = .noise; $0.textureOpacity = 0.25; $0.depth = .soft; $0.shadowOpacity = 0.18
                $0.border = .solid; $0.borderHex = "FFFFFF"; $0.borderWidth = 1.5; $0.borderOpacity = 0.9; $0.shape = .panel
            }
        ),
    ]

    static func theme(_ id: ThemeID) -> WidgetTheme {
        all.first { $0.id == id } ?? all[0]
    }

    static var free: [WidgetTheme] { all.filter { !$0.isPremium } }
}

extension WeightChoice {
    var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
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
    /// The color of the main values (the text color unless the person picked one).
    var numberColor: Color
    /// The color of the icons (the accent unless the person picked one).
    var icon: Color
    /// The color of charts, rings and progress bars (the accent unless the person picked one).
    var chart: Color
    var fontDesign: Font.Design
    var numberWeight: Font.Weight
    var titleWeight: Font.Weight
    /// The weight of the small widget titles.
    var labelWeight: Font.Weight
    var uppercaseLabels: Bool
    var lowercaseLabels: Bool
    var alignment: ContentAlignment
    var showsTitle: Bool
    var showsDetails: Bool
    /// Text color readable on top of `accent`.
    var onAccent: Color
    /// Multicolor SF Symbols (weather) only look right on neutral backgrounds.
    var prefersMulticolorSymbols: Bool
    /// Every Studio setting, the style's own values under the person's.
    var options: StyleOptions
    var isDarkSurface: Bool
    var shadowColor: Color
    var borderColor: Color
    /// Colors given in turn to lines and parts of a whole (a palette's, or the main color's shades).
    /// Empty: each line keeps its own color.
    var series: [String]

    init(design: WidgetDesign) {
        let theme = design.theme
        let accentHex = design.accentHex
        let options = design.effectiveStyle
        // With « Couleur principale », every color of the style takes the main color's hue.
        let recolor: String? = options.recolor ? accentHex : nil
        func ink(_ hex: String) -> String { recolor.map { ColorMath.recolor(hex, to: $0) } ?? hex }
        var primary = theme.primary.resolve(accent: accentHex, recolor: recolor)
        var secondary = theme.secondary.resolve(accent: accentHex, recolor: recolor)
        var tint = theme.tint.resolve(accent: accentHex, recolor: recolor)
        var panel = theme.panel.resolve(accent: accentHex, recolor: recolor, surface: true)
        var darkSurface = theme.isDarkSurface
        var tintHex: String? = {
            switch theme.tint {
            case let .fixed(hex, _): return recolor == nil ? hex : ink(hex)
            case .accent, .accentFaded: return accentHex
            case .adaptive: return nil
            }
        }()
        // A style's own highlight color (pink, gold, fluo…) becomes the main color itself.
        if recolor != nil, case let .fixed(_, opacity) = theme.tint, !theme.tint.isNeutral {
            tint = Color(hex: accentHex).opacity(opacity)
            tintHex = accentHex
        }
        var neutral = [ThemeID.minimal, .light, .dark, .typography, .modern, .card, .compact, .magazine].contains(theme.id)

        // Themes filled with the accent must keep readable text on light accents.
        if theme.background.followsAccent, ColorMath.isLight(Self.surfaceHex(theme.background, accentHex: accentHex)) {
            primary = Color(hex: ink("16171A"))
            secondary = Color(hex: ink("16171A")).opacity(0.7)
            tint = primary
            tintHex = ink("16171A")
            panel = Color.black.opacity(0.08)
            darkSurface = false
        }

        func readable(on light: Bool) {
            primary = Color(hex: ink(light ? "16171A" : "FFFFFF"))
            secondary = light ? Color(hex: ink("16171A")).opacity(0.6) : Color(hex: ink("FFFFFF")).opacity(0.7)
            panel = light ? Color.black.opacity(0.06) : Color.white.opacity(0.12)
            darkSurface = !light
            neutral = false
        }

        /// White text on a colorful background (the accent gradient, a photo).
        func onColorful() {
            primary = .white
            secondary = Color.white.opacity(0.75)
            tint = .white
            tintHex = "FFFFFF"
            panel = Color.white.opacity(0.16)
            darkSurface = true
            neutral = false
        }

        switch design.background {
        case .theme:
            break
        case let .color(hex):
            readable(on: ColorMath.isLight(hex))
            if case .fixed = theme.tint, recolor == nil {} else {
                tint = Color(hex: accentHex)
                tintHex = accentHex
            }
        case .gradient:
            if let spec = options.gradient {
                let light = ColorMath.isLight(ColorMath.mix(spec.startHex, spec.endHex, 0.5 * spec.intensity))
                readable(on: light)
                tint = light ? Color(hex: "16171A") : .white
                tintHex = light ? "16171A" : "FFFFFF"
            } else {
                onColorful()
            }
        case .glass:
            let light = GlassSurface.isLight(accentHex)
            readable(on: light)
            tint = light ? Color(hex: "16171A") : .white
            tintHex = light ? "16171A" : "FFFFFF"
            panel = light ? Color.white.opacity(0.35) : Color.white.opacity(0.18)
        case .photo:
            onColorful()
        }

        // The person's own colors win over the style's.
        if let hex = options.textHex {
            primary = Color(hex: hex)
            if options.secondaryHex == nil { secondary = Color(hex: hex).opacity(0.62) }
        }
        if let hex = options.secondaryHex { secondary = Color(hex: hex) }
        if let hex = options.panelHex { panel = Color(hex: hex) }

        self.primary = primary
        self.secondary = secondary
        self.accent = tint
        self.track = secondary.opacity(0.25)
        self.panel = panel
        self.numberColor = options.numberHex.map { Color(hex: $0) } ?? primary
        self.icon = options.iconHex.map { Color(hex: $0) } ?? tint
        self.chart = options.chartHex.map { Color(hex: $0) } ?? tint
        let onDark = darkSurface ?? false
        self.isDarkSurface = onDark
        // On colorful gradients and photos, green and red text is hard to read: the sign carries the meaning.
        let colorful: Bool = {
            switch design.background {
            case .theme:
                switch theme.background {
                case .gradient, .accentGradient, .glass: return true
                default: return false
                }
            case .color:
                return false
            default:
                return true
            }
        }()
        self.positive = options.positiveHex.map { Color(hex: $0) } ?? (colorful ? primary : (onDark ? Color(hex: "5BD68A") : Color(hex: "1E9E57")))
        self.negative = options.negativeHex.map { Color(hex: $0) } ?? (colorful ? primary : (onDark ? Color(hex: "FF7A7A") : Color(hex: "D6364B")))
        switch design.font {
        case .theme: self.fontDesign = theme.fontDesign
        case .standard: self.fontDesign = .default
        case .rounded: self.fontDesign = .rounded
        case .serif: self.fontDesign = .serif
        case .mono: self.fontDesign = .monospaced
        }
        self.numberWeight = options.numberWeight?.fontWeight ?? theme.numberWeight
        self.titleWeight = options.titleWeight?.fontWeight ?? theme.titleWeight
        self.labelWeight = options.titleWeight?.fontWeight ?? .semibold
        switch options.titleCase {
        case .theme:
            self.uppercaseLabels = theme.uppercaseLabels
            self.lowercaseLabels = false
        case .upper:
            self.uppercaseLabels = true
            self.lowercaseLabels = false
        case .normal:
            self.uppercaseLabels = false
            self.lowercaseLabels = false
        case .lower:
            self.uppercaseLabels = false
            self.lowercaseLabels = true
        }
        self.alignment = design.alignment
        self.showsTitle = design.showsTitle && !options.isHidden("title")
        self.showsDetails = design.showsDetails && !options.isHidden("detail")
        self.onAccent = (tintHex.map(ColorMath.isLight) ?? false) ? Color(hex: "16171A") : .white
        self.prefersMulticolorSymbols = neutral && options.iconHex == nil
        self.options = options
        // The style's own border and shadow colors follow the main color too; the person's stay as picked.
        let shadowHex = design.style.shadowHex == nil ? options.shadowHex.map(ink) : options.shadowHex
        let borderHex = design.style.borderHex == nil ? options.borderHex.map(ink) : options.borderHex
        self.shadowColor = shadowHex.map { Color(hex: $0) } ?? (options.depth == .glow ? (options.chartHex.map { Color(hex: $0) } ?? tint) : .black)
        let border = borderHex.map { Color(hex: $0) } ?? ((options.border == .glow || options.border == .gradient) ? (options.chartHex.map { Color(hex: $0) } ?? tint) : primary)
        self.borderColor = border.opacity(options.borderOpacity)
        if !options.seriesHexes.isEmpty {
            self.series = options.seriesHexes
        } else if options.recolor {
            self.series = ColorMath.series(from: accentHex)
        } else {
            self.series = []
        }
    }

    /// The color the text sits on, for backgrounds made of the accent.
    private static func surfaceHex(_ background: ThemeBackground, accentHex: String) -> String {
        switch background {
        // Glass is darkened by its tint: only very pale tints need dark text.
        case .glass: GlassSurface.isLight(accentHex) ? "FFFFFF" : "000000"
        default: accentHex
        }
    }

    func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * options.textScale, weight: weight, design: fontDesign)
    }

    func number(_ size: CGFloat) -> Font {
        let font = Font.system(size: size * options.valueScale, weight: numberWeight, design: fontDesign)
        return options.monospacedNumbers ? font.monospacedDigit() : font
    }

    /// The small title of a widget.
    func label(_ size: CGFloat) -> Font {
        .system(size: size * options.titleScale, weight: labelWeight, design: fontDesign)
    }

    func labelText(_ text: String) -> String {
        if uppercaseLabels { return text.uppercased() }
        if lowercaseLabels { return text.lowercased() }
        return text
    }

    var labelTracking: CGFloat { (uppercaseLabels ? 0.6 : 0) + options.tracking }

    var horizontalAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    var textAlignment: TextAlignment { alignment == .center ? .center : .leading }
    var frameAlignment: Alignment { alignment == .center ? .center : .leading }

    // MARK: Studio

    /// The color of one line (a macro, a category) when the person picked one.
    func rowColor(_ id: String) -> String? { options.rowColors[id] }

    /// Space around the content, by density.
    func padding(for large: Bool) -> CGFloat {
        let base: CGFloat = large ? 18 : 16
        switch options.density {
        case .compact: return base + 4
        case .balanced: return base
        case .dense: return base - 4
        }
    }

    /// Multiplies the spacing between elements.
    var spacing: CGFloat {
        switch options.density {
        case .compact: 1.35
        case .balanced: 1
        case .dense: 0.7
        }
    }

    /// Lines added to (or removed from) lists, by density.
    var rowDelta: Int {
        switch options.density {
        case .compact: -1
        case .balanced: 0
        case .dense: 2
        }
    }

    /// The corner radius of inner shapes (cards, bars, buttons) for a style's usual radius.
    func radius(_ base: CGFloat) -> CGFloat {
        switch options.shape {
        case .theme, .rounded, .panel: base
        case .soft: base * 1.8
        case .square: min(base, 2)
        case .capsule: 999
        }
    }

    var isPanel: Bool { options.shape == .panel }

    /// Resolves an icon to the chosen icon family (keeps the original when a variant doesn't exist).
    func symbol(_ name: String) -> String {
        SymbolFamily.resolve(name, family: options.iconFamily)
    }

    var iconStyle: IconStyle { options.iconStyle == .theme ? .plain : options.iconStyle }
}

/// Paints the background of a design: theme, flat color, gradient, glass or photo, then its texture.
struct DesignBackground: View {
    let design: WidgetDesign

    var body: some View {
        let options = design.effectiveStyle
        base(options)
            .overlay {
                if options.texture != .none {
                    TextureView(kind: options.texture, color: ResolvedStyle(design: design).primary, opacity: options.textureOpacity)
                }
            }
    }

    @ViewBuilder private func base(_ options: StyleOptions) -> some View {
        switch design.background {
        case .theme:
            themeBackground
        case let .color(hex):
            Color(hex: hex)
        case .gradient:
            if let spec = options.gradient {
                CustomGradient(spec: spec)
            } else {
                LinearGradient(
                    colors: [Color(hex: ColorMath.shade(design.accentHex, 0.18)), Color(hex: ColorMath.shade(design.accentHex, -0.45))],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        case .glass:
            GlassSurface(tintHex: design.accentHex)
        case let .photo(name):
            if let image = ImageStore.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(options.veil ?? 0.28))
            } else {
                themeBackground
            }
        }
    }

    /// The main color, when it tints the whole style.
    private var recolor: String? { design.effectiveStyle.recolor ? design.accentHex : nil }

    @ViewBuilder private var themeBackground: some View {
        switch design.theme.background {
        case let .solid(color):
            color.resolve(accent: design.accentHex, recolor: recolor, surface: true)
        case let .gradient(hexes):
            LinearGradient(
                colors: hexes.map { hex in Color(hex: recolor.map { ColorMath.recolor(hex, to: $0, surface: true) } ?? hex) },
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .accentFill:
            LinearGradient(
                colors: [Color(hex: design.accentHex), Color(hex: ColorMath.shade(design.accentHex, -0.12))],
                startPoint: .top, endPoint: .bottom
            )
        case .accentGradient:
            LinearGradient(
                colors: [Color(hex: ColorMath.shade(design.accentHex, 0.25)), Color(hex: design.accentHex), Color(hex: ColorMath.shade(design.accentHex, -0.5))],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case let .glass(tint):
            GlassSurface(tintHex: recolor == nil ? (tint ?? design.accentHex) : design.accentHex)
        }
    }
}

/// The person's own gradient: two colors, a direction and an intensity.
struct CustomGradient: View {
    let spec: GradientSpec

    var body: some View {
        let end = ColorMath.mix(spec.startHex, spec.endHex, spec.intensity)
        let colors = [Color(hex: spec.startHex), Color(hex: end)]
        switch spec.direction {
        case .down: LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
        case .up: LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top)
        case .across: LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        case .diagonal: LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .radial: RadialGradient(colors: colors, center: .center, startRadius: 4, endRadius: 240)
        }
    }
}

/// Frosted glass: iOS doesn't let a widget blur the wallpaper behind it, so the tint, the frost,
/// the soft light spots and the reflection are drawn.
struct GlassSurface: View {
    let tintHex: String

    /// Whether the glass is pale enough to need dark text.
    static func isLight(_ tintHex: String) -> Bool {
        ColorMath.luminance(tintHex) > 0.55
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: Self.isLight(tintHex)
                    ? [Color(hex: ColorMath.shade(tintHex, 0.2)), Color(hex: ColorMath.shade(tintHex, -0.15))]
                    : [Color(hex: ColorMath.shade(tintHex, -0.05)), Color(hex: ColorMath.shade(tintHex, -0.48))],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                let size = max(geo.size.width, geo.size.height)
                ZStack {
                    Circle()
                        .fill(Color(hex: ColorMath.shade(tintHex, Self.isLight(tintHex) ? 0.55 : 0.2)).opacity(0.35))
                        .frame(width: size * 0.7, height: size * 0.7)
                        .blur(radius: size * 0.16)
                        .position(x: geo.size.width * 0.18, y: geo.size.height * 0.12)
                    Circle()
                        .fill(Color(hex: ColorMath.shade(tintHex, -0.2)).opacity(0.8))
                        .frame(width: size * 0.6, height: size * 0.6)
                        .blur(radius: size * 0.18)
                        .position(x: geo.size.width * 0.9, y: geo.size.height * 0.95)
                }
            }
            LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.2),
                    .init(color: Color.white.opacity(0.2), location: 0.42),
                    .init(color: .clear, location: 0.6),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}
