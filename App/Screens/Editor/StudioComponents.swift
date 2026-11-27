import SwiftUI
import WidgetKit

/// The Widget Studio's sections, in the order a widget is usually made.
enum StudioSection: String, CaseIterable, Identifiable {
    case size, content, style, colors, text, background, border, chart, density, myStyles
    var id: String { rawValue }

    /// Also accepts the names of sections from earlier versions (« Thèmes », « Thème » : merged into « Style »).
    init?(name: String) {
        if name == "themes" || name == "theme" {
            self = .style
        } else {
            self.init(rawValue: name)
        }
    }

    var title: String {
        switch self {
        case .size: tr("Taille")
        case .content: tr("Contenu")
        case .style: tr("Style")
        case .colors: tr("Couleurs")
        case .text: tr("Texte")
        case .background: tr("Fond")
        case .border: tr("Bordure")
        case .chart: tr("Graphique")
        case .density: tr("Densité")
        case .myStyles: tr("Mes styles")
        }
    }

    var symbol: String {
        switch self {
        case .size: "aspectratio"
        case .content: "square.text.square"
        case .style: "swatchpalette"
        case .colors: "paintpalette"
        case .text: "textformat"
        case .background: "photo"
        case .border: "square.dashed"
        case .chart: "chart.bar.xaxis"
        case .density: "rectangle.compress.vertical"
        case .myStyles: "bookmark"
        }
    }
}

/// What the Studio's panel shows, derived from the tool open: « Contenu » (what the widget shows, the widgets inside)
/// or a tool of the look. Not steps: the person never sees them.
enum StudioChapter: String {
    case content, style
}

/// A link at the top right of a panel (« Suivant › », « Fermer »).
struct StudioPanelLink {
    let title: String
    var symbol: String?
    let identifier: String
    let action: () -> Void
}

/// The title of a chapter's panel, with what it is about on the right, or a link.
struct StudioPanelHeader: View {
    let title: String
    var detail: String?
    var link: StudioPanelLink?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let link {
                Button {
                    Haptics.tap()
                    link.action()
                } label: {
                    HStack(spacing: 3) {
                        Text(link.title)
                        if let symbol = link.symbol {
                            Image(systemName: symbol).font(.subheadline.weight(.bold))
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier(link.identifier)
            }
        }
    }
}

/// A round glass button on the stage (« + », « Sur mon écran »).
struct StudioRoundButton: View {
    let symbol: String
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .cristalGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
    }
}

/// The row of sections under the preview.
struct StudioSectionBar: View {
    let sections: [StudioSection]
    @Binding var selection: StudioSection
    @Environment(\.appStyle) private var style

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sections) { section in
                        let isSelected = section == selection
                        Button {
                            Haptics.tap()
                            withAnimation(.easeInOut(duration: 0.2)) { selection = section }
                        } label: {
                            // A tool: its symbol over its name; the one open sits on a soft tint, in the action color.
                            VStack(spacing: 4) {
                                Image(systemName: section.symbol).font(.system(size: 18, weight: .semibold))
                                Text(section.title)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 8)
                            .frame(minWidth: 68, minHeight: 60)
                            .background(isSelected ? CristalPalette.of(style.id).tint2Color : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
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
                Text(hex == nil ? (detail ?? tr("Celle du style")) : tr("Personnalisée"))
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
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(tr("Revenir à la couleur du style")))
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

/// The widget at the top of the Studio: always in view, updated with every change. On a combined widget each
/// widget inside can be touched (its settings open) and the one open is ringed; the footer holds the stage's
/// buttons (« Changer de widget », « + », « Sur mon écran »).
struct StudioStage<Footer: View>: View {
    let design: WidgetDesign
    @Binding var family: WidgetFamily
    let payload: WidgetPayload
    var isExample: Bool
    /// The widget inside whose settings are open, ringed on the stage.
    var selectedPart: Int?
    /// A touch on a widget inside a combined widget (nil: not touchable, as on the Lock Screen).
    var onPart: ((Int) -> Void)?
    /// The settings fill most of the screen: the widget shrinks to about the height of two buttons, the footer
    /// stands beside it, and a touch on the scene (not on a widget inside) calls `onExpand`.
    var isCompact: Bool
    var onExpand: (() -> Void)?
    let footer: Footer
    @Environment(\.appStyle) private var style

    /// The widget's height on the shrunk scene: « + » and « Sur mon écran » one above the other.
    static var compactHeight: CGFloat { 96 }

    init(design: WidgetDesign, family: Binding<WidgetFamily>, payload: WidgetPayload, isExample: Bool = false,
         selectedPart: Int? = nil, onPart: ((Int) -> Void)? = nil, isCompact: Bool = false, onExpand: (() -> Void)? = nil,
         @ViewBuilder footer: () -> Footer) {
        self.design = design
        self._family = family
        self.payload = payload
        self.isExample = isExample
        self.selectedPart = selectedPart
        self.onPart = onPart
        self.isCompact = isCompact
        self.onExpand = onExpand
        self.footer = footer()
    }

    var body: some View {
        let palette = CristalPalette.of(style.id)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                preview
                    .shadow(color: Color.black.opacity(family.isAccessory ? 0 : 0.14), radius: isCompact ? 6 : 10, y: isCompact ? 3 : 5)
                    // Laid exactly over the widget, after the shadow (the rings aren't shadowed).
                    .overlay { zones }
                    // Room for the shadow inside the clipped scene (radius 10, 5 points down).
                    .padding(.top, isCompact ? 8 : 12)
                    .padding(.bottom, isCompact ? 10 : (family.isAccessory ? 6 : 14))
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: design)
                    .animation(.easeInOut(duration: 0.2), value: family)
                if isCompact {
                    footer
                        .padding(.trailing, 12)
                        .transition(.opacity)
                }
            }
            if !isCompact {
                if family.isAccessory {
                    Text(tr("Écran verrouillé : iOS affiche les widgets d'une seule teinte."))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                footer
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        // Shrunk: a touch on the scene brings the large widget back (a widget inside keeps its own touch).
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded { onExpand?() }, including: isCompact ? .all : .subviews)
        .background {
            // The Lock Screen scene keeps its night backdrop (white caption, one-tint widgets).
            if family.isAccessory {
                LinearGradient(colors: [Color(hex: "1F2A44"), Color(hex: "3B2F5C")], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                palette.well2Color
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: palette.radius, style: .continuous))
        .overlay(alignment: .topLeading) {
            // Over a corner of the widget: the touch goes through to the widget inside.
            if isExample { ExampleBadge().padding(10).allowsHitTesting(false) }
        }
        .onChange(of: design.kind) { _, _ in
            if !design.families.contains(family) { family = design.families.first ?? .systemSmall }
        }
    }

    /// The touch zones of a combined widget's widgets (none for a widget alone or on the Lock Screen).
    @ViewBuilder private var zones: some View {
        if let onPart, design.isCombo, !family.isAccessory {
            StudioStageZones(parts: design.options.parts, family: family, selected: selectedPart, onPart: onPart)
        }
    }

    @ViewBuilder private var preview: some View {
        if family.isAccessory {
            WidgetPreview(design: design, family: family, payload: payload, width: previewWidth)
                .padding(.vertical, isCompact ? 0 : 14)
        } else {
            WidgetPreview(design: design, family: family, payload: payload, width: previewWidth)
        }
    }

    /// The widget's width on the scene; shrunk, no taller than `compactHeight`.
    private var previewWidth: CGFloat {
        let size = WidgetMetrics.size(family)
        let full: CGFloat
        switch family {
        case .systemSmall: full = 150
        case .systemMedium: full = 318
        case .systemLarge, .systemExtraLarge: full = 196
        default: full = size.width * 1.3
        }
        guard isCompact, size.width > 0 else { return full }
        let height = full * size.height / size.width
        return height > Self.compactHeight ? full * Self.compactHeight / height : full
    }
}

extension WidgetKind {
    /// Widgets drawn from a tile, whose layout, chart and lines the Studio can rearrange.
    /// The others (clock, calendar…) have their own arrangement and take the rest of the look.
    var usesTileLayout: Bool {
        switch self {
        case .clock, .calendar, .worldClock, .progress, .countdown, .yearDots, .tasks, .habits, .focus,
             .upNext, .note, .crypto, .moneyFlow, .hydration, .photos, .quote:
            false
        default:
            true
        }
    }
}
