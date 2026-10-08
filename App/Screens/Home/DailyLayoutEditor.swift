import SwiftUI

/// « Mon Quotidien » arranged by hand, from Home: the order of the cards (drag), their size (half or
/// full width) and which ones show. Every change is saved at once; « Disposition automatique » gives
/// the order back to Tessera (what matters at this moment of the day first).
struct DailyLayoutEditor: View {
    /// The cards Home can show now (only those with real data), in the automatic order.
    let available: [DailyBrief.Tile]
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var settings: AppSettings { model.settings }

    /// Shown cards in the order on screen, then the hidden ones.
    private var shown: [DailyBrief.Tile] {
        DailyBrief.arranged(available, order: settings.dailyOrder, hidden: settings.dailyHidden)
    }

    private var hidden: [DailyBrief.Tile] {
        available.filter { settings.dailyHidden.contains($0.id) }
    }

    private var isAutomatic: Bool {
        settings.dailyOrder.isEmpty && settings.dailyHidden.isEmpty && settings.dailyWide.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(shown) { tile in
                        row(tile, isHidden: false)
                    }
                    .onMove(perform: move)
                } header: {
                    Text(tr("Sur l'Accueil"))
                } footer: {
                    Text(tr("Fais glisser une carte pour la déplacer. ½ : à côté d'une autre carte ; Large : toute la largeur."))
                }
                if !hidden.isEmpty {
                    Section(tr("Masquées")) {
                        ForEach(hidden) { tile in
                            row(tile, isHidden: true)
                        }
                    }
                }
                Section {
                    Button {
                        model.updateSettings {
                            $0.dailyOrder = []
                            $0.dailyHidden = []
                            $0.dailyWide = [:]
                        }
                    } label: {
                        Label(tr("Disposition automatique"), systemImage: "wand.and.stars")
                    }
                    .disabled(isAutomatic)
                } footer: {
                    Text(tr("Automatique : Tessera met d'abord ce qui compte maintenant (repas, séance du jour, cours…), selon ce que tu as renseigné."))
                }
            }
            .styledList()
            .environment(\.editMode, .constant(.active))
            .navigationTitle(tr("Mon Quotidien"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ tile: DailyBrief.Tile, isHidden: Bool) -> some View {
        let info = Self.info(tile)
        let wide = settings.dailyWide[tile.id] ?? tile.isWide
        return HStack(spacing: 12) {
            Image(systemName: info.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: info.colorHex))
                .frame(width: 30, height: 30)
                .background(Color(hex: info.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(info.title)
                .foregroundStyle(isHidden ? Color.secondary : Color.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !isHidden {
                Picker(tr("Taille"), selection: Binding(
                    get: { wide },
                    set: { value in model.updateSettings { $0.dailyWide[tile.id] = value } }
                )) {
                    Text("½").tag(false)
                    Text(tr("Large")).tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .labelsHidden()
            }
            Button {
                Haptics.tap()
                model.updateSettings { settings in
                    if isHidden {
                        settings.dailyHidden.removeAll { $0 == tile.id }
                    } else {
                        settings.dailyHidden.append(tile.id)
                    }
                }
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(isHidden ? Color.secondary : Color.accentColor)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isHidden ? tr("Afficher \(info.title)") : tr("Masquer \(info.title)")))
        }
    }

    private func move(_ source: IndexSet, _ destination: Int) {
        var ids = shown.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        Haptics.tap()
        model.updateSettings { $0.dailyOrder = ids }
    }

    /// The name, symbol and color of a card, as Home shows it.
    static func info(_ tile: DailyBrief.Tile) -> (title: String, symbol: String, colorHex: String) {
        switch tile {
        case .nutrition: (tr("Nutrition"), "fork.knife", "F08A24")
        case .workout: (tr("Séance du jour"), "figure.strengthtraining.traditional", "E5484D")
        case .classes: (tr("Cours"), "graduationcap.fill", "3366FF")
        case .agenda: (tr("Agenda"), "calendar", "8C6CFF")
        case .habits: (tr("Habitudes"), "repeat", "7FA33A")
        case .water: (tr("Eau"), "drop.fill", "3A8DDE")
        case .steps: (tr("Pas"), "figure.walk", "12A4B5")
        case .budget: (tr("Budget"), "creditcard.fill", "2B9A66")
        case .weather: (tr("Météo"), "cloud.sun.fill", "3A8DDE")
        case .reminders: (tr("À ne pas oublier"), "bell.fill", "E5484D")
        case .priorities: (tr("Top 3"), "star.fill", "F5A524")
        case .invite: (tr("Mes données"), "plus", "8E8E93")
        }
    }
}
