import AppIntents
import SwiftUI
import WidgetKit

/// « Mes widgets »: the only Ardane entry of the Home Screen gallery. It shows the person's own widgets,
/// made in the app: the gallery previews their latest one for each size, and « Modifier le widget » picks
/// any of the others. The identifier is the one of the former « Mon widget », so widgets already placed
/// keep working (without a choice, they still show the latest widget saved for their size).
struct QuickWidget: Widget {
    static let kind = "tessera.quick"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DesignWidgetIntent.self, provider: MyWidgetsProvider()) { entry in
            DesignWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(tr("Mes widgets"))
        .description(tr("Tes widgets créés dans Ardane. Touche longuement › Modifier le widget pour en choisir un autre."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The person's own widgets only: the one chosen, else the latest saved for the size, else an invitation
/// to make one in the app (never a widget of the catalog presented as theirs).
struct MyWidgetsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DesignEntry {
        let design = Self.latest(for: context.family) ?? Self.invitation
        return DesignEntry(date: Date(), design: design, isSaved: false, payload: SamplePayload.make(for: design), isPremium: true)
    }

    func snapshot(for configuration: DesignWidgetIntent, in context: Context) async -> DesignEntry {
        let now = Date()
        let (design, isSaved) = resolve(configuration, family: context.family)
        let payload = isSaved ? await PayloadLoader.load(for: design, allowNetwork: !context.isPreview, now: now) : SamplePayload.make(for: design, now: now)
        return DesignEntry(date: now, design: design, isSaved: isSaved, payload: payload, isPremium: SharedStore.shared.premium.isPremium(at: now))
    }

    func timeline(for configuration: DesignWidgetIntent, in context: Context) async -> Timeline<DesignEntry> {
        let now = Date()
        let (design, isSaved) = resolve(configuration, family: context.family)
        let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
        let isPremium = SharedStore.shared.premium.isPremium(at: now)
        let plan = TimelinePlanner.plan(for: design, payload: payload, now: now)
        let entries = plan.dates.map { DesignEntry(date: $0, design: design, isSaved: isSaved, payload: payload, isPremium: isPremium) }
        return Timeline(entries: entries, policy: plan.policy)
    }

    private func resolve(_ configuration: DesignWidgetIntent, family: WidgetFamily) -> (WidgetDesign, Bool) {
        if let id = configuration.design?.id, let uuid = UUID(uuidString: id), let saved = SharedStore.shared.design(id: uuid) {
            return (saved, true)
        }
        if let latest = Self.latest(for: family) { return (latest, true) }
        return (Self.invitation, false)
    }

    /// The widget used or changed most recently that fits the size, made for it first.
    static func latest(for family: WidgetFamily) -> WidgetDesign? {
        let fitting = SharedStore.shared.designs.filter { $0.families.contains(family) }
        let sorted = fitting.sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
        return sorted.first { $0.format?.family == family } ?? sorted.first
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
