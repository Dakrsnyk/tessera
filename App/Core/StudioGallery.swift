import SwiftUI
import WidgetKit

#if DEBUG
/// Review captures of the Widget Studio: every style, theme, layout, chart and shape side by side.
/// Modes: gallery-styles-<page>, gallery-presets-<page>, gallery-layouts-<small|medium|large>,
/// gallery-charts, gallery-looks, gallery-palettes, gallery-recolor-<page> (every style in a main color).
struct StudioGalleryView: View {
    let mode: String

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let design: WidgetDesign
    }

    private var parts: [String] { mode.split(separator: "-").map(String.init) }
    private var page: Int { max(1, Int(parts.last ?? "1") ?? 1) }

    private var family: WidgetFamily {
        switch parts[safe: 2] ?? "" {
        case "medium": .systemMedium
        case "large": .systemLarge
        default: mode.hasPrefix("gallery-charts") || mode.hasPrefix("gallery-looks") ? .systemMedium : .systemSmall
        }
    }

    private var columns: Int { family == .systemMedium ? 2 : 3 }

    private static let kinds: [WidgetKind] = [.caloriesLeft, .nutritionWeek, .macros, .trainingStreak, .budgetLeft, .weeklyVolume]

    private var items: [Item] {
        switch parts[safe: 1] ?? "" {
        case "styles":
            let all = ThemeCatalog.all.enumerated().map { index, theme in
                Item(id: index, title: theme.name, design: WidgetDesign(
                    kind: Self.kinds[index % Self.kinds.count], themeID: theme.id,
                    accentHex: Palette.freeAccents[index % Palette.freeAccents.count].hex, format: .small
                ))
            }
            return Array(all.dropFirst((page - 1) * 15).prefix(15))
        case "presets":
            let all = StylePreset.all.enumerated().map { index, preset in
                Item(id: index, title: preset.name, design: preset.applied(to: WidgetDesign(kind: Self.kinds[index % Self.kinds.count], format: .small)))
            }
            return Array(all.dropFirst((page - 1) * 15).prefix(15))
        case "layouts":
            let kind: WidgetKind = family == .systemSmall ? .caloriesLeft : .macros
            return LayoutKind.allCases.enumerated().map { index, layout in
                var design = WidgetDesign(kind: kind, themeID: .modern, accentHex: "3366FF")
                design.style.layout = layout
                return Item(id: index, title: layout.title, design: design)
            }
        case "palettes":
            return ColorPalette.all.enumerated().map { index, palette in
                let design = WidgetDesign(kind: Self.kinds[index % Self.kinds.count], themeID: .modern, format: .small)
                return Item(id: index, title: palette.name, design: palette.applied(to: design))
            }
        case "recolor":
            // Every style, repainted by a main color (a different one on each, to see them all).
            let all = ThemeCatalog.all.enumerated().map { index, theme in
                let main = Palette.freeAccents[index % Palette.freeAccents.count]
                let design = WidgetDesign(kind: Self.kinds[index % Self.kinds.count], themeID: theme.id, format: .small).recolored(to: main.hex)
                return Item(id: index, title: "\(theme.name) · \(main.name)", design: design)
            }
            return Array(all.dropFirst((page - 1) * 15).prefix(15))
        case "charts":
            var result: [Item] = []
            for kind in ChartKind.options(for: .series) {
                var design = WidgetDesign(kind: .nutritionWeek, themeID: .dark, accentHex: "FF6B57")
                design.style.chart = kind
                design.style.chartValues = true
                result.append(Item(id: result.count, title: "Série · \(kind.title)", design: design))
            }
            for kind in ChartKind.options(for: .segments).dropFirst() {
                var design = WidgetDesign(kind: .macros, themeID: .minimal, accentHex: "2F8F7A")
                design.style.chart = kind
                result.append(Item(id: result.count, title: "Parts · \(kind.title)", design: design))
            }
            return Array(result.prefix(12))
        default:
            // Looks: borders, depth, shapes, textures, backgrounds, densities on one widget.
            var result: [Item] = []
            func add(_ title: String, _ change: (inout WidgetDesign) -> Void) {
                var design = WidgetDesign(kind: .macros, themeID: .dark, accentHex: "8C6CFF")
                change(&design)
                result.append(Item(id: result.count, title: title, design: design))
            }
            add("Bordure lumineuse") { $0.style.border = .glow; $0.style.borderWidth = 2 }
            add("Double bordure") { $0.themeID = .light; $0.style.border = .double; $0.style.borderHex = "8C6CFF" }
            add("Tirets + grille") { $0.style.border = .dashed; $0.style.texture = .grid }
            add("Verre") { $0.background = .glass; $0.style.depth = .soft }
            add("Dégradé perso") { $0.background = .gradient; $0.style.gradient = GradientSpec(startHex: "FF9A62", endHex: "8E3BA8", direction: .diagonal) }
            add("Panneau flottant") { $0.themeID = .light; $0.style.shape = .panel; $0.style.depth = .floating }
            add("Lueur + mono") { $0.font = .mono; $0.style.depth = .glow }
            add("Papier + serif") { $0.themeID = .paper; $0.style.layout = .vertical }
            add("Cartes denses") { $0.style.layout = .cards; $0.style.density = .dense }
            add("Aéré + capsule") { $0.themeID = .soft; $0.style.density = .compact; $0.style.shape = .capsule }
            return result
        }
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let width = (geo.size.width - 16 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: spacing), count: columns), spacing: 10) {
                    ForEach(items) { item in
                        VStack(spacing: 3) {
                            WidgetPreview(design: item.design, family: family, payload: SamplePayload.make(for: item.design.kind), width: width)
                            Text(item.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(8)
            }
        }
        .background(.screenFill)
    }
}
#endif
