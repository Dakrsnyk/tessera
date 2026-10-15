import AppIntents
import SwiftUI
import WidgetKit

/// « Mes widgets »: the only Ardane entry of the Home Screen gallery. It shows the person's own widgets,
/// made in the app: each size of the gallery previews their latest widget of that size, a widget added
/// keeps that one for good (the default of its configuration, see `MyWidgetsChoice`), and « Modifier le
/// widget » picks any of the others. The identifier is the one of the former « Mon widget », so widgets
/// already placed keep working.
struct QuickWidget: Widget {
    static let kind = "tessera.quick"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DesignWidgetIntent.self, provider: MyWidgetsProvider()) { entry in
            DesignWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(tr("Mes widgets"))
        .description(tr("Ajoute ton dernier widget de cette taille : il restera le même. Pour un autre, touche longuement › Modifier le widget."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The person's own widgets only: the one chosen or fixed when added, else the one remembered for the
/// size, else an invitation to make one in the app (never a widget of the catalog presented as theirs).
struct MyWidgetsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DesignEntry {
        let design = MyWidgetsChoice.latest(in: SharedStore.shared.designs, for: context.family) ?? Self.invitation
        return DesignEntry(date: Date(), design: design, isSaved: false, payload: SamplePayload.make(for: design), isPremium: true)
    }

    func snapshot(for configuration: DesignWidgetIntent, in context: Context) async -> DesignEntry {
        let now = Date()
        let (design, isSaved) = resolve(configuration, in: context)
        let payload = isSaved ? await PayloadLoader.load(for: design, allowNetwork: !context.isPreview, now: now) : SamplePayload.make(for: design, now: now)
        return DesignEntry(date: now, design: design, isSaved: isSaved, payload: payload, isPremium: SharedStore.shared.premium.isPremium(at: now))
    }

    func timeline(for configuration: DesignWidgetIntent, in context: Context) async -> Timeline<DesignEntry> {
        let now = Date()
        let (design, isSaved) = resolve(configuration, in: context)
        let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
        let isPremium = SharedStore.shared.premium.isPremium(at: now)
        let plan = TimelinePlanner.plan(for: design, payload: payload, now: now)
        let entries = plan.dates.map { DesignEntry(date: $0, design: design, isSaved: isSaved, payload: payload, isPremium: isPremium) }
        return Timeline(entries: entries, policy: plan.policy)
    }

    /// A configured widget never changes. One without a usable configuration keeps the widget remembered
    /// for its size; the gallery preview shows the latest instead, the one a new widget gets.
    private func resolve(_ configuration: DesignWidgetIntent, in context: Context) -> (WidgetDesign, Bool) {
        let format = WidgetFormat(context.family)
        let rememberedID: UUID? = context.isPreview ? nil : format.flatMap { Self.remembered($0) }
        let choice = MyWidgetsChoice.resolve(configuration.design?.id, family: context.family, designs: SharedStore.shared.designs, remembered: rememberedID)
        guard let design = choice.design else { return (Self.invitation, false) }
        if choice.isFallback, !context.isPreview, let format, design.id != rememberedID {
            Self.remember(design.id, for: format)
        }
        return (design, true)
    }

    private static func rememberedKey(_ format: WidgetFormat) -> String {
        "myWidgets.remembered.\(format.rawValue)"
    }

    /// The widget shown by the placed widgets of this size that have no configuration of their own.
    static func remembered(_ format: WidgetFormat) -> UUID? {
        (UserDefaults(suiteName: AppGroup.identifier)?.string(forKey: rememberedKey(format))).flatMap(UUID.init(uuidString:))
    }

    static func remember(_ id: UUID, for format: WidgetFormat) {
        UserDefaults(suiteName: AppGroup.identifier)?.set(id.uuidString, forKey: rememberedKey(format))
    }

    /// Before the first widget: where to make it.
    static var invitation: WidgetDesign {
        var design = WidgetDesign(kind: .note)
        design.name = tr("Mes widgets")
        design.options.noteTitle = tr("Mes widgets")
        design.options.noteText = tr("Crée ton widget dans Ardane : il apparaîtra ici.")
        return design
    }
}
