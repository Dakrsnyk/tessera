import SwiftUI
import WidgetKit

struct MyWidgetsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var showsFavoritesOnly = false
    @State private var pendingDeletion: WidgetDesign?

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
            .navigationTitle("Mes widgets")
            .toolbar {
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

    private func card(_ design: WidgetDesign) -> some View {
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
