import SwiftUI
import WidgetKit

/// Adding several widgets at once (a pack, a Home Screen): each widget in turn, with only the data it
/// needs, then a summary, then all of them saved together and sent to « Mes widgets ».
/// Data given for one widget is shared: the next widgets that need it find it already filled.
struct WidgetSetupFlow: View {
    let title: String
    let designs: [WidgetDesign]
    /// Closes whatever presented the flow, once the widgets are saved.
    let onSaved: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var step = 0
    @State private var showsPaywall = false
    @State private var previewFrame: CGRect = .zero

    private var isSummary: Bool { step >= designs.count }
    private var needsPremium: Bool { !model.isPremium && designs.contains(where: \.usesPremiumFeatures) }

    enum Status {
        case ready, toComplete, nothingNeeded
    }

    private func status(_ design: WidgetDesign) -> Status {
        if design.dataItems.isEmpty { return .nothingNeeded }
        return model.missingItems(design.dataItems).isEmpty ? .ready : .toComplete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progress
                if isSummary {
                    summary
                } else {
                    widgetStep(designs[step])
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: step)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.screenFill)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPaywall) { PaywallView() }
        .accessibilityIdentifier("setup-flow")
    }

    // MARK: Progress

    /// Which widget is being set, how many are left, and which are done.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSummary ? "Résumé" : "Widget \(step + 1) sur \(designs.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("setup-step")
            HStack(spacing: 5) {
                ForEach(Array(designs.enumerated()), id: \.offset) { index, design in
                    Button {
                        withAnimation { step = index }
                    } label: {
                        Capsule()
                            .fill(color(for: index, design))
                            .frame(height: 6)
                            .overlay {
                                if index == step && !isSummary {
                                    Capsule().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(design.name), \(statusText(status(design)))"))
                }
            }
        }
        .padding(.top, 8)
    }

    private func color(for index: Int, _ design: WidgetDesign) -> Color {
        if index == step && !isSummary { return .accentColor }
        switch status(design) {
        case .ready, .nothingNeeded: return index < step || isSummary ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.25)
        case .toComplete: return index < step || isSummary ? Color(hex: "F2A33A") : Color.secondary.opacity(0.25)
        }
    }

    private func statusText(_ status: Status) -> String {
        switch status {
        case .ready: "Prêt"
        case .toComplete: "À compléter plus tard"
        case .nothingNeeded: "Aucune donnée nécessaire"
        }
    }

    // MARK: A widget

    private func widgetStep(_ design: WidgetDesign) -> some View {
        let family = design.displayFormat.family
        let isExample = !model.hasOwnData(for: design)
        return VStack(alignment: .leading, spacing: 18) {
            ZStack {
                LinearGradient(
                    colors: [Color(light: "DCE3EA", dark: "1B1F26"), Color(light: "C9D3DD", dark: "11141A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                WidgetPreview(design: design, family: family, payload: model.previewPayload(for: design), width: family == .systemSmall ? 170 : min(330, WidgetMetrics.size(family).width))
                    .padding(20)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topLeading) {
                if isExample { ExampleBadge().padding(12) }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
            VStack(alignment: .leading, spacing: 2) {
                Text(design.name)
                    .font(.title3.weight(.bold))
                Text("\(design.kindTitle) · \(design.displayFormat.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if design.dataItems.isEmpty {
                Label("Aucune donnée à renseigner : ce widget est prêt.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .card(padding: 14)
            } else {
                WidgetDataSection(items: design.dataItems, title: "Ce qu'il lui faut")
            }
        }
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vérifie tes widgets avant de les enregistrer. Ce qui manque pourra être ajouté plus tard dans « Mes informations ».")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(Array(designs.enumerated()), id: \.offset) { index, design in
                    Button {
                        withAnimation { step = index }
                    } label: {
                        HStack(spacing: 12) {
                            let family = design.displayFormat.family
                            WidgetPreview(design: design, family: family, payload: model.previewPayload(for: design), width: 52 * family.aspectRatio)
                                .frame(width: 112, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(design.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                statusLabel(status(design))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < designs.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
            if !model.isPremium, model.designs.count + designs.count > AppModel.freeDesignLimit {
                Label("La version gratuite garde \(AppModel.freeDesignLimit) widgets : les premiers seront ajoutés, Premium les ajoute tous.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup-summary")
    }

    @ViewBuilder private func statusLabel(_ status: Status) -> some View {
        switch status {
        case .ready:
            Label("Prêt", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        case .toComplete:
            Label("À compléter plus tard", systemImage: "exclamationmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(light: "8A4B00", dark: "F5B25A"))
        case .nothingNeeded:
            Label("Aucune donnée nécessaire", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Buttons

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                if !isSummary {
                    Button("Passer") { next() }
                        .font(.headline)
                        .frame(minHeight: 50)
                        .padding(.horizontal, 12)
                        .accessibilityIdentifier("setup-skip")
                }
                Button(action: isSummary ? save : next) {
                    Text(primaryTitle)
                        .font(.headline)
                        .foregroundStyle(.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .accessibilityIdentifier("setup-next")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var primaryTitle: String {
        if isSummary {
            return needsPremium ? "Débloquer avec Premium" : "Enregistrer les \(designs.count) widgets"
        }
        return step == designs.count - 1 ? "Voir le résumé" : "Suivant"
    }

    private func next() {
        Haptics.tap()
        withAnimation { step = min(step + 1, designs.count) }
    }

    private func save() {
        if needsPremium {
            showsPaywall = true
            return
        }
        let added = model.install(designs: designs)
        guard added > 0 else {
            showsPaywall = true
            return
        }
        Haptics.success()
        // The widgets gather and fly into « Mes widgets » while the sheet closes.
        router.saveFlight = SaveFlight(designs: Array(designs.prefix(added)), source: previewFrame)
        onSaved()
    }
}
