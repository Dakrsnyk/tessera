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
        if design.kind.isPremium && !isPremium {
            PremiumLockedView(context: context)
        } else if family.isAccessory {
            AccessoryWidgetView(context: context)
        } else {
            KindContentView(context: context)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Self.padding(for: family))
                .environment(\.colorScheme, colorScheme(for: design))
        }
    }

    static func padding(for family: WidgetFamily) -> CGFloat {
        family == .systemLarge || family == .systemExtraLarge ? 18 : 16
    }

    /// Fixed dark or light themes set the scheme so system materials and symbols match the surface.
    private func colorScheme(for design: WidgetDesign) -> ColorScheme {
        switch design.background {
        case let .color(hex): return ColorMath.isLight(hex) ? .light : .dark
        case .gradient, .photo: return .dark
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
        if design.kind.isPremium && !isPremium { return DeepLink.premium.url }
        switch design.kind {
        case .tasks: return DeepLink.tasks.url
        case .habits: return DeepLink.habits.url
        case .hydration: return DeepLink.hydration.url
        case .moneyFlow: return DeepLink.money.url
        case .weather:
            if case .needsLocation = payload.weather { return DeepLink.weatherLocation.url }
        case .upNext:
            if case .needsAccess = payload.events { return DeepLink.calendarAccess.url }
        default:
            break
        }
        return isSaved ? DeepLink.design(design.id).url : DeepLink.explore.url
    }
}
