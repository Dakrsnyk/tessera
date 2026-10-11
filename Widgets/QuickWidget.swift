import SwiftUI
import WidgetKit

/// A widget without any configuration: it shows the design saved most recently in the app
/// (or « Maintenant » before the first one). It relies on no App Intent, so it is offered even
/// where configurable widgets are not, and it is the quickest way to put Ardane on a screen.
struct QuickWidget: Widget {
    static let kind = "tessera.quick"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickProvider()) { entry in
            DesignWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(tr("Mon widget"))
        .description(tr("Ton dernier widget enregistré dans Ardane, sans aucun réglage."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct QuickProvider: TimelineProvider {
    func placeholder(in context: Context) -> DesignEntry {
        let design = WidgetDesign.starter(for: Self.fallbackKind(for: context.family))
        return DesignEntry(date: Date(), design: design, isSaved: false, payload: SamplePayload.make(for: design), isPremium: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DesignEntry) -> Void) {
        let (design, isSaved) = Self.pick(for: context.family)
        if context.isPreview && !isSaved {
            completion(DesignEntry(date: Date(), design: design, isSaved: false, payload: SamplePayload.make(for: design), isPremium: true))
            return
        }
        Task {
            let now = Date()
            let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
            completion(DesignEntry(date: now, design: design, isSaved: isSaved, payload: payload, isPremium: SharedStore.shared.premium.isPremium(at: now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DesignEntry>) -> Void) {
        let (design, isSaved) = Self.pick(for: context.family)
        Task {
            let now = Date()
            let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
            let isPremium = SharedStore.shared.premium.isPremium(at: now)
            let plan = TimelinePlanner.plan(for: design, payload: payload, now: now)
            let entries = plan.dates.map {
                DesignEntry(date: $0, design: design, isSaved: isSaved, payload: payload, isPremium: isPremium)
            }
            completion(Timeline(entries: entries, policy: plan.policy))
        }
    }

    /// The most recently used or edited design that fits the size.
    static func pick(for family: WidgetFamily) -> (WidgetDesign, Bool) {
        let saved = SharedStore.shared.designs
            .filter { $0.families.contains(family) }
            .sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
        if let design = saved.first {
            return (design, true)
        }
        return (WidgetDesign.starter(for: fallbackKind(for: family)), false)
    }

    static func fallbackKind(for family: WidgetFamily) -> WidgetKind {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: .progress
        default: .now
        }
    }
}
