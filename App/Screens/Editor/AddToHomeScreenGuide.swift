import SwiftUI

/// How to put a Tessera widget on the Home Screen or Lock Screen.
struct AddToHomeScreenGuide: View {
    var designName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var target = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let designName {
                        Label("« \(designName) » est prêt", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }

                    Picker("Emplacement", selection: $target) {
                        Text("Écran d'accueil").tag(0)
                        Text("Écran verrouillé").tag(1)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 16) {
                        if target == 0 {
                            AddStepRow(number: 1, symbol: "hand.tap", text: "Appuie longuement sur un espace vide de l'écran d'accueil")
                            AddStepRow(number: 2, symbol: "plus", text: "Touche « Modifier » en haut, puis « Ajouter un widget »")
                            AddStepRow(number: 3, symbol: "magnifyingglass", text: "Cherche « Tessera », choisis le type et la taille")
                            AddStepRow(number: 4, symbol: "slider.horizontal.3", text: "Une fois ajouté, touche le widget pendant que les icônes bougent et choisis ton design")
                        } else {
                            AddStepRow(number: 1, symbol: "lock", text: "Sur l'écran verrouillé, appuie longuement puis touche « Personnaliser »")
                            AddStepRow(number: 2, symbol: "rectangle.dashed", text: "Choisis « Écran verrouillé » et touche la zone des widgets")
                            AddStepRow(number: 3, symbol: "magnifyingglass", text: "Ajoute un widget Tessera (progression, compte à rebours, météo…)")
                            AddStepRow(number: 4, symbol: "slider.horizontal.3", text: "Touche-le pour choisir ton design")
                        }
                    }
                    .card(padding: 20)

                    Label {
                        Text("Pour changer le contenu d'un widget déjà posé : appui long sur le widget, puis « Modifier le widget ».")
                    } icon: {
                        Image(systemName: "lightbulb")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color.screenFill)
            .navigationTitle("Ajouter un widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Compris") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
