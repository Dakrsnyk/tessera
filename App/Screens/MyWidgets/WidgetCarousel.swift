import SwiftUI
import WidgetKit

/// What « Mes widgets » shows: every widget, the favorites, or one category.
enum WidgetShelfFilter: Hashable {
    case all, favorites
    case category(WidgetCategory)

    func allows(_ design: WidgetDesign) -> Bool {
        switch self {
        case .all: true
        case .favorites: design.isFavorite
        case let .category(category): design.kind.category == category
        }
    }
}

/// The person's widgets on a turning carousel: the one in the middle big and upright, its neighbors
/// smaller, tilted and faded on each side. Swipe to turn it; touch the middle one to edit it.
struct WidgetCarousel<Menu: View>: View {
    let designs: [WidgetDesign]
    @Binding var centeredID: UUID?
    let payload: (WidgetDesign) -> WidgetPayload
    let onOpen: (WidgetDesign) -> Void
    @ViewBuilder let menu: (WidgetDesign) -> Menu

    static var stageHeight: CGFloat { 250 }

    /// How big a widget is drawn on its page, and at which scale.
    static func fitted(_ design: WidgetDesign, pageWidth: CGFloat) -> (size: CGSize, scale: CGFloat) {
        let size = WidgetMetrics.size(design.displayFormat.family)
        let scale = min(pageWidth / size.width, stageHeight * 0.9 / size.height)
        return (CGSize(width: size.width * scale, height: size.height * scale), scale)
    }

    /// The widget in the middle (the first one until the carousel has turned).
    private var centered: WidgetDesign? {
        designs.first { $0.id == centeredID } ?? designs.first
    }

    var body: some View {
        GeometryReader { geo in
            let pageWidth = min(geo.size.width * 0.6, 300)
            let margin = max(0, (geo.size.width - pageWidth) / 2)
            // Where the widget in the middle is drawn: what the tutorial lights up on « Mes widgets ». A marker of
            // its own, in the middle of the stage, so it is right whichever widget the carousel has turned to.
            if let centered {
                let fitted = Self.fitted(centered, pageWidth: pageWidth)
                Color.clear
                    .frame(width: fitted.size.width, height: fitted.size.height)
                    .tutorialTarget(.myWidgets, radius: WidgetMetrics.cornerRadius * fitted.scale)
                    .position(x: geo.size.width / 2, y: Self.stageHeight / 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                // Pages overlap a little so the neighbors peek in on each side.
                LazyHStack(spacing: -pageWidth * 0.08) {
                    ForEach(designs) { design in
                        page(design, width: pageWidth)
                            .frame(width: pageWidth, height: Self.stageHeight)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .rotation3DEffect(.degrees(phase.value * -24), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                                    .rotationEffect(.degrees(phase.value * 4))
                                    .scaleEffect(1 - min(abs(phase.value), 1) * 0.24)
                                    .offset(y: min(abs(phase.value), 1) * 16)
                                    .opacity(1 - min(abs(phase.value), 1) * 0.45)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredID)
            .scrollClipDisabled()
        }
        .frame(height: Self.stageHeight)
    }

    private func page(_ design: WidgetDesign, width: CGFloat) -> some View {
        let family = design.displayFormat.family
        let fitted = Self.fitted(design, pageWidth: width)
        let isCentered = centeredID == design.id || (centeredID == nil && design.id == designs.first?.id)
        return Button {
            if isCentered {
                onOpen(design)
            } else {
                Haptics.tap()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { centeredID = design.id }
            }
        } label: {
            WidgetPreview(design: design, family: family, payload: payload(design), width: fitted.size.width)
                .overlay(alignment: .topTrailing) {
                    if design.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.35), in: Circle())
                            .padding(10)
                    }
                }
                .shadow(color: .black.opacity(isCentered ? 0.24 : 0.12), radius: isCentered ? 20 : 10, y: isCentered ? 12 : 6)
        }
        .buttonStyle(.pressable)
        .contextMenu { menu(design) }
        .accessibilityLabel(Text("\(design.name), \(design.kindTitle), \(design.displayFormat.title)"))
        .accessibilityHint(Text(isCentered ? tr("Ouvre l'éditeur") : tr("Amène ce widget au centre")))
        .accessibilityIdentifier(isCentered ? "carousel-center" : "carousel-item")
    }
}

/// The surface of a round button: the action color when prominent, glass otherwise.
private struct RoundSurface: ViewModifier {
    let isProminent: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isProminent {
            content.background(Color.accentColor, in: Circle())
        } else {
            content.cristalGlass(in: Circle())
        }
    }
}

/// A round action under the carousel: its symbol in a circle, its name below.
struct CarouselAction: View {
    let title: String
    let symbol: String
    var isProminent = false
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isProminent ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.accentColor))
                    .frame(width: 50, height: 50)
                    .modifier(RoundSurface(isProminent: isProminent))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// The categories of the person's widgets, as round icons: touch one to find a widget in it.
struct CategoryStrip: View {
    let designs: [WidgetDesign]
    @Binding var filter: WidgetShelfFilter
    @Environment(\.appStyle) private var style

    private struct Option: Identifiable {
        let filter: WidgetShelfFilter
        let title: String
        let symbol: String
        let colorHex: String
        let count: Int
        var id: String { title }
    }

    private var options: [Option] {
        var options = [Option(filter: .all, title: tr("Tous"), symbol: "square.grid.2x2.fill", colorHex: "2F8F7A", count: designs.count)]
        let favorites = designs.filter(\.isFavorite).count
        if favorites > 0 {
            options.append(Option(filter: .favorites, title: tr("Favoris"), symbol: "heart.fill", colorHex: "F2588F", count: favorites))
        }
        for category in WidgetCategory.allCases {
            let count = designs.filter { $0.kind.category == category }.count
            if count > 0 {
                options.append(Option(filter: .category(category), title: category.title, symbol: category.symbol, colorHex: category.colorHex, count: count))
            }
        }
        return options
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(options) { option in
                    let isSelected = filter == option.filter
                    let color = CristalPalette.of(style.id).category(option.colorHex)
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { filter = option.filter }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(color))
                                .frame(width: 50, height: 50)
                                .modifier(RoundSurface(isProminent: isSelected))
                                .overlay(alignment: .topTrailing) {
                                    Text("\(option.count)")
                                        .font(.caption2.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 20, minHeight: 20)
                                        .background(.screenFill, in: Capsule())
                                        .offset(x: 5, y: -3)
                                }
                            Text(option.title)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 62)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text("\(option.title), \(Fmt.plural(option.count, tr("widget"), tr("widgets")))"))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("shelf-\(option.title)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }
}
