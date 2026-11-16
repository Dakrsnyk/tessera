import SwiftUI
import WidgetKit

/// The Créer tab (« taille d'abord », 2026-11-16): a size, then a category, then the widgets of that category made
/// into one widget (`CreateFlowView`); the Studio is pushed on it with that widget. « Changer de widget » goes back
/// to the categories at the same size. After a save the Studio closes back to the sizes while the widget flies away.
struct CreateView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    /// What the Studio pushed on the start screen is on; nil = the start screen. A new request (new id)
    /// starts the Studio again from zero (history, photo, save guard).
    @State private var route: StudioRoute?
    /// The step of the start (size, category, widgets).
    @State private var step: CreateStep = .size
    /// The size of the widget in the Studio: « Changer de widget » goes back to the categories at that size.
    @State private var openedFormat: WidgetFormat = .medium
    /// « Écran verrouillé » of the start screen: the Lock Screen widgets in a sheet.
    @State private var showsLockScreen = false
    /// Test captures: the full creator of a space, over the start screen (see `openRequestedCreator`).
    @State private var combining: Space?

    /// A request for the Studio, as a navigation value (`EditorRequest` is only Identifiable).
    private struct StudioRoute: Hashable {
        let request: EditorRequest

        static func == (lhs: StudioRoute, rhs: StudioRoute) -> Bool { lhs.request.id == rhs.request.id }
        func hash(into hasher: inout Hasher) { hasher.combine(request.id) }
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.spacePath) {
            CreateFlowView(step: $step, onOpen: open, onLockScreen: { showsLockScreen = true })
                .navigationDestination(for: Space.self) { space in
                    SpaceView(space: space)
                }
                .navigationDestination(item: $route) { item in
                    WidgetStudio(request: item.request, isPushed: true, onChangeWidget: changeWidget) { closeStudio() }
                        .id(item.request.id)
                }
        }
        .sheet(isPresented: $showsLockScreen) {
            LockScreenSheet(onChoose: use, onChooseLock: useLock)
        }
        .sheet(item: $combining) { space in
            SpaceBuilderView(space: space, combines: true, onChoose: use)
        }
        .onAppear {
            if router.showsLockScreenCreator {
                router.showsLockScreenCreator = false
                showsLockScreen = true
            }
            openRequestedCreator()
        }
        // A category tapped on the Home tab while this tab was already loaded.
        .onChange(of: router.requestedCreator) { _, _ in openRequestedCreator() }
    }

    /// Pushes the Studio on a request.
    private func open(_ request: EditorRequest) {
        openedFormat = request.design.displayFormat
        route = StudioRoute(request: request)
    }

    /// The Studio is done (saved or dropped): back to the sizes.
    private func closeStudio() {
        route = nil
        step = .size
    }

    /// « Changer de widget »: back to the categories, at the size of the widget being made.
    private func changeWidget() {
        route = nil
        step = .category(openedFormat)
    }

    /// A widget chosen in a sheet: the sheets close and the Studio opens on it.
    private func use(_ designs: [WidgetDesign]) {
        guard !designs.isEmpty else { return }
        combining = nil
        showsLockScreen = false
        open(EditorRequest(designs: designs, isNew: true, section: StudioSection.size.rawValue))
    }

    /// A Lock Screen widget chosen: the Studio opens on its size, on the Lock Screen shape the card showed.
    private func useLock(_ design: WidgetDesign, _ family: WidgetFamily) {
        combining = nil
        showsLockScreen = false
        open(EditorRequest(design: design, isNew: true, section: StudioSection.size.rawValue, family: family))
    }

    /// A category touched on Home, or a capture (`creator-<space>`): the Studio on the « Pour toi » widget of
    /// that space. The captures that drive the space creator itself (a size, a selection, kinds, the Studio
    /// started from it) keep it as a sheet; only test builds read those options.
    private func openRequestedCreator() {
        guard let space = router.requestedCreator else { return }
        router.requestedCreator = nil
        #if DEBUG
        let defaults = UserDefaults.standard
        let needsBuilder = defaults.string(forKey: "screenshotCreatorFormat") != nil
            || defaults.bool(forKey: "screenshotCreatorMulti")
            || defaults.string(forKey: "screenshotCreatorKinds") != nil
            || defaults.bool(forKey: "screenshotCreatorStudio")
        if needsBuilder {
            combining = space
            return
        }
        #endif
        let request = EditorRequest(
            design: SpaceCatalog.startDesign(for: space, isPremium: model.isPremium),
            isNew: true, section: StudioSection.size.rawValue
        )
        // Pushed once the tab is on screen: a push made while the stack appears can be dropped.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            open(request)
        }
    }
}

/// The Lock Screen widgets (« Écran verrouillé » of the start screen), in their own sheet.
private struct LockScreenSheet: View {
    let onChoose: ([WidgetDesign]) -> Void
    var onChooseLock: ((WidgetDesign, WidgetFamily) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LockScreenCreator(onChoose: onChoose, onChooseLock: onChooseLock)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .cristalScreen()
            .navigationTitle(tr("Écran verrouillé"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
            }
        }
    }
}
