import SwiftUI
import WidgetKit

struct MyWidgetsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    /// The carousel: which widgets it shows, and the one in the middle.
    @State private var filter: WidgetShelfFilter = .all
    @State private var centeredID: UUID?
    @State private var pendingDeletion: WidgetDesign?
    /// Selection mode: several widgets picked, then deleted or merged together.
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    /// The same widgets in the order they were picked: a merge lays them out in that order.
    @State private var selectionOrder: [UUID] = []
    @State private var confirmsBatchDeletion = false
    @State private var showsFusion = false
    @State private var showsPaywall = false
    /// Where each selected card is on screen, for the merge animation.
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var fusionRun: FusionRun?

    private var selectedDesigns: [WidgetDesign] { model.designs.filter { selectedIDs.contains($0.id) } }
    private var orderedSelection: [WidgetDesign] {
        selectionOrder.compactMap { id in model.designs.first { $0.id == id } }
    }
    /// The merge the selection allows, if any (same category, sizes that fill a medium or a large widget).
    private var fusion: Fusion.Result? { isSelecting ? Fusion.result(for: orderedSelection) : nil }
    private var allShownSelected: Bool { !designs.isEmpty && designs.allSatisfy { selectedIDs.contains($0.id) } }

    private var designs: [WidgetDesign] {
        model.recentDesigns.filter(filter.allows)
    }

    /// The widget in the middle of the carousel.
    private var current: WidgetDesign? {
        designs.first { $0.id == centeredID } ?? designs.first
    }

    private struct CardRow: Identifiable {
        let designs: [WidgetDesign]
        var id: UUID { designs[0].id }
    }

    /// Small widgets two per row; medium and large widgets across the whole width, at their real proportions.
    private var rows: [CardRow] {
        var rows: [CardRow] = []
        var waiting: WidgetDesign?
        for design in designs {
            if design.displayFormat == .small {
                if let first = waiting {
                    rows.append(CardRow(designs: [first, design]))
                    waiting = nil
                } else {
                    waiting = design
                }
            } else {
                rows.append(CardRow(designs: [design]))
            }
        }
        if let waiting { rows.append(CardRow(designs: [waiting])) }
        return rows
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.designs.isEmpty {
                        EmptyStateView(
                            symbol: "rectangle.stack.badge.plus",
                            title: "Aucun widget pour l'instant",
                            message: "Choisis un modèle dans le Store, personnalise-le et enregistre-le. Il apparaîtra ici.",
                            actionTitle: "Ouvrir le Store"
                        ) { router.openExplore() }
                        .padding(20)
                    } else if isSelecting {
                        selectionGrid
                            .padding(20)
                    } else {
                        carousel
                    }
                }
                .id("top")
            }
            .onChange(of: fusionRun?.isDone) { _, done in
                if done == true { withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) } }
            }
            }
            .background(.screenFill)
            .navigationTitle(isSelecting ? selectionTitle : "Mes widgets")
            .navigationBarTitleDisplayMode(isSelecting ? .inline : .automatic)
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(allShownSelected ? "Tout désélectionner" : "Tout sélectionner") {
                            Haptics.tap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if allShownSelected {
                                    selectedIDs.subtract(designs.map(\.id))
                                } else {
                                    selectedIDs.formUnion(designs.map(\.id))
                                }
                                selectionOrder = selectionOrder.filter { selectedIDs.contains($0) }
                                    + designs.map(\.id).filter { id in selectedIDs.contains(id) && !selectionOrder.contains(id) }
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") { endSelection() }
                    }
                } else {
                    if !model.designs.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Sélectionner") {
                                withAnimation(.easeInOut(duration: 0.2)) { isSelecting = true }
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            router.lastSavedName = nil
                            router.isAddGuidePresented = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel(Text("Comment ajouter un widget"))
                        Button {
                            router.openExplore()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("Créer un widget"))
                    }
                }
            }
            .toolbar(isSelecting ? .hidden : .visible, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                if isSelecting { selectionBar }
            }
            .confirmationDialog(
                selectedIDs.count == 1 ? "Supprimer ce widget ?" : "Supprimer ces \(selectedIDs.count) widgets ?",
                isPresented: $confirmsBatchDeletion,
                titleVisibility: .visible
            ) {
                Button(selectedIDs.count == 1 ? "Supprimer le widget" : "Supprimer les \(selectedIDs.count) widgets", role: .destructive) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        model.delete(selectedDesigns)
                    }
                    Haptics.success()
                    endSelection()
                }
            } message: {
                Text("Les widgets qui les affichent sur ton écran d'accueil reviendront au modèle par défaut.")
            }
            .sheet(isPresented: $showsFusion) {
                if let merged = Fusion.merge(orderedSelection) {
                    FusionSheet(designs: orderedSelection, merged: merged) { keepsOriginals in
                        startFusion(merged: merged, keepsOriginals: keepsOriginals)
                    }
                }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .overlay {
                if let run = fusionRun {
                    FusionOverlay(run: run) { phase in
                        fusionPhaseChanged(phase)
                    }
                    .id(run.id)
                }
            }
            .onChange(of: model.designs.isEmpty) { _, isEmpty in
                if isEmpty { endSelection() }
            }
            .onChange(of: filter) { _, _ in
                centeredID = designs.first?.id
            }
            .onChange(of: designs.map(\.id)) { _, ids in
                // A filter left empty (last favorite removed, last widget of a category deleted) shows everything again.
                if ids.isEmpty, filter != .all {
                    filter = .all
                } else if let centeredID, !ids.contains(centeredID) {
                    self.centeredID = ids.first
                }
            }
            .onAppear {
                if router.startsFusion {
                    router.startsFusion = false
                    let all = model.recentDesigns
                    for i in all.indices {
                        for j in all.indices where j > i {
                            if Fusion.result(for: [all[i], all[j]]) != nil, !isSelecting {
                                isSelecting = true
                                selectionOrder = [all[i].id, all[j].id]
                                selectedIDs = Set(selectionOrder)
                                showsFusion = true
                            }
                        }
                    }
                }
                if router.startsSelection {
                    router.startsSelection = false
                    isSelecting = true
                    selectionOrder = model.recentDesigns.prefix(2).map(\.id)
                    selectedIDs = Set(selectionOrder)
                }
            }
            .confirmationDialog(
                "Supprimer « \(pendingDeletion?.name ?? "") » ?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    if let design = pendingDeletion { model.delete(design) }
                    pendingDeletion = nil
                }
            } message: {
                Text("Les widgets qui l'affichent sur ton écran d'accueil reviendront au modèle par défaut.")
            }
        }
    }

    // MARK: Carousel

    private var carousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(Fmt.plural(designs.count, "widget", "widgets")) · glisse pour les faire tourner")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .padding(.horizontal, 20)
            WidgetCarousel(
                designs: designs,
                centeredID: $centeredID,
                payload: { model.payload(for: $0) },
                onOpen: { router.openEditor($0, isNew: false) }
            ) { design in
                menuItems(design)
            }
            if let current {
                VStack(spacing: 3) {
                    Text(current.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    Text(currentDetails(current))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .animation(nil, value: current.id)
                actions(for: current)
                    .padding(.horizontal, 12)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Trouver un widget")
                    .font(.headline)
                    .padding(.horizontal, 20)
                CategoryStrip(designs: model.recentDesigns, filter: $filter)
            }
            .padding(.top, 2)
            if !model.isPremium {
                limitBanner
                    .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
        .onAppear {
            if centeredID == nil { centeredID = designs.first?.id }
        }
    }

    /// « Nutrition · Moyen · 2 sur 8 »
    private func currentDetails(_ design: WidgetDesign) -> String {
        var parts = [design.isCombo ? design.kindTitle : design.kind.category.title, design.displayFormat.title]
        if let index = designs.firstIndex(where: { $0.id == design.id }) {
            parts.append("\(index + 1) sur \(designs.count)")
        }
        return parts.joined(separator: " · ")
    }

    private func actions(for design: WidgetDesign) -> some View {
        HStack(alignment: .top, spacing: 4) {
            CarouselAction(title: "Modifier", symbol: "slider.horizontal.3", isProminent: true, identifier: "carousel-edit") {
                router.openEditor(design, isNew: false)
            }
            CarouselAction(title: "Dupliquer", symbol: "plus.square.on.square", identifier: "carousel-duplicate") {
                duplicate(design)
            }
            CarouselAction(title: "Favori", symbol: design.isFavorite ? "heart.fill" : "heart", identifier: "carousel-favorite") {
                Haptics.tap()
                model.toggleFavorite(design)
            }
            .accessibilityLabel(Text(design.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris"))
            CarouselAction(title: "Ajouter à l'écran", symbol: "apps.iphone.badge.plus", identifier: "carousel-place") {
                router.lastSavedName = design.name
                router.isAddGuidePresented = true
            }
            .accessibilityLabel(Text("Ajouter à l'écran d'accueil"))
        }
    }

    /// The same widget, same data, opened in the Studio to give it another look.
    private func makeVariant(of design: WidgetDesign) {
        guard let copy = model.duplicate(design, asVariant: true) else {
            router.isPaywallPresented = true
            return
        }
        Haptics.success()
        router.openEditor(copy, isNew: false, section: StudioSection.style.rawValue)
    }

    private func duplicate(_ design: WidgetDesign) {
        guard let copy = model.duplicate(design) else {
            router.isPaywallPresented = true
            return
        }
        Haptics.success()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            centeredID = copy.id
        }
    }

    // MARK: Selection grid

    private var selectionGrid: some View {
        LazyVStack(spacing: 20) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(row.designs) { design in
                        card(design)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(fusionRun?.hides(design.id) == true ? 0 : 1)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                    if row.designs.count == 1 && row.designs[0].displayFormat == .small {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }

    private var limitBanner: some View {
        let used = model.designs.count
        let limit = AppModel.freeDesignLimit
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(min(used, limit)) sur \(limit) widgets gratuits")
                    .font(.subheadline.weight(.semibold))
                BarView(progress: Double(used) / Double(limit), color: .accentColor, track: Color.secondary.opacity(0.2), height: 5)
            }
            Button("Illimité") { router.isPaywallPresented = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .card(padding: 14)
    }

    private var selectionTitle: String {
        selectedIDs.isEmpty ? "Sélection" : Fmt.plural(selectedIDs.count, "sélectionné", "sélectionnés")
    }

    private var selectionBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 10) {
                HStack {
                    Text(selectedIDs.isEmpty ? "Touche les widgets à supprimer ou à fusionner" : Fmt.plural(selectedIDs.count, "sélectionné", "sélectionnés"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Spacer(minLength: 8)
                    if let fusion {
                        Label("Fusion en widget \(fusion.format.title.lowercased())", systemImage: "arrow.triangle.merge")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .transition(.opacity)
                    }
                }
                HStack(spacing: 10) {
                    if fusion != nil {
                        Button {
                            showsFusion = true
                        } label: {
                            Label("Fusionner", systemImage: "arrow.triangle.merge")
                                .font(.headline)
                                .foregroundStyle(.onAccent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    Button(role: .destructive) {
                        confirmsBatchDeletion = true
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: fusion == nil ? nil : .infinity, minHeight: 44)
                            .padding(.horizontal, fusion == nil ? 6 : 0)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedIDs.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: fusion?.format)
        }
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Merge

    private func startFusion(merged: WidgetDesign, keepsOriginals: Bool) {
        let needsPaywall = (merged.usesPremiumFeatures && !model.isPremium) || (keepsOriginals && !model.canCreateDesign)
        let sources = orderedSelection.map { design in
            FusionRun.Source(design: design, payload: model.payload(for: design), frame: cardFrames[design.id] ?? .zero)
        }
        // Once the sheet has slid away, the cards gather and merge.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            if needsPaywall {
                showsPaywall = true
                return
            }
            fusionRun = FusionRun(sources: sources, merged: merged, mergedPayload: model.payload(for: merged), keepsOriginals: keepsOriginals)
        }
    }

    private func fusionPhaseChanged(_ phase: FusionOverlay.Phase) {
        guard let run = fusionRun else { return }
        switch phase {
        case .merged:
            // The new widget joins the collection; the originals leave it unless they are kept.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                model.save(run.merged)
                if !run.keepsOriginals { model.delete(run.sources.map(\.design)) }
            }
            Haptics.success()
            fusionRun?.isDone = true
        case .finished:
            fusionRun = nil
            endSelection()
        default:
            break
        }
    }

    private func endSelection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelecting = false
            selectedIDs = []
            selectionOrder = []
        }
    }

    private func toggleSelection(_ design: WidgetDesign) {
        Haptics.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            if selectedIDs.contains(design.id) {
                selectedIDs.remove(design.id)
                selectionOrder.removeAll { $0 == design.id }
            } else {
                selectedIDs.insert(design.id)
                selectionOrder.append(design.id)
            }
        }
    }

    @ViewBuilder private func card(_ design: WidgetDesign) -> some View {
        if isSelecting {
            let isSelected = selectedIDs.contains(design.id)
            Button {
                toggleSelection(design)
            } label: {
                DesignCard(design: design, payload: model.payload(for: design), width: nil, isPremiumUser: model.isPremium)
                    .scaleEffect(isSelected ? 0.93 : 1)
                    .opacity(isSelected ? 1 : 0.85)
                    .overlay(alignment: .topLeading) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.white), isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear))
                            .background(Circle().fill(Color.black.opacity(isSelected ? 0 : 0.25)).padding(2))
                            .shadow(color: .black.opacity(0.25), radius: 3)
                            .padding(8)
                    }
            }
            .buttonStyle(.plain)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrames[design.id] = $0 }
            .accessibilityLabel(Text(design.name))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            editableCard(design)
        }
    }

    private func editableCard(_ design: WidgetDesign) -> some View {
        Button {
            router.openEditor(design, isNew: false)
        } label: {
            DesignCard(design: design, payload: model.payload(for: design), width: nil, isPremiumUser: model.isPremium)
        }
        .buttonStyle(.plain)
        .contextMenu { menuItems(design) }
    }

    @ViewBuilder private func menuItems(_ design: WidgetDesign) -> some View {
        Button {
            router.openEditor(design, isNew: false)
        } label: {
            Label("Modifier", systemImage: "slider.horizontal.3")
        }
        Button {
            duplicate(design)
        } label: {
            Label("Dupliquer", systemImage: "plus.square.on.square")
        }
        Button {
            makeVariant(of: design)
        } label: {
            Label("Créer une variante", systemImage: "wand.and.stars")
        }
        Button {
            model.toggleFavorite(design)
        } label: {
            Label(design.isFavorite ? "Retirer des favoris" : "Favori", systemImage: design.isFavorite ? "heart.slash" : "heart")
        }
        Divider()
        Button(role: .destructive) {
            pendingDeletion = design
        } label: {
            Label("Supprimer", systemImage: "trash")
        }
    }
}
