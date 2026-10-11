import SwiftUI

/// How to put an Ardane widget on the Home Screen or Lock Screen.
struct AddToHomeScreenGuide: View {
    var designName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var target = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let designName {
                        Label(tr("« \(designName) » est prêt"), systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }

                    Picker(tr("Emplacement"), selection: $target) {
                        Text(tr("Écran d'accueil")).tag(0)
                        Text(tr("Écran verrouillé")).tag(1)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 16) {
                        if target == 0 {
                            AddStepRow(number: 1, symbol: "hand.tap", text: tr("Appuie longuement sur un espace vide de l'écran d'accueil"))
                            AddStepRow(number: 2, symbol: "plus", text: tr("Touche « Modifier » en haut, puis « Ajouter un widget »"))
                            AddStepRow(number: 3, symbol: "magnifyingglass", text: tr("Cherche « Ardane » : chaque espace a son entrée (Nutrition, Fitness, Budget…). Choisis la taille"))
                            AddStepRow(number: 4, symbol: "slider.horizontal.3", text: tr("Une fois ajouté, touche le widget pendant que les icônes bougent et choisis ton design, ou un modèle du catalogue"))
                        } else {
                            AddStepRow(number: 1, symbol: "lock", text: tr("Sur l'écran verrouillé, appuie longuement puis touche « Personnaliser »"))
                            AddStepRow(number: 2, symbol: "rectangle.dashed", text: tr("Choisis « Écran verrouillé » et touche la zone des widgets"))
                            AddStepRow(number: 3, symbol: "magnifyingglass", text: tr("Ajoute un widget Ardane (progression, compte à rebours, météo…)"))
                            AddStepRow(number: 4, symbol: "slider.horizontal.3", text: tr("Touche-le pour choisir ton design"))
                        }
                    }
                    .card(padding: 20)

                    Label {
                        Text(tr("Pour changer le contenu d'un widget déjà posé : appui long sur le widget, puis « Modifier le widget »."))
                    } icon: {
                        Image(systemName: "lightbulb")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(.screenGradient)
            .navigationTitle(tr("Ajouter un widget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Compris")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
