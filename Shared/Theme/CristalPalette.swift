import SwiftUI

// Jetons de couleur de la refonte « Cristal » : port exact du calcul de docs/design/2026-11-15-cristal/cristal.js
// (tokens, tokensDark) et cristal_reference.js. Calcul pur sur des HEX : aucune vue (compilé aussi dans le widget).
// Les tests (Tests/CristalPaletteTests.swift) comparent le résultat à Tests/CristalPaletteReference.swift.

/// Une nappe de couleur du fond : ellipse (rx, ry) centrée en (x, y) sur un écran de référence 393 × 852.
struct CristalWash: Equatable {
    let rx: Double
    let ry: Double
    let x: Double
    let y: Double
}

/// Une déclinaison dessinée (THEMES de cristal.js). HEX sans dièse, majuscules.
struct CristalSeed {
    let id: String
    let primary: String
    let secondary: String
    let accent: String
    let bg: String
    let na: String
    let nb: String
    let ink: String
    let ink2: String
    let rule: String
    let track: String
    /// Part de la couleur principale mêlée aux couleurs de catégorie.
    let cat: Double
    /// Part de gris mêlée aux catégories (teintes neutres), et couleur du panneau clair.
    let gray: Double
    let panel: String
    let radius: Double
    /// Nappe 1 (couleur `na`) puis nappe 2 (couleur `nb`).
    let washes: [CristalWash]

    static let saphir = CristalSeed(id: "saphir", primary: "245B8F", secondary: "398FA8", accent: "1E9EC0", bg: "EEF3FA", na: "BFEAF2", nb: "C9D8FB",
                                    ink: "0B1220", ink2: "4E5A6B", rule: "D6DFEB", track: "D3DCE8", cat: 0, gray: 0, panel: "FFFFFF", radius: 26,
                                    washes: [CristalWash(rx: 190, ry: 190, x: 333, y: 200), CristalWash(rx: 220, ry: 220, x: 30, y: 640)])
    static let lavande = CristalSeed(id: "lavande", primary: "6841A5", secondary: "9854B8", accent: "A765D6", bg: "F4F1FA", na: "DDD2F8", nb: "F6D6E8",
                                     ink: "1A1330", ink2: "5A5270", rule: "E1DAEE", track: "DCD4EA", cat: 0.14, gray: 0, panel: "FFFFFF", radius: 28,
                                     washes: [CristalWash(rx: 220, ry: 220, x: 50, y: 170), CristalWash(rx: 230, ry: 230, x: 390, y: 560)])
    static let rose = CristalSeed(id: "rose", primary: "AD3561", secondary: "E0705F", accent: "DD6654", bg: "FBF2F4", na: "F9D2DC", nb: "FFDDCC",
                                  ink: "2A1420", ink2: "6A5560", rule: "F0DEE3", track: "EBD8DE", cat: 0.12, gray: 0, panel: "FFFFFF", radius: 28,
                                  washes: [CristalWash(rx: 260, ry: 200, x: 196, y: 70), CristalWash(rx: 220, ry: 220, x: 360, y: 770)])
    static let sauge = CristalSeed(id: "sauge", primary: "4A6E39", secondary: "7DB79E", accent: "3E9E7C", bg: "F2F6EF", na: "D6E8CC", nb: "D2F0E4",
                                   ink: "152015", ink2: "566355", rule: "DCE6D6", track: "D6E0CF", cat: 0.16, gray: 0, panel: "FFFFFF", radius: 26,
                                   washes: [CristalWash(rx: 230, ry: 230, x: 30, y: 300), CristalWash(rx: 210, ry: 210, x: 380, y: 640)])
    static let ocean = CristalSeed(id: "ocean", primary: "00727B", secondary: "1F5FB8", accent: "14A9B8", bg: "ECF7F8", na: "B5E9EC", nb: "C5DAF8",
                                   ink: "07191C", ink2: "48605F", rule: "D2E6E8", track: "CDE0E3", cat: 0.12, gray: 0, panel: "FFFFFF", radius: 26,
                                   washes: [CristalWash(rx: 340, ry: 150, x: 196, y: 190), CristalWash(rx: 230, ry: 230, x: 50, y: 730)])
    static let peche = CristalSeed(id: "peche", primary: "A04C1B", secondary: "F0A56B", accent: "E07B32", bg: "FCF4EC", na: "FFDCC2", nb: "FFE9C6",
                                   ink: "2A170B", ink2: "6B5747", rule: "F1E0D0", track: "EBDAC9", cat: 0.12, gray: 0, panel: "FFFFFF", radius: 28,
                                   washes: [CristalWash(rx: 220, ry: 220, x: 330, y: 150), CristalWash(rx: 240, ry: 240, x: 80, y: 700)])
    static let foret = CristalSeed(id: "foret", primary: "1F6B5C", secondary: "6FA898", accent: "2B9A7C", bg: "EEF5F2", na: "BFE1D4", nb: "CEE8E6",
                                   ink: "0C1C18", ink2: "4A5F59", rule: "D5E4DE", track: "CFDFD9", cat: 0.14, gray: 0, panel: "FFFFFF", radius: 26,
                                   washes: [CristalWash(rx: 230, ry: 230, x: 60, y: 180), CristalWash(rx: 220, ry: 220, x: 360, y: 700)])
    static let sable = CristalSeed(id: "sable", primary: "7B5D34", secondary: "C8A97A", accent: "B5813A", bg: "F8F4EC", na: "EFE0C4", nb: "F6E8D6",
                                   ink: "241C10", ink2: "665A48", rule: "E8DFCF", track: "E3D9C7", cat: 0.18, gray: 0, panel: "FFFDF9", radius: 26,
                                   washes: [CristalWash(rx: 230, ry: 230, x: 350, y: 120), CristalWash(rx: 210, ry: 210, x: 20, y: 540)])
    // La nappe 1 de la maquette est un dégradé linéaire en biais : ici une large nappe radiale en haut à gauche.
    static let graphite = CristalSeed(id: "graphite", primary: "3D4756", secondary: "8E99A8", accent: "56789F", bg: "F1F3F6", na: "DDE2E9", nb: "E3E8F0",
                                      ink: "12161C", ink2: "545D6A", rule: "DCE0E7", track: "D5DAE2", cat: 0.10, gray: 0.30, panel: "FFFFFF", radius: 22,
                                      washes: [CristalWash(rx: 300, ry: 260, x: 60, y: 60), CristalWash(rx: 250, ry: 250, x: 320, y: 800)])
}

/// Les jetons Cristal d'une couleur de l'app, en clair et en sombre (HEX sans dièse, majuscules).
struct CristalPalette {
    /// Jetons : bg, na, nb, ink, ink2, rule, rule2, primary, onPrimary, secondary, accent, tint, tint2, track, grid, go, dot,
    /// panelSolid, sheet, well, well2, ok, plus « cat.<clé> » et « strong.<clé> » pour chaque catégorie.
    let light: [String: String]
    let dark: [String: String]
    let seedID: String
    let radius: CGFloat
    let washes: [CristalWash]
    /// Base des catégories mêlée à la couleur d'action.
    fileprivate let catMix: Double
    fileprivate let catGray: Double

    static let categoryKeys = ["nut", "fit", "pla", "hab", "bud", "pro", "pas", "prot", "gluc", "lip", "travail", "rdv"]
    static let tokenNames = ["bg", "na", "nb", "ink", "ink2", "rule", "rule2", "primary", "onPrimary", "secondary", "accent", "tint", "tint2",
                             "track", "grid", "go", "dot", "panelSolid", "sheet", "well", "well2", "ok"]

    private static let cache: [AppStyleID: CristalPalette] = Dictionary(uniqueKeysWithValues: AppStyleID.allCases.map { ($0, build($0)) })

    /// Palette d'une couleur de l'app, calculée une seule fois.
    static func of(_ id: AppStyleID) -> CristalPalette {
        cache[id] ?? build(id)
    }

    // MARK: Accès

    /// HEX d'un jeton (« bg », « cat.nut », « strong.nut »…) ; « 000000 » si le nom est inconnu.
    func hex(_ token: String, dark isDark: Bool) -> String {
        (isDark ? dark : light)[token] ?? "000000"
    }

    private func color(_ token: String) -> Color { Color(light: hex(token, dark: false), dark: hex(token, dark: true)) }

    var bgColor: Color { color("bg") }
    var naColor: Color { color("na") }
    var nbColor: Color { color("nb") }
    var inkColor: Color { color("ink") }
    var ink2Color: Color { color("ink2") }
    var ruleColor: Color { color("rule") }
    var rule2Color: Color { color("rule2") }
    var primaryColor: Color { color("primary") }
    var onPrimaryColor: Color { color("onPrimary") }
    var secondaryColor: Color { color("secondary") }
    var accentColor: Color { color("accent") }
    var tintColor: Color { color("tint") }
    var tint2Color: Color { color("tint2") }
    var trackColor: Color { color("track") }
    var gridColor: Color { color("grid") }
    var goColor: Color { color("go") }
    var dotColor: Color { color("dot") }
    var panelSolidColor: Color { color("panelSolid") }
    var sheetColor: Color { color("sheet") }
    var wellColor: Color { color("well") }
    var well2Color: Color { color("well2") }
    var okColor: Color { color("ok") }

    /// Couleur d'une catégorie Cristal par clé (« nut », « fit »…).
    func cat(_ key: String) -> Color { color("cat." + key) }
    func strong(key: String) -> Color { color("strong." + key) }

    // MARK: Couleurs de catégorie de l'app

    /// Catégorie de l'app (HEX) traduite en Cristal : (clair, sombre). Un HEX connu prend la base de la référence, un HEX inconnu
    /// sert de base ; un HEX invalide se replie sur la couleur d'action.
    func categoryHex(_ hex: String) -> (light: String, dark: String) {
        let primaryLight = light["primary"] ?? "000000"
        let card = dark["panelSolid"] ?? "000000"
        // Gardé en mémoire : les écrans redemandent la même couleur à chaque dessin.
        let key = primaryLight + card + seedID + hex
        Self.translatedLock.lock()
        defer { Self.translatedLock.unlock() }
        if let known = Self.translated[key] { return known }
        let base = Self.baseCategory(hex) ?? primaryLight
        let mixed = Hx.mix(base, primaryLight, catMix)
        // Teintes neutres : le gris est l'encre 2 éclaircie en clair, un gris fixe en sombre.
        let mixedLight = catGray > 0 ? Hx.mix(mixed, Hx.mix(light["ink2"] ?? "000000", "FFFFFF", 0.15), catGray) : mixed
        let mixedDark = catGray > 0 ? Hx.mix(mixed, Self.darkGray, catGray) : mixed
        let result = (light: Hx.fit(mixedLight, light["panelSolid"] ?? "FFFFFF", 3.2), dark: Hx.lift(Hx.mix(mixedDark, "FFFFFF", 0.16), card, 5.0))
        Self.translated[key] = result
        return result
    }

    /// Le gris mêlé aux catégories en sombre (tokensDark de cristal.js).
    private static let darkGray = "9AA3B0"
    private static let translatedLock = NSLock()
    private static var translated: [String: (light: String, dark: String)] = [:]

    /// Variante « forte » (texte) : en clair assombrie jusqu'à 4,6:1 sur blanc, en sombre identique à la catégorie.
    func strongHex(_ hex: String) -> (light: String, dark: String) {
        let c = categoryHex(hex)
        return (Hx.fit(c.light, "FFFFFF", 4.6), c.dark)
    }

    func category(_ hex: String) -> Color {
        let c = categoryHex(hex)
        return Color(light: c.light, dark: c.dark)
    }

    func strong(_ hex: String) -> Color {
        let c = strongHex(hex)
        return Color(light: c.light, dark: c.dark)
    }

    /// Les HEX de catégorie de l'app qui ont une base dans CATS0.
    private static func baseCategory(_ hex: String) -> String? {
        guard let h = Hx.normalized(hex) else { return nil }
        guard let key = knownCategories[h] else { return h }
        return cats0[key] ?? h
    }

    private static let knownCategories = ["F08A24": "nut", "E5484D": "fit", "3366FF": "pla", "7FA33A": "hab", "2F8F7A": "bud", "6B7280": "pro", "12A4B5": "pas"]

    private static let cats0: [String: String] = ["nut": "C36F25", "fit": "DF5661", "pla": "4385DB", "hab": "49961D", "bud": "1D9672", "pro": "79849A",
                                                  "pas": "1E929F", "prot": "DF5661", "gluc": "A37F12", "lip": "4385DB", "travail": "926FE4", "rdv": "DD4DA1"]

    // MARK: Association couleur de l'app → graine

    /// Graine et « teinte principale » (sa couleur d'action est celle de la graine). Pas de `default` : une nouvelle couleur casse la compilation.
    private static func seedFor(_ id: AppStyleID) -> (seed: CristalSeed, main: Bool) {
        switch id {
        case .cobalt: return (.ocean, false)
        case .sapphire: return (.saphir, true)
        case .iceBlue: return (.saphir, false)
        case .aqua: return (.ocean, true)
        case .jade: return (.foret, true)
        case .pistachio: return (.sauge, true)
        case .olive: return (.sauge, false)
        case .amber: return (.peche, true)
        case .ruby: return (.rose, false)
        case .rose: return (.rose, true)
        case .orchid: return (.lavande, false)
        case .amethyst: return (.lavande, true)
        case .sable: return (.sable, true)
        case .slate: return (.graphite, true)
        }
    }

    // MARK: Calcul

    private static func build(_ id: AppStyleID) -> CristalPalette {
        let style = AppStyle.style(id)
        let (seed, main) = seedFor(id)
        let primary = main ? seed.primary : Hx.fitSelf(style.accentLight)

        // Clair (tokens de cristal.js ; panneau blanc).
        let panel = seed.panel
        // Teintes neutres : le gris des catégories est l'encre 2 éclaircie (comme tokens() de cristal.js).
        let gray = Hx.mix(seed.ink2, "FFFFFF", 0.15)
        var l: [String: String] = [
            "bg": seed.bg, "na": seed.na, "nb": seed.nb, "ink": seed.ink, "ink2": seed.ink2, "rule": seed.rule,
            "rule2": Hx.mix(seed.rule, seed.ink2, 0.35), "primary": primary, "onPrimary": "FFFFFF", "secondary": seed.secondary,
            "accent": Hx.fit(seed.accent, panel, 3.0), "tint": Hx.mix(primary, "FFFFFF", 0.90), "tint2": Hx.mix(primary, "FFFFFF", 0.86),
            "track": seed.track, "grid": Hx.mix(seed.track, "FFFFFF", 0.45), "go": Hx.mix(seed.ink2, "FFFFFF", 0.12),
            "dot": Hx.mix(seed.track, seed.ink2, 0.22), "panelSolid": panel, "sheet": Hx.mix(panel, seed.bg, 0.12),
            "well": Hx.mix(seed.bg, seed.track, 0.35), "well2": Hx.mix(seed.bg, primary, 0.10), "ok": Hx.fit("23835F", panel, 4.5),
        ]
        for k in categoryKeys {
            var base = Hx.mix(cats0[k] ?? primary, primary, seed.cat)
            if seed.gray > 0 { base = Hx.mix(base, gray, seed.gray) }
            let c = Hx.fit(base, panel, k == "gluc" ? 3.0 : 3.2)
            l["cat." + k] = c
            l["strong." + k] = Hx.fit(c, "FFFFFF", 4.6)
        }

        // Sombre : fond, carte et couleur d'action viennent d'AppStyle ; le reste suit cristal_reference.js.
        let bg = style.screenDark, card = style.cardDark, dPrimary = style.accentDark
        let hue = Hx.hue(style.accentLight)
        // A neutral color keeps only part of its hue's saturation, as in AppStyle.palette (Graphite: 0.22).
        let saturation = seed.gray > 0 ? (seed.gray > 0.5 ? 0 : 0.22) : 1
        let darkInk = Hx.fromHSL(hue, 0.5 * saturation, 0.07)
        let onPrimary = Hx.contrast(darkInk, dPrimary) >= Hx.contrast("FFFFFF", dPrimary) ? darkInk : "FFFFFF"
        let ink = Hx.mix("FFFFFF", dPrimary, 0.05), ink2 = Hx.mix(ink, card, 0.36)
        var d: [String: String] = [
            "bg": bg, "na": Hx.mix(bg, seed.secondary, 0.32), "nb": Hx.mix(bg, primary, 0.46), "ink": ink, "ink2": ink2,
            "rule": Hx.mix(card, "FFFFFF", 0.10), "rule2": Hx.mix(card, "FFFFFF", 0.22), "primary": dPrimary, "onPrimary": onPrimary,
            "secondary": Hx.lift(seed.secondary, card, 4.5), "accent": Hx.lift(seed.accent, card, 4.5),
            "tint": Hx.mix(card, dPrimary, 0.13), "tint2": Hx.mix(card, dPrimary, 0.19), "track": Hx.mix(card, "FFFFFF", 0.13),
            "grid": Hx.mix(card, "FFFFFF", 0.07), "go": Hx.mix(ink2, card, 0.35), "dot": Hx.mix(card, "FFFFFF", 0.24),
            "panelSolid": card, "sheet": Hx.mix(card, "FFFFFF", 0.03), "well": Hx.mix(bg, "FFFFFF", 0.06),
            "well2": Hx.mix(bg, dPrimary, 0.10), "ok": "5FD3A0",
        ]
        for k in categoryKeys {
            var base = Hx.mix(cats0[k] ?? primary, primary, seed.cat)
            if seed.gray > 0 { base = Hx.mix(base, darkGray, seed.gray) }
            let c = Hx.lift(Hx.mix(base, "FFFFFF", 0.16), card, 5.0)
            d["cat." + k] = c
            d["strong." + k] = c
        }
        return CristalPalette(light: l, dark: d, seedID: seed.id, radius: CGFloat(seed.radius), washes: seed.washes, catMix: seed.cat, catGray: seed.gray)
    }

    /// Rapport de contraste WCAG entre deux HEX.
    static func contrast(_ a: String, _ b: String) -> Double { Hx.contrast(a, b) }
}

/// Calcul de couleur sur des entiers 0…255, identique à C.mix / C.lum / C.cr / C.fit / C.lift de cristal.js.
private enum Hx {
    /// « RRGGBB » en majuscules, sans dièse ; nil si le texte n'est pas un HEX à 6 chiffres.
    static func normalized(_ s: String) -> String? {
        var v = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if v.hasPrefix("#") { v.removeFirst() }
        guard v.count == 6, v.allSatisfy(\.isHexDigit) else { return nil }
        return v
    }

    static func rgb(_ hex: String) -> [Int] {
        let n = Int(UInt64(normalized(hex) ?? "000000", radix: 16) ?? 0)
        return [(n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF]
    }

    static func hex(_ c: [Double]) -> String {
        let b = c.map { Int(min(255, max(0, $0)).rounded()) }
        return String(format: "%02X%02X%02X", b[0], b[1], b[2])
    }

    static func mix(_ a: String, _ b: String, _ t: Double) -> String {
        let x = rgb(a), y = rgb(b)
        return hex((0..<3).map { k in let v = Double(x[k]); return v + (Double(y[k]) - v) * t })
    }

    static func lum(_ h: String) -> Double {
        let c = rgb(h).map { v -> Double in
            let s = Double(v) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }

    static func contrast(_ a: String, _ b: String) -> Double {
        let x = lum(a), y = lum(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Assombrit jusqu'au contraste voulu (au plus 40 tours, re-quantifié en HEX à chaque tour comme le JS).
    static func fit(_ start: String, _ bg: String, _ minimum: Double) -> String {
        var h = start, k = 0
        while contrast(h, bg) < minimum && k < 40 { k += 1; h = mix(h, "000000", 0.05) }
        return h
    }

    static func lift(_ start: String, _ bg: String, _ minimum: Double) -> String {
        var h = start, k = 0
        while contrast(h, bg) < minimum && k < 40 { k += 1; h = mix(h, "FFFFFF", 0.05) }
        return h
    }

    /// Assombrit tant que la couleur se lit mal sur sa propre teinte (onglet actif, bouton teinté).
    static func fitSelf(_ start: String) -> String {
        var h = start, k = 0
        while contrast(h, mix(h, "FFFFFF", 0.86)) < 4.6 && k < 40 { k += 1; h = mix(h, "000000", 0.05) }
        return h
    }

    /// Teinte en degrés (0…360), comme C.hsl(...).h.
    static func hue(_ hex: String) -> Double {
        let c = rgb(hex).map { Double($0) / 255 }
        let r = c[0], g = c[1], b = c[2]
        let hi = max(r, g, b), lo = min(r, g, b), d = hi - lo
        guard d != 0 else { return 0 }
        var h: Double
        if hi == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if hi == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        h *= 60
        if h < 0 { h += 360 }
        return h
    }

    /// Comme C.fromHsl(h, s, l) : h en degrés, s et l entre 0 et 1.
    static func fromHSL(_ h: Double, _ s: Double, _ l: Double) -> String {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let p: (Double, Double, Double)
        switch Int((h / 60).rounded(.down)) % 6 {
        case 0: p = (c, x, 0)
        case 1: p = (x, c, 0)
        case 2: p = (0, c, x)
        case 3: p = (0, x, c)
        case 4: p = (x, 0, c)
        default: p = (c, 0, x)
        }
        return hex([(p.0 + m) * 255, (p.1 + m) * 255, (p.2 + m) * 255])
    }
}
