import SwiftUI
import WidgetKit

/// Renders a design at a given size. Used by the real widgets and by every preview in the app,
/// so what the user designs is exactly what lands on the Home Screen.
struct WidgetCanvas: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let date: Date
    let payload: WidgetPayload
    let isPremium: Bool
    let isInteractive: Bool

    /// Premium styling is shown as-is in app previews (to try before buying), but downgraded on the Home Screen.
    static func displayedDesign(_ design: WidgetDesign, isPremium: Bool, isPreview: Bool) -> WidgetDesign {
        (isPremium || isPreview) ? design : design.downgradedForFree()
    }

    var body: some View {
        let style = ResolvedStyle(design: design)
        let context = RenderContext(
            design: design, style: style, family: family, date: date,
            payload: payload, isInteractive: isInteractive
        )
        if design.usesPremiumKind && !isPremium {
            PremiumLockedView(context: context)
        } else if family.isAccessory {
            // A combined widget shows its first widget on the Lock Screen.
            if design.isCombo, let first = design.partDesigns.first {
                AccessoryWidgetView(context: RenderContext(
                    design: first, style: style, family: family, date: date, payload: payload, isInteractive: isInteractive
                ))
            } else {
                AccessoryWidgetView(context: context)
            }
        } else if design.isCombo {
            ComboWidgetView(context: context)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { StyleBorder(style: style) }
                .environment(\.colorScheme, colorScheme(for: design))
        } else {
            framed(KindContentView(context: context).frame(maxWidth: .infinity, maxHeight: .infinity), style: style)
                .overlay { StyleBorder(style: style) }
                .environment(\.colorScheme, colorScheme(for: design))
        }
    }

    /// The content with the density's margins, on an inner card when the shape is « Panneau ».
    @ViewBuilder private func framed<Content: View>(_ content: Content, style: ResolvedStyle) -> some View {
        let large = family == .systemLarge || family == .systemExtraLarge
        if style.isPanel {
            content
                .padding(style.padding(for: large) - 5)
                .background {
                    ContainerRelativeShape()
                        .fill(style.panel)
                        .styleDepth(style)
                }
                .padding(7)
        } else {
            content.padding(style.padding(for: large))
        }
    }

    static func padding(for family: WidgetFamily) -> CGFloat {
        family == .systemLarge || family == .systemExtraLarge ? 18 : 16
    }

    /// Fixed dark or light themes set the scheme so system materials and symbols match the surface.
    private func colorScheme(for design: WidgetDesign) -> ColorScheme {
        switch design.background {
        case let .color(hex): return ColorMath.isLight(hex) ? .light : .dark
        case .gradient:
            if let spec = design.effectiveStyle.gradient {
                return ColorMath.isLight(ColorMath.mix(spec.startHex, spec.endHex, 0.5 * spec.intensity)) ? .light : .dark
            }
            return .dark
        case .photo: return .dark
        case .glass: return GlassSurface.isLight(design.accentHex) ? .light : .dark
        case .theme: break
        }
        switch design.theme.isDarkSurface {
        case .some(true): return .dark
        case .some(false): return .light
        case .none: return currentScheme
        }
    }

    @Environment(\.colorScheme) private var currentScheme
}

struct KindContentView: View {
    let context: RenderContext

    var body: some View {
        switch context.design.kind {
        case .clock: ClockWidgetView(context: context)
        case .calendar: CalendarWidgetView(context: context)
        case .worldClock: WorldClockWidgetView(context: context)
        case .progress: ProgressWidgetView(context: context)
        case .countdown: CountdownWidgetView(context: context)
        case .yearDots: YearDotsWidgetView(context: context)
        case .tasks: TasksWidgetView(context: context)
        case .habits: HabitsWidgetView(context: context)
        case .focus: FocusWidgetView(context: context)
        case .upNext: UpNextWidgetView(context: context)
        case .note: NoteWidgetView(context: context)
        case .weather: WeatherWidgetView(context: context)
        case .crypto: CryptoWidgetView(context: context)
        case .moneyFlow: MoneyFlowWidgetView(context: context)
        case .hydration: HydrationWidgetView(context: context)
        default: TileView(tile: TileFactory.make(context), context: context)
        }
    }
}

/// Shown on the Home Screen when a free user places a Premium widget.
struct PremiumLockedView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        if context.family.isAccessory {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.fill")
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: context.design.kind.symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(s.accent)
                Text(context.design.kind.title)
                    .font(s.text(15, .semibold))
                    .foregroundStyle(s.primary)
                Label("Premium", systemImage: "lock.fill")
                    .font(s.text(11, .semibold))
                    .foregroundStyle(s.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(s.accent, in: Capsule())
                if !context.isSmall {
                    Text("Touche pour débloquer ce widget")
                        .font(s.text(11))
                        .foregroundStyle(s.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
    }
}

enum WidgetLinks {
    /// Where a tap on the widget should take the user.
    static func url(for design: WidgetDesign, payload: WidgetPayload, isPremium: Bool, isSaved: Bool) -> URL {
        if design.usesPremiumKind && !isPremium { return DeepLink.premium.url }
        switch design.kind {
        case .tasks: return DeepLink.tasks.url
        case .habits: return DeepLink.habits.url
        case .hydration: return DeepLink.hydration.url
        case .moneyFlow: return DeepLink.money.url
        case .weather:
            if case .needsLocation = payload.weather { return DeepLink.weatherLocation.url }
        case .upNext:
            if case .needsAccess = payload.events { return DeepLink.calendarAccess.url }
        case .sunCycle, .rainNext, .windUV, .weatherDetails, .weeklyForecast, .myDay, .morning, .now:
            if case .needsLocation = payload.weather { return DeepLink.weatherLocation.url }
        default:
            break
        }
        // Mini-app widgets open their space, where the data behind them is entered.
        if let space = design.kind.space {
            return DeepLink.space(space.rawValue).url
        }
        return isSaved ? DeepLink.design(design.id).url : DeepLink.explore.url
    }
}

/// A combined widget: its widgets side by side (two small in a row) or stacked (medium rows), each drawn
/// exactly as on its own at that size, separated by a hairline. A combined large shown in a medium
/// widget keeps its first row; any combined widget shown small keeps its first widget.
struct ComboWidgetView: View {
    let context: RenderContext

    var body: some View {
        let parts = context.options.parts
        let rows = ComboLayout.rows(parts) ?? [Array(parts.prefix(2))]
        let shown: [[ComboPart]] = context.isSmall ? [Array(parts.prefix(1))] : (context.isLarge ? rows : Array(rows.prefix(1)))
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 {
                    divider.frame(height: 1).padding(.horizontal, 14)
                }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, part in
                        if index > 0 {
                            divider.frame(width: 1).padding(.vertical, 14)
                        }
                        partView(part, family: context.isSmall || row.count > 1 ? .systemSmall : .systemMedium)
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(context.style.secondary.opacity(0.22))
    }

    private func partView(_ part: ComboPart, family: WidgetFamily) -> some View {
        // The widget as a whole can hold links (medium, large): its first nutrition widget gets the scanner.
        let scanKind = context.options.parts.first { NutritionTiles.scanKinds.contains($0.kind) }?.kind
        let sub = RenderContext(
            design: context.design.design(for: part), style: context.style, family: family,
            date: context.date, payload: context.payload, isInteractive: context.isInteractive,
            linksAllowed: context.allowsLinks && part.kind == scanKind
        )
        return KindContentView(context: sub)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
    }
}
