import SwiftUI
import WidgetKit

/// Temporary: the same views as the real widgets, without an App Intent configuration,
/// to tell a rendering problem from an intent problem in the CI placement test.
struct DiagnosticProvider: TimelineProvider {
    private func entry() -> DesignEntry {
        let design = WidgetDesign.starter(for: .clock)
        return DesignEntry(date: Date(), design: design, isSaved: false, payload: WidgetPayload(), isPremium: true)
    }

    func placeholder(in context: Context) -> DesignEntry {
        entry()
    }

    func getSnapshot(in context: Context, completion: @escaping (DesignEntry) -> Void) {
        WidgetLog.logger.log("diagnostic snapshot")
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DesignEntry>) -> Void) {
        WidgetLog.logger.log("diagnostic timeline")
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(900))))
    }
}

struct DiagnosticWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "tessera.diagnostic", provider: DiagnosticProvider()) { entry in
            DesignWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Diagnostic")
        .description("Vérification du rendu.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
