import SwiftUI

struct TargetOption: Identifiable, Hashable {
    let id: String
    let title: String
}

/// Which item a widget follows, for kinds that show one element among several.
enum TargetOptions {
    static func title(for kind: WidgetKind) -> String {
        switch kind {
        case .habitStreak: "Habitude"
        case .counter: "Compteur"
        case .project: "Projet"
        case .deadline: "Échéance"
        case .savingsGoal: "Objectif"
        default: "Entreprise"
        }
    }

    @MainActor
    static func options(for kind: WidgetKind, model: AppModel) -> [TargetOption] {
        switch kind {
        case .habitStreak: model.content.habits.map { TargetOption(id: $0.id.uuidString, title: $0.name) }
        case .counter: model.productivity.counters.map { TargetOption(id: $0.id.uuidString, title: $0.name) }
        case .project: model.productivity.projects.map { TargetOption(id: $0.id.uuidString, title: $0.name) }
        case .deadline: model.productivity.deadlines.map { TargetOption(id: $0.id.uuidString, title: $0.title) }
        case .savingsGoal: model.budget.goals.map { TargetOption(id: $0.id.uuidString, title: $0.name) }
        case .companySnapshot, .companyRevenue, .companyStock:
            model.following.followed.map { TargetOption(id: String($0.cik), title: "\($0.name) (\($0.ticker))") }
        default: []
        }
    }
}

/// Editor options for the mini-app widgets: what to follow, and a shortcut to the data.
struct SpaceOptionsSection: View {
    @Binding var design: WidgetDesign
    @Environment(AppModel.self) private var model

    var body: some View {
        let kind = design.kind
        let targets = TargetOptions.options(for: kind, model: model)
        EditorSection(title: "Contenu") {
            VStack(alignment: .leading, spacing: 0) {
                if !targets.isEmpty {
                    Picker(TargetOptions.title(for: kind), selection: $design.options.targetID) {
                        Text("Automatique").tag(String?.none)
                        ForEach(targets) { option in
                            Text(option.title).tag(Optional(option.id))
                        }
                    }
                    .frame(minHeight: 44)
                    Divider()
                }
                if let space = kind.space ?? fallbackSpace(kind) {
                    NavigationLink {
                        SpaceView(space: space)
                    } label: {
                        HStack {
                            Label("Données de l'espace \(space.title)", systemImage: space.symbol)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if let note = note(for: kind) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
        }
    }

    private func fallbackSpace(_ kind: WidgetKind) -> Space? {
        switch kind {
        case .fitnessDashboard: .fitness
        case .moneyDashboard: .budget
        case .studentDashboard: .student
        case .marketOverview: .investing
        default: nil
        }
    }

    private func note(for kind: WidgetKind) -> String? {
        switch kind.category {
        case .dashboards:
            if [.aiSummary, .aiNutrition, .aiFinance, .aiProductivity].contains(kind) {
                return AIPhraser.isAvailable
                    ? "Rédigé par Apple Intelligence sur ton iPhone, uniquement à partir de tes données. Chaque chiffre est vérifié avant d'être affiché."
                    : "Calculé sur ton iPhone à partir de tes données, sans jamais inventer de chiffre. Avec Apple Intelligence (iOS 26), le texte est reformulé plus naturellement."
            }
            return "Ce tableau réunit plusieurs espaces et change selon ce que tu y notes."
        case .weather:
            return "Données Open-Meteo pour la ville choisie dans Réglages."
        case .investing, .markets:
            return "À titre informatif, pas un conseil financier."
        case .nutrition:
            return "Valeurs indicatives, pas un avis médical."
        default:
            return nil
        }
    }
}
