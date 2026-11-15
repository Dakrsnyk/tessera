import SwiftUI

// Le fond Cristal des écrans entiers. Séparé de Shared/ : `CristalBackdrop` est une vue de l'app, pas des widgets.

extension View {
    /// Fond Cristal d'un écran entier : la couleur de fond et ses deux nappes, derrière le contenu.
    func cristalScreen() -> some View {
        background { CristalBackdrop() }
    }

    /// Lists and forms on the style's background instead of the system gray.
    func styledList() -> some View {
        scrollContentBackground(.hidden)
            .cristalScreen()
    }
}
