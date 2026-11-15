import SwiftUI

/// The Créer tab: it opens straight on the Studio with a widget already proposed. « Changer de widget »
/// opens every other one (spaces, photos and quotes, Lock Screen) in a sheet; the one chosen replaces the
/// Studio's widget. After a save the Studio starts again on a new proposal while the widget flies away.
struct CreateView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    /// What the Studio is on; a new request (new id) starts it again from zero (history, photo, save guard).
    @State private var request: EditorRequest?
    /// The sheet of every other widget.
    @State private var changing = false
    /// Test captures (`creator-<space>`): the full creator of a space, over the Studio.
    @State private var combining: Space?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.spacePath) {
            Group {
                if let request {
                    WidgetStudio(request: request, isPushed: true, onChangeWidget: { changing = true }) { propose() }
                        .id(request.id)
                } else {
                    Color.clear
                }
            }
            .navigationDestination(for: Space.self) { space in
                SpaceView(space: space)
            }
        }
        .sheet(isPresented: $changing) {
            SpacesView(onChoose: use)
        }
        .sheet(item: $combining) { space in
            SpaceBuilderView(space: space, combines: true, onChoose: use)
        }
        .onAppear {
            if request == nil { propose() }
            if router.showsLockScreenCreator { changing = true }
            openRequestedCreator()
        }
        // A category tapped on the Home tab while this tab was already loaded.
        .onChange(of: router.requestedCreator) { _, _ in openRequestedCreator() }
    }

    private func propose() {
        request = EditorRequest(
            design: SpaceCatalog.proposal(for: model.profile.preferredSpaces, isPremium: model.isPremium),
            isNew: true, section: StudioSection.size.rawValue
        )
    }

    /// A widget chosen in a sheet: the sheets close and the Studio opens on it.
    private func use(_ designs: [WidgetDesign]) {
        guard !designs.isEmpty else { return }
        combining = nil
        changing = false
        request = EditorRequest(designs: designs, isNew: true, section: StudioSection.size.rawValue)
    }

    private func openRequestedCreator() {
        guard let space = router.requestedCreator else { return }
        router.requestedCreator = nil
        combining = space
    }
}
