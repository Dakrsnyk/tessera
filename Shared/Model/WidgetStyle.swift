import Foundation

// MARK: - Choices

/// How the main content of a data widget is arranged.
enum LayoutKind: String, Codable, CaseIterable, Identifiable {
    case auto, vertical, horizontal, minimal, centered, split, data, list, progress, graph, cards
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .vertical: "Vertical"
        case .horizontal: "Horizontal"
        case .minimal: "Minimal"
        case .centered: "Focus"
        case .split: "Deux colonnes"
        case .data: "Données"
        case .list: "Liste"
        case .progress: "Progression"
        case .graph: "Graphique"
        case .cards: "Cartes"
        }
    }

    var symbol: String {
        switch self {
        case .auto: "wand.and.stars"
        case .vertical: "rectangle.split.1x2"
        case .horizontal: "rectangle.split.3x1"
        case .minimal: "textformat.size.larger"
        case .centered: "circle.dashed.inset.filled"
        case .split: "rectangle.split.2x1"
        case .data: "tablecells"
        case .list: "list.bullet.rectangle"
        case .progress: "chart.bar.fill"
        case .graph: "chart.xyaxis.line"
        case .cards: "square.grid.2x2"
        }
    }

    var summary: String {
        switch self {
        case .auto: "La disposition prévue pour ce widget."
        case .vertical: "Titre, valeur, puis le graphique en dessous."
        case .horizontal: "Icône, valeur et progression sur une ligne."
        case .minimal: "Une seule information, très grande."
        case .centered: "L'icône et la valeur au centre, comme un cadran."
        case .split: "La valeur d'un côté, le détail de l'autre."
        case .data: "Plusieurs statistiques, bien alignées."
        case .list: "Les lignes d'abord, la valeur en en-tête."
        case .progress: "Une grande barre de progression."
        case .graph: "La valeur et un grand graphique."
        case .cards: "Chaque information sur sa petite carte."
        }
    }
}

/// What kind of numbers a widget draws, which decides the charts it can use.
enum ChartFamily {
    /// Values over time (a week, a month).
    case series
    /// One value toward a goal.
    case progress
    /// Parts of a whole (macros, spending categories).
    case segments
    case none
}

/// How numbers are drawn when the widget has a series, a progress or parts of a whole.
enum ChartKind: String, Codable, CaseIterable, Identifiable {
    case auto, line, area, bars, histogram, dots, sparkline, evolution, comparison, ring, pie, gauge, progress
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .line: "Ligne"
        case .area: "Aire"
        case .bars: "Barres"
        case .histogram: "Histogramme"
        case .dots: "Points"
        case .sparkline: "Sparkline"
        case .evolution: "Évolution"
        case .comparison: "Comparaison"
        case .ring: "Anneau"
        case .pie: "Cercle"
        case .gauge: "Jauge"
        case .progress: "Barre"
        }
    }

    var symbol: String {
        switch self {
        case .auto: "wand.and.stars"
        case .line: "chart.xyaxis.line"
        case .area: "chart.line.uptrend.xyaxis"
        case .bars: "chart.bar.fill"
        case .histogram: "chart.bar.xaxis"
        case .dots: "circle.grid.3x3.fill"
        case .sparkline: "waveform.path"
        case .evolution: "arrow.up.right"
        case .comparison: "equal.square"
        case .ring: "circle.circle"
        case .pie: "chart.pie.fill"
        case .gauge: "gauge.with.dots.needle.33percent"
        case .progress: "minus.rectangle"
        }
    }

    /// The charts that make sense for a kind of numbers, "Auto" first.
    static func options(for family: ChartFamily) -> [ChartKind] {
        switch family {
        case .series: [.auto, .line, .area, .bars, .histogram, .dots, .sparkline, .evolution, .comparison]
        case .progress: [.auto, .ring, .pie, .gauge, .progress, .comparison]
        case .segments: [.auto, .progress, .ring, .pie, .bars]
        case .none: [.auto]
        }
    }
}

enum Density: String, Codable, CaseIterable, Identifiable {
    case compact, balanced, dense
    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "Aéré"
        case .balanced: "Équilibré"
        case .dense: "Dense"
        }
    }

    var summary: String {
        switch self {
        case .compact: "Peu d'informations, très lisible."
        case .balanced: "Équilibre entre informations et espace."
        case .dense: "Plus d'informations dans le même widget."
        }
    }
}

enum BorderKind: String, Codable, CaseIterable, Identifiable {
    case none, solid, dashed, dotted, double, glow, gradient
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Aucune"
        case .solid: "Pleine"
        case .dashed: "Tirets"
        case .dotted: "Points"
        case .double: "Double"
        case .glow: "Lumineuse"
        case .gradient: "Dégradé"
        }
    }
}

enum DepthKind: String, Codable, CaseIterable, Identifiable {
    case none, soft, strong, glow, floating, embossed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Aucune"
        case .soft: "Légère"
        case .strong: "Forte"
        case .glow: "Lueur"
        case .floating: "Flottant"
        case .embossed: "Relief"
        }
    }

    var summary: String {
        switch self {
        case .none: "Tout est à plat."
        case .soft: "Une ombre douce sous les chiffres et les cartes."
        case .strong: "Une ombre marquée, plus de contraste."
        case .glow: "Les chiffres et les graphiques brillent."
        case .floating: "Le contenu semble flotter au-dessus du fond."
        case .embossed: "Un léger relief, comme gravé."
        }
    }
}

/// The shape of what sits inside the widget: iOS draws the widget's own outline, Tessera shapes the rest.
enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case theme, rounded, soft, square, capsule, panel
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Style"
        case .rounded: "Arrondi"
        case .soft: "Doux"
        case .square: "Carré"
        case .capsule: "Capsule"
        case .panel: "Panneau"
        }
    }

    var summary: String {
        switch self {
        case .theme: "Les formes prévues par le style."
        case .rounded: "Coins arrondis classiques."
        case .soft: "Coins très arrondis, forme douce."
        case .square: "Coins nets, presque carrés."
        case .capsule: "Barres, cartes et boutons en capsule."
        case .panel: "Le contenu posé sur une carte intérieure."
        }
    }
}

/// The frame around the widget's icons.
enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case theme, plain, circle, square, outline, none
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Style"
        case .plain: "Simple"
        case .circle: "Pastille"
        case .square: "Carré"
        case .outline: "Contour"
        case .none: "Aucune"
        }
    }
}

/// The drawing of the icons themselves (SF Symbols variants, so every icon of the widget matches).
enum IconFamily: String, Codable, CaseIterable, Identifiable {
    case theme, filled, outlined, circled, squared
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Style"
        case .filled: "Pleines"
        case .outlined: "Traits"
        case .circled: "Rondes"
        case .squared: "Carrées"
        }
    }
}

enum IconPosition: String, Codable, CaseIterable, Identifiable {
    case leading, trailing, top
    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: "À gauche"
        case .trailing: "À droite"
        case .top: "En haut"
        }
    }
}

enum TitleCase: String, Codable, CaseIterable, Identifiable {
    case theme, upper, normal, lower
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Style"
        case .upper: "MAJUSCULES"
        case .normal: "Normal"
        case .lower: "minuscules"
        }
    }
}

enum WeightChoice: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Fin"
        case .regular: "Normal"
        case .medium: "Moyen"
        case .semibold: "Demi-gras"
        case .bold: "Gras"
        case .heavy: "Épais"
        case .black: "Noir"
        }
    }
}

enum GradientDirection: String, Codable, CaseIterable, Identifiable {
    case down, diagonal, across, up, radial
    var id: String { rawValue }

    var title: String {
        switch self {
        case .down: "Vers le bas"
        case .diagonal: "En diagonale"
        case .across: "De gauche à droite"
        case .up: "Vers le haut"
        case .radial: "Depuis le centre"
        }
    }

    var symbol: String {
        switch self {
        case .down: "arrow.down"
        case .diagonal: "arrow.down.right"
        case .across: "arrow.right"
        case .up: "arrow.up"
        case .radial: "circle.dotted.circle"
        }
    }
}

enum TextureKind: String, Codable, CaseIterable, Identifiable {
    case none, grain, paper, dots, grid, lines, diagonal, noise
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Aucune"
        case .grain: "Grain"
        case .paper: "Papier"
        case .dots: "Points"
        case .grid: "Grille"
        case .lines: "Lignes"
        case .diagonal: "Rayures"
        case .noise: "Bruit"
        }
    }
}

/// A typography preset: several text settings at once.
struct TypePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let font: FontChoice
    let numberWeight: WeightChoice
    let titleWeight: WeightChoice
    let valueScale: Double
    let titleCase: TitleCase
    let tracking: Double

    static let all: [TypePreset] = [
        TypePreset(id: "system", name: "Système", font: .standard, numberWeight: .semibold, titleWeight: .semibold, valueScale: 1, titleCase: .upper, tracking: 0),
        TypePreset(id: "display", name: "Affiche", font: .standard, numberWeight: .black, titleWeight: .bold, valueScale: 1.2, titleCase: .upper, tracking: 0.5),
        TypePreset(id: "light", name: "Léger", font: .standard, numberWeight: .light, titleWeight: .regular, valueScale: 1.1, titleCase: .normal, tracking: 0),
        TypePreset(id: "friendly", name: "Arrondi", font: .rounded, numberWeight: .bold, titleWeight: .semibold, valueScale: 1, titleCase: .normal, tracking: 0),
        TypePreset(id: "editorial", name: "Éditorial", font: .serif, numberWeight: .regular, titleWeight: .medium, valueScale: 1.1, titleCase: .upper, tracking: 1.2),
        TypePreset(id: "classic", name: "Classique", font: .serif, numberWeight: .black, titleWeight: .semibold, valueScale: 1.15, titleCase: .normal, tracking: 0),
        TypePreset(id: "code", name: "Code", font: .mono, numberWeight: .medium, titleWeight: .medium, valueScale: 0.95, titleCase: .lower, tracking: 0),
        TypePreset(id: "tech", name: "Technique", font: .mono, numberWeight: .light, titleWeight: .regular, valueScale: 1, titleCase: .upper, tracking: 1.5),
    ]
}

/// Two colors, a direction and an intensity: the person's own gradient.
struct GradientSpec: Codable, Hashable {
    var startHex: String
    var endHex: String
    var direction: GradientDirection = .diagonal
    /// 0 = almost flat, 1 = the full contrast between the two colors.
    var intensity: Double = 1

    init(startHex: String, endHex: String, direction: GradientDirection = .diagonal, intensity: Double = 1) {
        self.startHex = startHex
        self.endHex = endHex
        self.direction = direction
        self.intensity = intensity
    }

    enum CodingKeys: String, CodingKey { case startHex, endHex, direction, intensity }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startHex = try c.decode(String.self, forKey: .startHex)
        endHex = try c.decode(String.self, forKey: .endHex)
        direction = (try? c.decodeIfPresent(GradientDirection.self, forKey: .direction)) ?? .diagonal
        intensity = (try? c.decodeIfPresent(Double.self, forKey: .intensity)) ?? 1
    }
}

// MARK: - The style

/// Everything about a widget's look beyond its theme. Each setting is optional: left alone it follows
/// the chosen style (the theme), changed it wins. A style (theme) brings its own starting values.
struct StyleOptions: Codable, Hashable {
    // Colors (nil: from the style).
    var textHex: String?
    var secondaryHex: String?
    var numberHex: String?
    var iconHex: String?
    var chartHex: String?
    var positiveHex: String?
    var negativeHex: String?
    /// Colors of individual lines (macros, categories…), by line id, or "seg:<label>" for parts of a whole.
    var rowColors: [String: String] = [:]

    // Background.
    var gradient: GradientSpec?
    var texture: TextureKind = .none
    var textureOpacity: Double = 0.5
    /// How much a photo is darkened so the text stays readable (nil: 0.28).
    var veil: Double?

    // Border.
    var border: BorderKind = .none
    var borderHex: String?
    var borderWidth: Double = 2
    var borderOpacity: Double = 1

    // Depth, inside the widget (iOS draws the widget's own edge and doesn't let apps shade it).
    var depth: DepthKind = .none
    var shadowHex: String?
    var shadowRadius: Double = 8
    var shadowOpacity: Double = 0.35
    var shadowOffset: Double = 3

    // Shape.
    var shape: ShapeKind = .theme

    // Typography.
    var valueScale: Double = 1
    var titleScale: Double = 1
    var textScale: Double = 1
    var numberWeight: WeightChoice?
    var titleWeight: WeightChoice?
    var tracking: Double = 0
    var titleCase: TitleCase = .theme
    var monospacedNumbers: Bool = true

    // Icons.
    var iconStyle: IconStyle = .theme
    var iconFamily: IconFamily = .theme
    var iconScale: Double = 1
    var iconPosition: IconPosition = .leading

    // Layout, chart and density.
    var layout: LayoutKind = .auto
    var chart: ChartKind = .auto
    var chartThickness: Double = 1
    var chartFill: Bool = true
    var chartValues: Bool = false
    var density: Density = .balanced

    /// Parts of the widget hidden by the person: "icon", "title", "value", "caption", "detail", "visual",
    /// "rows", "buttons", "footnote", or one line: "row:<id>".
    var hidden: Set<String> = []

    init() {}

    var isDefault: Bool { self == StyleOptions() }

    enum CodingKeys: String, CodingKey {
        case textHex, secondaryHex, numberHex, iconHex, chartHex, positiveHex, negativeHex, rowColors
        case gradient, texture, textureOpacity, veil, border, borderHex, borderWidth, borderOpacity
        case depth, shadowHex, shadowRadius, shadowOpacity, shadowOffset, shape
        case valueScale, titleScale, textScale, numberWeight, titleWeight, tracking, titleCase, monospacedNumbers
        case iconStyle, iconFamily, iconScale, iconPosition, layout, chart, chartThickness, chartFill, chartValues, density, hidden
    }

    /// Tolerant: a setting a newer version added, or a value it no longer knows, falls back to its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = StyleOptions()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        func optional<T: Decodable>(_ key: CodingKeys, _ type: T.Type) -> T? { (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil }
        textHex = optional(.textHex, String.self)
        secondaryHex = optional(.secondaryHex, String.self)
        numberHex = optional(.numberHex, String.self)
        iconHex = optional(.iconHex, String.self)
        chartHex = optional(.chartHex, String.self)
        positiveHex = optional(.positiveHex, String.self)
        negativeHex = optional(.negativeHex, String.self)
        rowColors = value(.rowColors, d.rowColors)
        gradient = optional(.gradient, GradientSpec.self)
        texture = value(.texture, d.texture)
        textureOpacity = value(.textureOpacity, d.textureOpacity)
        veil = optional(.veil, Double.self)
        border = value(.border, d.border)
        borderHex = optional(.borderHex, String.self)
        borderWidth = value(.borderWidth, d.borderWidth)
        borderOpacity = value(.borderOpacity, d.borderOpacity)
        depth = value(.depth, d.depth)
        shadowHex = optional(.shadowHex, String.self)
        shadowRadius = value(.shadowRadius, d.shadowRadius)
        shadowOpacity = value(.shadowOpacity, d.shadowOpacity)
        shadowOffset = value(.shadowOffset, d.shadowOffset)
        shape = value(.shape, d.shape)
        valueScale = value(.valueScale, d.valueScale)
        titleScale = value(.titleScale, d.titleScale)
        textScale = value(.textScale, d.textScale)
        numberWeight = optional(.numberWeight, WeightChoice.self)
        titleWeight = optional(.titleWeight, WeightChoice.self)
        tracking = value(.tracking, d.tracking)
        titleCase = value(.titleCase, d.titleCase)
        monospacedNumbers = value(.monospacedNumbers, d.monospacedNumbers)
        iconStyle = value(.iconStyle, d.iconStyle)
        iconFamily = value(.iconFamily, d.iconFamily)
        iconScale = value(.iconScale, d.iconScale)
        iconPosition = value(.iconPosition, d.iconPosition)
        layout = value(.layout, d.layout)
        chart = value(.chart, d.chart)
        chartThickness = value(.chartThickness, d.chartThickness)
        chartFill = value(.chartFill, d.chartFill)
        chartValues = value(.chartValues, d.chartValues)
        density = value(.density, d.density)
        hidden = value(.hidden, d.hidden)
    }

    /// These settings drawn over a style's own starting values: what the person changed wins,
    /// what they left alone comes from the style.
    func over(_ base: StyleOptions) -> StyleOptions {
        let d = StyleOptions()
        var r = base
        func pick<T: Equatable>(_ mine: T, _ fallback: T, _ neutral: T) -> T { mine != neutral ? mine : fallback }
        r.textHex = textHex ?? base.textHex
        r.secondaryHex = secondaryHex ?? base.secondaryHex
        r.numberHex = numberHex ?? base.numberHex
        r.iconHex = iconHex ?? base.iconHex
        r.chartHex = chartHex ?? base.chartHex
        r.positiveHex = positiveHex ?? base.positiveHex
        r.negativeHex = negativeHex ?? base.negativeHex
        r.rowColors = base.rowColors.merging(rowColors) { _, mine in mine }
        r.gradient = gradient ?? base.gradient
        r.texture = pick(texture, base.texture, d.texture)
        r.textureOpacity = pick(textureOpacity, base.textureOpacity, d.textureOpacity)
        r.veil = veil ?? base.veil
        r.border = pick(border, base.border, d.border)
        r.borderHex = borderHex ?? base.borderHex
        r.borderWidth = pick(borderWidth, base.borderWidth, d.borderWidth)
        r.borderOpacity = pick(borderOpacity, base.borderOpacity, d.borderOpacity)
        r.depth = pick(depth, base.depth, d.depth)
        r.shadowHex = shadowHex ?? base.shadowHex
        r.shadowRadius = pick(shadowRadius, base.shadowRadius, d.shadowRadius)
        r.shadowOpacity = pick(shadowOpacity, base.shadowOpacity, d.shadowOpacity)
        r.shadowOffset = pick(shadowOffset, base.shadowOffset, d.shadowOffset)
        r.shape = pick(shape, base.shape, d.shape)
        r.valueScale = pick(valueScale, base.valueScale, d.valueScale)
        r.titleScale = pick(titleScale, base.titleScale, d.titleScale)
        r.textScale = pick(textScale, base.textScale, d.textScale)
        r.numberWeight = numberWeight ?? base.numberWeight
        r.titleWeight = titleWeight ?? base.titleWeight
        r.tracking = pick(tracking, base.tracking, d.tracking)
        r.titleCase = pick(titleCase, base.titleCase, d.titleCase)
        r.monospacedNumbers = pick(monospacedNumbers, base.monospacedNumbers, d.monospacedNumbers)
        r.iconStyle = pick(iconStyle, base.iconStyle, d.iconStyle)
        r.iconFamily = pick(iconFamily, base.iconFamily, d.iconFamily)
        r.iconScale = pick(iconScale, base.iconScale, d.iconScale)
        r.iconPosition = pick(iconPosition, base.iconPosition, d.iconPosition)
        r.layout = pick(layout, base.layout, d.layout)
        r.chart = pick(chart, base.chart, d.chart)
        r.chartThickness = pick(chartThickness, base.chartThickness, d.chartThickness)
        r.chartFill = pick(chartFill, base.chartFill, d.chartFill)
        r.chartValues = pick(chartValues, base.chartValues, d.chartValues)
        r.density = pick(density, base.density, d.density)
        r.hidden = base.hidden.union(hidden)
        return r
    }

    /// Settings that need Premium: the person's own colors, the advanced backgrounds, borders and depth.
    var premiumFeatures: [String] {
        var features: [String] = []
        let colors = [textHex, secondaryHex, numberHex, iconHex, chartHex, positiveHex, negativeHex, borderHex, shadowHex]
        if colors.contains(where: { $0 != nil }) || !rowColors.isEmpty { features.append("Couleurs personnalisées") }
        if gradient != nil { features.append("Dégradé personnalisé") }
        if texture != .none { features.append("Texture") }
        if border != .none { features.append("Bordure") }
        if depth != .none { features.append("Ombre et profondeur") }
        return features
    }

    /// The same style without its Premium settings (layout, shapes, text and icons stay).
    func withoutPremium() -> StyleOptions {
        var copy = self
        copy.textHex = nil
        copy.secondaryHex = nil
        copy.numberHex = nil
        copy.iconHex = nil
        copy.chartHex = nil
        copy.positiveHex = nil
        copy.negativeHex = nil
        copy.borderHex = nil
        copy.shadowHex = nil
        copy.rowColors = [:]
        copy.gradient = nil
        copy.texture = .none
        copy.border = .none
        copy.depth = .none
        return copy
    }

    /// Only the look, without what belongs to the content (the lines the person hid).
    var look: StyleOptions {
        var copy = self
        copy.hidden = []
        return copy
    }

    func isHidden(_ part: String) -> Bool { hidden.contains(part) }
}

// MARK: - Complete themes

/// A complete theme: a style, colors, a background and every setting at once. Only a starting point:
/// each setting can then be changed on its own.
struct StylePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let themeID: ThemeID
    let accentHex: String
    let background: BackgroundStyle
    let font: FontChoice
    let style: StyleOptions

    /// The design with this theme, its content and hidden lines untouched.
    func applied(to design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.themeID = themeID
        copy.accentHex = accentHex
        copy.background = background
        copy.font = font
        var look = style
        look.hidden = design.style.hidden
        copy.style = look
        return copy
    }

    var isPremium: Bool {
        var probe = WidgetDesign(kind: .note)
        probe = applied(to: probe)
        return probe.usesPremiumFeatures
    }

    private static func make(_ id: String, _ name: String, _ summary: String, theme: ThemeID, accent: String,
                             background: BackgroundStyle = .theme, font: FontChoice = .theme,
                             _ change: (inout StyleOptions) -> Void = { _ in }) -> StylePreset {
        var options = StyleOptions()
        change(&options)
        return StylePreset(id: id, name: name, summary: summary, themeID: theme, accentHex: accent, background: background, font: font, style: options)
    }

    static let all: [StylePreset] = [
        make("midnight", "Midnight", "Bleu nuit, chiffres fins, lueur discrète", theme: .dark, accent: "7C9CFF", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "1B2250", endHex: "05060F", direction: .down)
            $0.depth = .glow
            $0.shadowHex = "7C9CFF"
            $0.numberWeight = .light
        },
        make("pure-white", "Pure White", "Blanc pur, noir net, rien de trop", theme: .light, accent: "111114", background: .color("FFFFFF")) {
            $0.border = .solid
            $0.borderHex = "E6E6EA"
            $0.borderWidth = 1
            $0.titleCase = .normal
        },
        make("ocean", "Ocean", "Du turquoise au bleu profond", theme: .modern, accent: "5EE6D0", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "0B8FAC", endHex: "063A6B", direction: .diagonal)
            $0.chartHex = "9DF3E6"
            $0.shape = .soft
        },
        make("forest", "Forest", "Vert forêt, texture papier", theme: .soft, accent: "A8D672", background: .color("1E3A2B")) {
            $0.texture = .paper
            $0.textureOpacity = 0.35
            $0.chartHex = "A8D672"
            $0.iconStyle = .circle
        },
        make("sunset", "Sunset", "Orange, rose et violet du soir", theme: .gradient, accent: "FF8A5B", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "FF9A62", endHex: "8E3BA8", direction: .diagonal)
            $0.depth = .soft
            $0.numberWeight = .heavy
        },
        make("cyber", "Cyber", "Magenta et cyan, bord lumineux", theme: .neon, accent: "00F0FF") {
            $0.border = .glow
            $0.borderHex = "FF2DAA"
            $0.chartHex = "00F0FF"
            $0.numberHex = "FF2DAA"
        },
        make("luxury", "Luxury", "Noir profond et or", theme: .luxury, accent: "D4AF37"),
        make("minimal-black", "Minimal Black", "Noir total, une seule couleur", theme: .monochrome, accent: "FFFFFF") {
            $0.iconStyle = .none
            $0.titleCase = .lower
            $0.numberWeight = .regular
        },
        make("glass", "Glass", "Verre dépoli et reflets", theme: .liquidGlass, accent: "5B7FE0"),
        make("monochrome", "Monochrome", "Gris doux, chiffres noirs", theme: .light, accent: "3A3A3C", background: .color("E9E9EB")) {
            $0.shape = .panel
            $0.chartHex = "3A3A3C"
        },
        make("sakura", "Sakura", "Rose poudré et prune", theme: .pastel, accent: "D0487A", background: .color("FBE4EC")) {
            $0.textHex = "4A1830"
            $0.shape = .soft
            $0.iconStyle = .circle
        },
        make("sand", "Sable", "Beige chaud, serif élégant", theme: .editorial, accent: "A0522D", background: .color("EFE3CC")) {
            $0.texture = .grain
            $0.textureOpacity = 0.3
        },
        make("arctic", "Arctique", "Bleu glacier et blanc", theme: .modern, accent: "2F80ED", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "F4FAFF", endHex: "CFE3F7", direction: .down)
            $0.textHex = "0B2540"
            $0.secondaryHex = "5A7390"
        },
        make("terminal", "Hacker", "Vert sur noir, lignes de balayage", theme: .terminal, accent: "39FF6A") {
            $0.chart = .sparkline
        },
        make("sport", "Stade", "Noir et jaune fluo, gros chiffres", theme: .sport, accent: "C6FF00"),
        make("dashboard", "Cockpit", "Petites cartes sur ardoise", theme: .dashboard, accent: "4DA3FF"),
    ]

    static func preset(_ id: String) -> StylePreset? { all.first { $0.id == id } }
}

// MARK: - Personal styles

/// A look saved by the person under a name (« Mon thème »), to give several widgets the same identity.
struct SavedStyle: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var themeID: ThemeID
    var accentHex: String
    var background: BackgroundStyle
    var font: FontChoice
    var style: StyleOptions
    var createdAt = Date()

    init(name: String, design: WidgetDesign) {
        self.name = name
        themeID = design.themeID
        accentHex = design.accentHex
        // A photo belongs to one widget: the saved look keeps the style's own background instead.
        if case .photo = design.background { background = .theme } else { background = design.background }
        font = design.font
        style = design.style.look
    }

    enum CodingKeys: String, CodingKey { case id, name, themeID, accentHex, background, font, style, createdAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Mon thème"
        themeID = (try? c.decodeIfPresent(ThemeID.self, forKey: .themeID)) ?? .minimal
        accentHex = (try? c.decodeIfPresent(String.self, forKey: .accentHex)) ?? Palette.defaultAccent
        background = (try? c.decodeIfPresent(BackgroundStyle.self, forKey: .background)) ?? .theme
        font = (try? c.decodeIfPresent(FontChoice.self, forKey: .font)) ?? .theme
        style = (try? c.decodeIfPresent(StyleOptions.self, forKey: .style)) ?? StyleOptions()
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
    }

    /// The design with this look, its content untouched: the data, the options and the lines the person hid.
    func applied(to design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.themeID = themeID
        copy.accentHex = accentHex
        // A widget with its own photo keeps it.
        if case .photo = design.background {} else { copy.background = background }
        copy.font = font
        var look = style
        look.hidden = design.style.hidden
        copy.style = look
        return copy
    }

    /// Whether a design already wears this look.
    func matches(_ design: WidgetDesign) -> Bool {
        var keepsOwnPhoto = false
        if case .photo = design.background { keepsOwnPhoto = true }
        let sameBackground = keepsOwnPhoto || design.background == background
        let sameLook = design.style.look == style.look
        return sameBackground && sameLook && design.themeID == themeID && design.accentHex == accentHex && design.font == font
    }
}

struct StyleLibrary: Codable, Hashable {
    var styles: [SavedStyle] = []

    init() {}

    init(styles: [SavedStyle]) {
        self.styles = styles
    }

    enum CodingKeys: String, CodingKey { case styles }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        styles = (try? c.decodeIfPresent([SavedStyle].self, forKey: .styles)) ?? []
    }
}

extension StyleLibrary: StoredState { static var file: StoreFile { .styles } }
