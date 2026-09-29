import SwiftUI
import WidgetKit

struct MyWidgetsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var showsFavoritesOnly = false
    @State private var pendingDeletion: WidgetDesign?
    /// Selection mode: several widgets picked, then deleted together.
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var confirmsBatchDeletion = false

    private var selectedDesigns: [WidgetDesign] { model.designs.filter { selectedIDs.contains($0.id) } }
    private var allShownSelected: Bool { !designs.isEmpty && designs.allSatisfy { selectedIDs.contains($0.id) } }

    private var designs: [WidgetDesign] {
        showsFavoritesOnly ? model.favoriteDesigns : model.recentDesigns
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.designs.isEmpty {
                        EmptyStateView(
                            symbol: "rectangle.stack.badge.plus",
                            title: "Aucun widget pour l'instant",
                            message: "Choisis un modèle dans Explorer, personnalise-le et enregistre-le. Il apparaîtra ici.",
                            actionTitle: "Explorer les widgets"
                        ) { router.openExplore() }
                    } else {
                        Picker("Afficher", selection: $showsFavoritesOnly) {
                            Text("Tous").tag(false)
                            Text("Favoris").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if !model.isPremium {
                            limitBanner
                        }

                        if designs.isEmpty {
                            EmptyStateView(symbol: "heart", title: "Aucun favori", message: "Maintiens un widget appuyé et choisis « Favori ».")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                                ForEach(designs) { design in
                                    card(design)
                                }
                            }
                        }
                    }
                }
                .padding(20)
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
            .onChange(of: model.designs.isEmpty) { _, isEmpty in
                if isEmpty { endSelection() }
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
        selectedIDs.isEmpty ? "Sélectionne des widgets" : Fmt.plural(selectedIDs.count, "widget sélectionné", "widgets sélectionnés")
    }

    private var selectionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text(selectedIDs.isEmpty ? "Touche les widgets à supprimer" : Fmt.plural(selectedIDs.count, "sélectionné", "sélectionnés"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                Button(role: .destructive) {
                    confirmsBatchDeletion = true
                } label: {
                    Label("Supprimer", systemImage: "trash")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func endSelection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelecting = false
            selectedIDs = []
        }
    }

    private func toggleSelection(_ design: WidgetDesign) {
        Haptics.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            if selectedIDs.contains(design.id) {
                selectedIDs.remove(design.id)
            } else {
                selectedIDs.insert(design.id)
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
        .contextMenu {
            Button {
                router.openEditor(design, isNew: false)
            } label: {
                Label("Modifier", systemImage: "slider.horizontal.3")
            }
            Button {
                if model.duplicate(design) == nil { router.isPaywallPresented = true }
            } label: {
                Label("Dupliquer", systemImage: "plus.square.on.square")
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
}
