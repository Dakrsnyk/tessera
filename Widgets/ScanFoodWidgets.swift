import AppIntents
import SwiftUI
import WidgetKit

/// « Scanner un aliment » on the Lock Screen, next to Nutrition: a touch opens Ardane right on the
/// barcode scanner (iOS asks to unlock first). The rectangular size also shows today's calories.
/// A widget of its own: the scan buttons of the Nutrition widgets are left out of the Lock Screen.
struct ScanFoodLockWidget: Widget {
    /// Never change it: placed widgets would disappear.
    static let kind = "tessera.lock.scan-food"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ScanFoodProvider()) { entry in
            ScanFoodLockView(entry: entry)
        }
        .configurationDisplayName(tr("Scanner un aliment"))
        .description(tr("Touche-le pour scanner un code-barres : Ardane s'ouvre sur le scanner, une fois ton iPhone déverrouillé."))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct ScanFoodEntry: TimelineEntry {
    let date: Date
    /// « 1 250 kcal restantes », or what was eaten when no target was given.
    let calories: String?
}

struct ScanFoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScanFoodEntry {
        ScanFoodEntry(date: Date(), calories: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScanFoodEntry) -> Void) {
        let now = Date()
        completion(ScanFoodEntry(date: now, calories: context.isPreview ? nil : Self.calories(at: now)))
    }

    /// Now, then midnight (a new day starts from zero). Logging a meal reloads every widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanFoodEntry>) -> Void) {
        let now = Date()
        let midnight = DateMath.nextMidnight(after: now)
        let entries = [now, midnight].map { ScanFoodEntry(date: $0, calories: Self.calories(at: $0)) }
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }

    /// The same line as the « Calories restantes » widget on the Lock Screen.
    static func calories(at date: Date) -> String? {
        let store = SharedStore.shared
        let known = NutritionTiles.Targets(store.state(UserProfile.self))
        return NutritionTiles.caloriesLeft(store.state(NutritionState.self), now: date, known: known).inline
    }
}

struct ScanFoodLockView: View {
    let entry: ScanFoodEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(DeepLink.scanFood.url)
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder private var content: some View {
        if family == .accessoryRectangular {
            HStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.22)))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Scanner un aliment"))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .widgetAccentable()
                    Text(entry.calories ?? tr("Scanner un code-barres"))
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                    Text(tr("Scanner"))
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
                .widgetAccentable()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(tr("Scanner un aliment")))
        }
    }
}

/// The scanner among the controls (iOS 18): Control Center, the two buttons at the bottom of the Lock
/// Screen, or the Action button. It runs `OpenFoodScannerIntent` in the app (custom URL schemes can't be
/// opened from a control).
@available(iOS 18.0, *)
struct ScanFoodControl: ControlWidget {
    /// Never change it: placed controls would disappear.
    static let kind = "tessera.control.scan-food"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenFoodScannerIntent()) {
                Label(tr("Scanner"), systemImage: "barcode.viewfinder")
            }
        }
        .displayName("Scanner un aliment")
        .description("Ouvre Ardane sur le scanner de code-barres.")
    }
}
