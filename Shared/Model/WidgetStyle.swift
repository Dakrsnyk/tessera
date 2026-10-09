import Foundation

// MARK: - Choices

/// How the main content of a data widget is arranged.
enum LayoutKind: String, Codable, CaseIterable, Identifiable {
    case auto, vertical, horizontal, minimal, centered, split, data, list, progress, graph, cards
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: tr("Auto")
        case .vertical: tr("Vertical")
        case .horizontal: tr("Horizontal")
        case .minimal: tr("Minimal")
        case .centered: tr("Focus")
        case .split: tr("Deux colonnes")
        case .data: tr("Données")
        case .list: tr("Liste")
        case .progress: tr("Progression")
        case .graph: tr("Graphique")
        case .cards: tr("Cartes")
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
        case .auto: tr("La disposition prévue pour ce widget.")
        case .vertical: tr("Titre, valeur, puis le graphique en dessous.")
        case .horizontal: tr("Icône, valeur et progression sur une ligne.")
        case .minimal: tr("Une seule information, très grande.")
        case .centered: tr("L'icône et la valeur au centre, comme un cadran.")
        case .split: tr("La valeur d'un côté, le détail de l'autre.")
        case .data: tr("Plusieurs statistiques, bien alignées.")
        case .list: tr("Les lignes d'abord, la valeur en en-tête.")
        case .progress: tr("Une grande barre de progression.")
        case .graph: tr("La valeur et un grand graphique.")
        case .cards: tr("Chaque information sur sa petite carte.")
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
        case .auto: tr("Auto")
        case .line: tr("Ligne")
        case .area: tr("Aire")
        case .bars: tr("Barres")
        case .histogram: tr("Histogramme")
        case .dots: tr("Points")
        case .sparkline: tr("Sparkline")
        case .evolution: tr("Évolution")
        case .comparison: tr("Comparaison")
        case .ring: tr("Anneau")
        case .pie: tr("Cercle")
        case .gauge: tr("Jauge")
        case .progress: tr("Barre", context: "progress")
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
        case .compact: tr("Aéré")
        case .balanced: tr("Équilibré")
        case .dense: tr("Dense")
        }
    }

    var summary: String {
        switch self {
        case .compact: tr("Peu d'informations, très lisible.")
        case .balanced: tr("Équilibre entre informations et espace.")
        case .dense: tr("Plus d'informations dans le même widget.")
        }
    }
}

enum BorderKind: String, Codable, CaseIterable, Identifiable {
    case none, solid, dashed, dotted, double, glow, gradient
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: tr("Aucune")
        case .solid: tr("Pleine")
        case .dashed: tr("Tirets")
        case .dotted: tr("Points")
        case .double: tr("Double")
        case .glow: tr("Lumineuse")
        case .gradient: tr("Dégradé")
        }
    }
}

enum DepthKind: String, Codable, CaseIterable, Identifiable {
    case none, soft, strong, glow, floating, embossed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: tr("Aucune")
        case .soft: tr("Légère")
        case .strong: tr("Forte")
        case .glow: tr("Lueur")
        case .floating: tr("Flottant")
        case .embossed: tr("Relief")
        }
    }

    var summary: String {
        switch self {
        case .none: tr("Tout est à plat.")
        case .soft: tr("Une ombre douce sous les chiffres et les cartes.")
        case .strong: tr("Une ombre marquée, plus de contraste.")
        case .glow: tr("Les chiffres et les graphiques brillent.")
        case .floating: tr("Le contenu semble flotter au-dessus du fond.")
        case .embossed: tr("Un léger relief, comme gravé.")
        }
    }
}

/// The shape of what sits inside the widget: iOS draws the widget's own outline, Tessera shapes the rest.
enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case theme, rounded, soft, square, capsule, panel
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: tr("Style")
        case .rounded: tr("Arrondi")
        case .soft: tr("Doux")
        case .square: tr("Carré")
        case .capsule: tr("Capsule")
        case .panel: tr("Panneau")
        }
    }

    var summary: String {
        switch self {
        case .theme: tr("Les formes prévues par le style.")
        case .rounded: tr("Coins arrondis classiques.")
        case .soft: tr("Coins très arrondis, forme douce.")
        case .square: tr("Coins nets, presque carrés.")
        case .capsule: tr("Barres, cartes et boutons en capsule.")
        case .panel: tr("Le contenu posé sur une carte intérieure.")
        }
    }
}

/// The frame around the widget's icons.
enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case theme, plain, circle, square, outline, none
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: tr("Style")
        case .plain: tr("Simple")
        case .circle: tr("Pastille")
        case .square: tr("Carré")
        case .outline: tr("Contour")
        case .none: tr("Aucune")
        }
    }
}

/// The drawing of the icons themselves (SF Symbols variants, so every icon of the widget matches).
enum IconFamily: String, Codable, CaseIterable, Identifiable {
    case theme, filled, outlined, circled, squared
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: tr("Style")
        case .filled: tr("Pleines")
        case .outlined: tr("Traits")
        case .circled: tr("Rondes")
        case .squared: tr("Carrées")
        }
    }
}

enum IconPosition: String, Codable, CaseIterable, Identifiable {
    case leading, trailing, top
    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: tr("À gauche")
        case .trailing: tr("À droite")
        case .top: tr("En haut")
        }
    }
}

enum TitleCase: String, Codable, CaseIterable, Identifiable {
    case theme, upper, normal, lower
    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: tr("Style")
        case .upper: tr("MAJUSCULES")
        case .normal: tr("Normal")
        case .lower: tr("minuscules")
        }
    }
}

enum WeightChoice: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: tr("Fin")
        case .regular: tr("Normal")
        case .medium: tr("Moyen")
        case .semibold: tr("Demi-gras")
        case .bold: tr("Gras")
        case .heavy: tr("Épais")
        case .black: tr("Noir")
        }
    }
}

enum GradientDirection: String, Codable, CaseIterable, Identifiable {
    case down, diagonal, across, up, radial
    var id: String { rawValue }

    var title: String {
        switch self {
        case .down: tr("Vers le bas")
        case .diagonal: tr("En diagonale")
        case .across: tr("De gauche à droite")
        case .up: tr("Vers le haut")
        case .radial: tr("Depuis le centre")
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
    // Motifs of the themed styles: space, snow, water, a web, foliage.
    case stars, snow, waves, web, leaves
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: tr("Aucune")
        case .grain: tr("Grain")
        case .paper: tr("Papier")
        case .dots: tr("Points")
        case .grid: tr("Grille")
        case .lines: tr("Lignes")
        case .diagonal: tr("Rayures")
        case .noise: tr("Bruit")
        case .stars: tr("Étoiles")
        case .snow: tr("Neige")
        case .waves: tr("Vagues")
        case .web: tr("Toile")
        case .leaves: tr("Feuillage")
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
        TypePreset(id: "system", name: tr("Système"), font: .standard, numberWeight: .semibold, titleWeight: .semibold, valueScale: 1, titleCase: .upper, tracking: 0),
        TypePreset(id: "display", name: tr("Affiche"), font: .standard, numberWeight: .black, titleWeight: .bold, valueScale: 1.2, titleCase: .upper, tracking: 0.5),
        TypePreset(id: "light", name: tr("Léger"), font: .standard, numberWeight: .light, titleWeight: .regular, valueScale: 1.1, titleCase: .normal, tracking: 0),
        TypePreset(id: "friendly", name: tr("Arrondi"), font: .rounded, numberWeight: .bold, titleWeight: .semibold, valueScale: 1, titleCase: .normal, tracking: 0),
        TypePreset(id: "editorial", name: tr("Éditorial"), font: .serif, numberWeight: .regular, titleWeight: .medium, valueScale: 1.1, titleCase: .upper, tracking: 1.2),
        TypePreset(id: "classic", name: tr("Classique"), font: .serif, numberWeight: .black, titleWeight: .semibold, valueScale: 1.15, titleCase: .normal, tracking: 0),
        TypePreset(id: "code", name: tr("Code"), font: .mono, numberWeight: .medium, titleWeight: .medium, valueScale: 0.95, titleCase: .lower, tracking: 0),
        TypePreset(id: "tech", name: tr("Technique"), font: .mono, numberWeight: .light, titleWeight: .regular, valueScale: 1, titleCase: .upper, tracking: 1.5),
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
    /// The fill of inner surfaces (cards, list rows, chips), set by a palette.
    var panelHex: String?
    /// Colors given in turn to the lines and parts of a whole, set by a palette.
    var seriesHexes: [String] = []
    /// The main color tints the whole style: background, surfaces, text, charts and lines take its hue.
    var recolor: Bool = false

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
        case textHex, secondaryHex, numberHex, iconHex, chartHex, positiveHex, negativeHex, rowColors, panelHex, seriesHexes, recolor
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
        panelHex = optional(.panelHex, String.self)
        seriesHexes = value(.seriesHexes, d.seriesHexes)
        recolor = value(.recolor, d.recolor)
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
        r.panelHex = panelHex ?? base.panelHex
        r.seriesHexes = seriesHexes.isEmpty ? base.seriesHexes : seriesHexes
        r.recolor = recolor || base.recolor
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
        let colors = [textHex, secondaryHex, numberHex, iconHex, chartHex, positiveHex, negativeHex, borderHex, shadowHex, panelHex]
        if colors.contains(where: { $0 != nil }) || !rowColors.isEmpty || !seriesHexes.isEmpty { features.append(tr("Couleurs personnalisées")) }
        if gradient != nil { features.append(tr("Dégradé personnalisé")) }
        if texture != .none { features.append(tr("Texture")) }
        if border != .none { features.append(tr("Bordure")) }
        if depth != .none { features.append(tr("Ombre et profondeur")) }
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
        copy.panelHex = nil
        copy.seriesHexes = []
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
        make("midnight", tr("Midnight"), tr("Bleu nuit, chiffres fins, lueur discrète"), theme: .dark, accent: "7C9CFF", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "1B2250", endHex: "05060F", direction: .down)
            $0.depth = .glow
            $0.shadowHex = "7C9CFF"
            $0.numberWeight = .light
        },
        make("pure-white", tr("Pure White"), tr("Blanc pur, noir net, rien de trop"), theme: .light, accent: "111114", background: .color("FFFFFF")) {
            $0.border = .solid
            $0.borderHex = "E6E6EA"
            $0.borderWidth = 1
            $0.titleCase = .normal
        },
        make("ocean", tr("Ocean"), tr("Du turquoise au bleu profond"), theme: .modern, accent: "5EE6D0", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "0B8FAC", endHex: "063A6B", direction: .diagonal)
            $0.chartHex = "9DF3E6"
            $0.shape = .soft
        },
        make("forest", tr("Forest"), tr("Vert forêt, texture papier"), theme: .soft, accent: "A8D672", background: .color("1E3A2B")) {
            $0.texture = .paper
            $0.textureOpacity = 0.35
            $0.chartHex = "A8D672"
            $0.iconStyle = .circle
        },
        make("sunset", tr("Sunset"), tr("Orange, rose et violet du soir"), theme: .gradient, accent: "FF8A5B", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "FF9A62", endHex: "8E3BA8", direction: .diagonal)
            $0.depth = .soft
            $0.numberWeight = .heavy
        },
        make("cyber", tr("Cyber"), tr("Magenta et cyan, bord lumineux"), theme: .neon, accent: "00F0FF") {
            $0.border = .glow
            $0.borderHex = "FF2DAA"
            $0.chartHex = "00F0FF"
            $0.numberHex = "FF2DAA"
        },
        make("luxury", tr("Luxury"), tr("Noir profond et or"), theme: .luxury, accent: "D4AF37"),
        make("minimal-black", tr("Minimal Black"), tr("Noir total, une seule couleur"), theme: .monochrome, accent: "FFFFFF") {
            $0.iconStyle = .none
            $0.titleCase = .lower
            $0.numberWeight = .regular
        },
        make("glass", tr("Glass"), tr("Verre dépoli et reflets"), theme: .liquidGlass, accent: "5B7FE0"),
        make("monochrome", tr("Monochrome"), tr("Gris doux, chiffres noirs"), theme: .light, accent: "3A3A3C", background: .color("E9E9EB")) {
            $0.shape = .panel
            $0.chartHex = "3A3A3C"
        },
        make("sakura", tr("Sakura"), tr("Rose poudré et prune"), theme: .pastel, accent: "D0487A", background: .color("FBE4EC")) {
            $0.textHex = "4A1830"
            $0.shape = .soft
            $0.iconStyle = .circle
        },
        make("sand", tr("Sable"), tr("Beige chaud, serif élégant"), theme: .editorial, accent: "A0522D", background: .color("EFE3CC")) {
            $0.texture = .grain
            $0.textureOpacity = 0.3
        },
        make("arctic", tr("Arctique"), tr("Bleu glacier et blanc"), theme: .modern, accent: "2F80ED", background: .gradient) {
            $0.gradient = GradientSpec(startHex: "F4FAFF", endHex: "CFE3F7", direction: .down)
            $0.textHex = "0B2540"
            $0.secondaryHex = "5A7390"
        },
        make("terminal", tr("Hacker"), tr("Vert sur noir, lignes de balayage"), theme: .terminal, accent: "39FF6A") {
            $0.chart = .sparkline
        },
        make("sport", tr("Stade"), tr("Noir et jaune fluo, gros chiffres"), theme: .sport, accent: "C6FF00"),
        make("dashboard", tr("Cockpit"), tr("Petites cartes sur ardoise"), theme: .dashboard, accent: "4DA3FF"),
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
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? tr("Mon thème")
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
