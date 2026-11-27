import SwiftUI
import UIKit

/// One style of the Studio's « Style » tab: a complete look (base, colors, background, font and every setting at
/// once). Only the look changes: the widget's content, structure and functions stay. Applying one keeps the parts the
/// person hid. The 4 original styles are free; every other one is Premium.
struct StyleLook: Identifiable, Hashable {
    let id: String
    let name: String
    /// One line under the preview.
    let summary: String
    /// Internal family, never shown: keeps neighbours in the grid related.
    let family: String
    let themeID: ThemeID
    /// Nil: the person's main color stays (the original styles follow it).
    let accentHex: String?
    let background: BackgroundStyle
    let font: FontChoice
    let style: StyleOptions

    var isFree: Bool { StyleCatalog.freeIDs.contains(id) }
    var isPremium: Bool { !isFree }

    /// The design in this style, its content and hidden parts untouched.
    func applied(to design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.themeID = themeID
        if let accentHex { copy.accentHex = accentHex }
        copy.background = background
        copy.font = font
        var look = style
        look.hidden = design.style.hidden
        copy.style = look
        return copy
    }

    /// Whether the design is in this style (and nothing was changed since).
    func matches(_ design: WidgetDesign) -> Bool {
        // Field by field, same as comparing applied(to:) but without copying the whole design.
        themeID == design.themeID && (accentHex == nil || accentHex == design.accentHex)
            && background == design.background && font == design.font
            && style.look == design.style.look
    }
}

enum StyleCatalog {
    /// The 4 original styles, the only free ones.
    static let freeIDs: Set<String> = ["minimal", "light", "dark", "monochrome"]

    static let originals: [StyleLook] = [ThemeID.minimal, .light, .dark, .monochrome].map { id in
        let theme = ThemeCatalog.theme(id)
        return StyleLook(id: id.rawValue, name: theme.name, summary: theme.tagline, family: "original", themeID: id,
                         accentHex: nil, background: .theme, font: .theme, style: StyleOptions())
    }

    /// Every style, the originals first, then the families in their order (generated: StyleLibraryData.swift).
    static let all: [StyleLook] = originals + generated

    private static let index: [String: StyleLook] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func look(_ id: String) -> StyleLook? { index[id] }

    static var premiumCount: Int { all.count - freeIDs.count }

    /// The style a design is in, if it was applied and left unchanged.
    static func current(for design: WidgetDesign) -> StyleLook? { all.first { $0.matches(design) } }
}

/// A family of styles: one row of the Style tool, named above it.
struct StyleFamily: Identifiable {
    let id: String
    let name: String
}

/// The filters above the Style tool's rows.
enum StyleFilter: String, CaseIterable, Identifiable {
    case all, free, dark, light, colorful

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: tr("Tous")
        case .free: tr("Gratuits")
        case .dark: tr("Sombres")
        case .light: tr("Clairs")
        case .colorful: tr("Colorés")
        }
    }

    func includes(_ look: StyleLook) -> Bool {
        switch self {
        case .all: true
        case .free: look.isFree
        case .dark: StyleCatalog.isDark(look)
        case .light: !StyleCatalog.isDark(look)
        case .colorful: StyleCatalog.isColorful(look)
        }
    }
}

extension StyleCatalog {
    /// The families in the order of their rows (the ids of `StyleLibraryData.swift`).
    static let families: [StyleFamily] = [
        StyleFamily(id: "aura", name: tr("Aura")),
        StyleFamily(id: "prime", name: tr("Prestige")),
        StyleFamily(id: "luxe", name: tr("Luxe")),
        StyleFamily(id: "riche", name: tr("Opulence")),
        StyleFamily(id: "chrome", name: tr("Chrome")),
        StyleFamily(id: "verre", name: tr("Verre")),
        StyleFamily(id: "girl", name: tr("Girly")),
        StyleFamily(id: "rose", name: tr("Rose")),
        StyleFamily(id: "pixel", name: tr("Pixel")),
        StyleFamily(id: "gaming", name: tr("Gaming")),
        StyleFamily(id: "cyberpunk", name: tr("Cyberpunk")),
        StyleFamily(id: "y2k", name: tr("Y2K")),
        StyleFamily(id: "vintage", name: tr("Vintage")),
        StyleFamily(id: "retro", name: tr("Rétro")),
        StyleFamily(id: "neon", name: tr("Néon")),
        StyleFamily(id: "minimal", name: tr("Minimaliste")),
        StyleFamily(id: "brutal", name: tr("Brutal")),
        StyleFamily(id: "nature", name: tr("Nature")),
        StyleFamily(id: "illustration", name: tr("Illustré")),
        StyleFamily(id: "sport", name: tr("Sport")),
    ]

    private static let byFamily: [String: [StyleLook]] = Dictionary(grouping: generated, by: \.family)

    static func looks(in family: String) -> [StyleLook] { byFamily[family] ?? [] }

    /// Computed once: the filters run over 500 styles at each change.
    private static let traits: [String: (dark: Bool, colorful: Bool)] = Dictionary(
        all.map { look in (look.id, (dark: darkness(look), colorful: colorfulness(look))) },
        uniquingKeysWith: { first, _ in first }
    )

    static func isDark(_ look: StyleLook) -> Bool { traits[look.id]?.dark ?? false }
    static func isColorful(_ look: StyleLook) -> Bool { traits[look.id]?.colorful ?? false }

    /// A dark style writes in light letters; the originals follow their theme.
    private static func darkness(_ look: StyleLook) -> Bool {
        if let text = look.style.textHex { return ColorMath.isLight(text) }
        return look.themeID == .dark || look.themeID == .monochrome
    }

    /// A colorful style has a saturated background (flat, gradient or tinted glass).
    private static func colorfulness(_ look: StyleLook) -> Bool {
        let hexes: [String]
        switch look.background {
        case .color(let hex): hexes = [hex]
        case .gradient: hexes = [look.style.gradient?.startHex, look.style.gradient?.endHex, look.accentHex].compactMap { $0 }
        case .glass: hexes = [look.accentHex].compactMap { $0 }
        default: hexes = []
        }
        return hexes.contains { hex in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(Color(hex: hex)).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return s > 0.35 && b > 0.35
        }
    }
}
