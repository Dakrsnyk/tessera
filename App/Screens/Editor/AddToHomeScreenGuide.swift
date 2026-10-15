import SwiftUI

/// How to put an Ardane widget on the Home Screen or Lock Screen. iOS can't list each widget made in
/// the gallery: « Mes widgets » shows, for each size, the latest widget of that size, and a widget added
/// keeps it (see `MyWidgetsChoice`).
struct AddToHomeScreenGuide: View {
    var designName: String?
    /// The widget the guide is about, when the caller knows it (two widgets can share a name).
    var designID: UUID?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var target = 0

    /// The widget the guide is about (just saved, or picked in « Mes widgets »).
    private var savedDesign: WidgetDesign? {
        Self.subject(id: designID, name: designName, in: model.designs)
    }

    /// By its id, else by its name when no other widget has it: with namesakes, the steps stay generic
    /// rather than describe the wrong widget.
    static func subject(id: UUID?, name: String?, in designs: [WidgetDesign]) -> WidgetDesign? {
        if let id { return designs.first { $0.id == id } }
        guard let name else { return nil }
        let named = designs.filter { $0.name == name }
        return named.count == 1 ? named.first : nil
    }

    /// Whether the gallery shows it: each size previews the latest widget of that size.
    private var isInGallery: Bool {
        guard let design = savedDesign, let format = design.format else { return false }
        return MyWidgetsChoice.latest(in: model.designs, for: format.family)?.id == design.id
    }

    private var galleryStep: String {
        if isInGallery, let design = savedDesign, let format = design.format {
            let size = format.title
            let name = design.name
            return tr("Cherche « Ardane », puis « Mes widgets », et fais défiler jusqu'à la taille \(size) : « \(name) » y est")
        }
        return tr("Cherche « Ardane », puis « Mes widgets » : chaque taille montre ton dernier widget de cette taille")
    }

    private var chooseStep: String {
        if let design = savedDesign, !isInGallery {
            let name = design.name
            return tr("Une fois ajouté, touche le widget pendant que les icônes bougent et choisis « \(name) »")
        }
        return tr("Une fois ajouté, touche le widget pendant que les icônes bougent pour choisir un autre de tes widgets")
    }

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
                            AddStepRow(number: 3, symbol: "magnifyingglass", text: galleryStep)
                            AddStepRow(number: 4, symbol: "pin", text: tr("Ajoute-le : il garde ce widget, même quand tu en crées d'autres"))
                            AddStepRow(number: 5, symbol: "slider.horizontal.3", text: chooseStep)
                        } else {
                            AddStepRow(number: 1, symbol: "lock", text: tr("Sur l'écran verrouillé, appuie longuement puis touche « Personnaliser »"))
                            AddStepRow(number: 2, symbol: "rectangle.dashed", text: tr("Choisis « Écran verrouillé » et touche la zone des widgets"))
                            AddStepRow(number: 3, symbol: "magnifyingglass", text: tr("Ajoute l'essentiel d'une mini-app Ardane (Nutrition, Fitness, Planning, Finances…)"))
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

                    if target == 1 {
                        Label {
                            Text(tr("Pour scanner un aliment d'un geste, ajoute « Scanner un aliment » à côté de Nutrition, ou à la place d'un bouton en bas de l'écran verrouillé (iOS 18). Ardane s'ouvre sur le scanner une fois ton iPhone déverrouillé."))
                        } icon: {
                            Image(systemName: "barcode.viewfinder")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
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
