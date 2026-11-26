import SwiftUI

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
        let applied = applied(to: design)
        return applied.themeID == design.themeID && applied.accentHex == design.accentHex
            && applied.background == design.background && applied.font == design.font
            && applied.style.look == design.style.look
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
