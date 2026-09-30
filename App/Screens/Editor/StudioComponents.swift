import SwiftUI
import WidgetKit

/// The Widget Studio's sections, in the order a widget is usually made.
enum StudioSection: String, CaseIterable, Identifiable {
    case content, themes, style, colors, background, border, depth, shape, text, icons, layout, chart, density, myStyles
    var id: String { rawValue }

    var title: String {
        switch self {
        case .content: "Contenu"
        case .themes: "Thèmes"
        case .style: "Style"
        case .colors: "Couleurs"
        case .background: "Fond"
        case .border: "Bordure"
        case .depth: "Profondeur"
        case .shape: "Forme"
        case .text: "Texte"
        case .icons: "Icônes"
        case .layout: "Disposition"
        case .chart: "Graphique"
        case .density: "Densité"
        case .myStyles: "Mes styles"
        }
    }

    var symbol: String {
        switch self {
        case .content: "square.text.square"
        case .themes: "sparkles"
        case .style: "swatchpalette"
        case .colors: "paintpalette"
        case .background: "photo"
        case .border: "square.dashed"
        case .depth: "shadow"
        case .shape: "square.on.circle"
        case .text: "textformat"
        case .icons: "star.circle"
        case .layout: "rectangle.3.group"
        case .chart: "chart.bar.xaxis"
        case .density: "rectangle.compress.vertical"
        case .myStyles: "bookmark"
        }
    }
}

/// The row of sections under the preview.
struct StudioSectionBar: View {
    @Binding var selection: StudioSection

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StudioSection.allCases) { section in
                        let isSelected = section == selection
                        Button {
                            Haptics.tap()
                            withAnimation(.easeInOut(duration: 0.2)) { selection = section }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: section.symbol).font(.caption.weight(.semibold))
                                Text(section.title)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.cardFill), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("studio-\(section.rawValue)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .id(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, section in
                withAnimation { proxy.scrollTo(section, anchor: .center) }
            }
        }
    }
}

/// A titled group of settings, on a card.
struct StudioGroup<Content: View>: View {
    let title: String
    var detail: String?
    var isPremium = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        EditorSection(title: title, detail: detail, isPremium: isPremium, content: content)
    }
}

/// What iOS allows, said plainly next to the setting it concerns.
struct StudioNote: View {
    let text: String
    var symbol = "info.circle"

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// Choices shown as chips that wrap onto several lines.
struct StudioChoices<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var symbol: (Option) -> String? = { _ in nil }
    var identifier: ((Option) -> String)?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                FilterChip(title: title(option), symbol: symbol(option), isSelected: option == selection) {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                }
                .accessibilityIdentifier(identifier?(option) ?? "")
            }
        }
    }
}

/// A slider with its name and value.
struct StudioSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.05
    var format: (Double) -> String = { "\(Int(($0 * 100).rounded())) %" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(Text(title))
        }
    }
}

/// One color setting: the style's own color until the person picks one, which can be reset.
struct StudioColorRow: View {
    let title: String
    @Binding var hex: String?
    /// Shown while the style decides.
    let fallback: Color
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline)
                Text(hex == nil ? (detail ?? "Celle du style") : "Personnalisée")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if hex != nil {
                Button {
                    withAnimation { hex = nil }
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Revenir à la couleur du style"))
            }
            ColorPicker(title, selection: Binding(
                get: { hex.map { Color(hex: $0) } ?? fallback },
                set: { hex = $0.hexString }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(minWidth: 44, minHeight: 44)
        }
    }
}

/// A predefined set of colors applied at once (accent, charts, icons).
struct ColorPalette: Identifiable, Hashable {
    let id: String
    let name: String
    let accent: String
    let chart: String
    let icon: String
    var number: String?

    static let all: [ColorPalette] = [
        ColorPalette(id: "jade", name: "Jade", accent: "2F8F7A", chart: "2F8F7A", icon: "5BB89F"),
        ColorPalette(id: "ocean", name: "Océan", accent: "1E7FD8", chart: "22B8CF", icon: "1E7FD8"),
        ColorPalette(id: "coral", name: "Corail", accent: "FF6B57", chart: "FF9A62", icon: "FF6B57"),
        ColorPalette(id: "lavender", name: "Lavande", accent: "8C6CFF", chart: "B69CFF", icon: "8C6CFF"),
        ColorPalette(id: "forest", name: "Forêt", accent: "3F7D4E", chart: "7FA33A", icon: "3F7D4E"),
        ColorPalette(id: "sand", name: "Sable", accent: "B07A45", chart: "D9A066", icon: "B07A45"),
        ColorPalette(id: "neon", name: "Néon", accent: "FF2DAA", chart: "00F0FF", icon: "FF2DAA"),
        ColorPalette(id: "candy", name: "Bonbon", accent: "F2588F", chart: "FFB547", icon: "5AC8FA"),
        ColorPalette(id: "gold", name: "Or", accent: "C9A227", chart: "E6C35C", icon: "C9A227"),
        ColorPalette(id: "mono", name: "Graphite", accent: "4B5563", chart: "9CA3AF", icon: "4B5563"),
        ColorPalette(id: "sunset", name: "Couchant", accent: "F45B69", chart: "F7A072", icon: "8E3BA8"),
        ColorPalette(id: "mint", name: "Menthe", accent: "2DBE8D", chart: "7CE0C3", icon: "2DBE8D"),
    ]

    func applied(to design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.accentHex = accent
        copy.style.chartHex = chart
        copy.style.iconHex = icon
        copy.style.numberHex = number
        return copy
    }

    func matches(_ design: WidgetDesign) -> Bool {
        design.accentHex == accent && design.style.chartHex == chart && design.style.iconHex == icon
    }
}

/// A small live preview of the widget with one change, for the choice grids.
struct StudioPreviewTile: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let payload: WidgetPayload
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var showsLock = false
    let width: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            WidgetPreview(design: design, family: family, payload: payload, width: width)
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius * width / WidgetMetrics.size(family).width + 3, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                }
                .overlay(alignment: .topTrailing) {
                    if showsLock {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.premiumInk)
                            .padding(4)
                            .background(Color.premiumFill, in: Circle())
                            .padding(6)
                    }
                }
            VStack(spacing: 0) {
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        // The whole tile, preview included, is what the finger taps.
        .contentShape(Rectangle())
    }
}

/// The widget at the top of the Studio: always in view, updated with every change.
struct StudioStage: View {
    let design: WidgetDesign
    @Binding var family: WidgetFamily
    let payload: WidgetPayload
    var isExample = false

    var body: some View {
        VStack(spacing: 8) {
            preview
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.25), value: design)
                .animation(.easeInOut(duration: 0.2), value: family)
                .frame(maxWidth: .infinity)
                .background {
                    LinearGradient(
                        colors: family.isAccessory
                            ? [Color(hex: "1F2A44"), Color(hex: "3B2F5C")]
                            : [Color(light: "DCE3EA", dark: "1B1F26"), Color(light: "C9D3DD", dark: "11141A")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topLeading) {
                if isExample { ExampleBadge().padding(10) }
            }
            .overlay(alignment: .bottom) {
                if family.isAccessory {
                    Text("Écran verrouillé : iOS affiche les widgets d'une seule teinte.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 6)
                }
            }

            if design.families.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(design.families, id: \.self) { item in
                            FilterChip(title: item.shortTitle, symbol: item.isAccessory ? "lock.iphone" : nil, isSelected: family == item) {
                                family = item
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: design.kind) { _, _ in
            if !design.families.contains(family) { family = design.families.first ?? .systemSmall }
        }
    }

    @ViewBuilder private var preview: some View {
        switch family {
        case .systemSmall:
            WidgetPreview(design: design, family: family, payload: payload, width: 150)
        case .systemMedium:
            WidgetPreview(design: design, family: family, payload: payload, width: 318)
        case .systemLarge, .systemExtraLarge:
            WidgetPreview(design: design, family: family, payload: payload, width: 196)
        default:
            WidgetPreview(design: design, family: family, payload: payload, width: WidgetMetrics.size(family).width * 1.3)
                .padding(.vertical, 14)
        }
    }
}

extension WidgetKind {
    /// Widgets drawn from a tile, whose layout, chart and lines the Studio can rearrange.
    /// The others (clock, calendar, weather…) have their own arrangement and take the rest of the look.
    var usesTileLayout: Bool {
        switch self {
        case .clock, .calendar, .worldClock, .progress, .countdown, .yearDots, .tasks, .habits, .focus,
             .upNext, .note, .weather, .crypto, .moneyFlow, .hydration:
            false
        default:
            true
        }
    }
}
