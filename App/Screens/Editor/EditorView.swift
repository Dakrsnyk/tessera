import PhotosUI
import SwiftUI
import WidgetKit

/// The Studio in its own sheet: a saved widget from « Mes widgets », or a new one from the Store.
struct EditorView: View {
    let request: EditorRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WidgetStudio(request: request, isPushed: false) { dismiss() }
        }
    }
}

/// Photos imported while editing. Those the saved widgets don't use are deleted once the Studio is gone
/// for good (not when a page is pushed over it, nor when a change is undone).
final class StudioPhotoSession {
    var imported: [String] = []
    var kept: Set<String> = []

    deinit {
        for name in imported where !kept.contains(name) {
            ImageStore.delete(named: name)
        }
    }
}

/// The Widget Studio (« l'Atelier »): every widget is made and changed here, whether it comes from « Créer », the
/// Store, a pack or « Mes widgets ». Three chapters under the stage: « Contenu » (the size, the widgets inside, what
/// the widget shows), « Disposition » (how the widgets inside are laid out) and « Style » (the look). The stage acts on
/// the widget: a touch on a widget inside opens it, « + » adds one. Several widgets made together are edited one
/// after the other and can share their look. Every change can be undone and redone.
struct WidgetStudio: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    /// Pushed inside another flow (a creation, a pack): its back button returns to the selection.
    let isPushed: Bool
    /// Closes the Studio, and the flow that opened it, once the widgets are saved or the edit dropped.
    let onClose: () -> Void
    /// The Créer tab: opens the other widgets. Gives the Studio a « Changer de widget » button under the preview.
    let onChangeWidget: (() -> Void)?

    @State private var designs: [WidgetDesign]
    @State private var index = 0
    @State private var family: WidgetFamily
    @State private var paywall: PaywallContext?
    /// A double tap on « Enregistrer » saves once (not two celebrations and two flights).
    @State private var saveGuard = TapGuard()
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var backgroundTab: BackgroundKind
    @State private var previewFrame: CGRect = .zero
    /// The chapter open under the stage, and those already opened (a check on their badge).
    @State private var chapter: StudioChapter
    @State private var visitedChapters: Set<StudioChapter>
    /// The tool open in « Style » (never « Taille » nor « Contenu », which are in the chapter « Contenu »).
    @State private var section: StudioSection
    /// Widgets made together wear the same look while this is on: a change to one goes to all.
    @State private var sharesLook: Bool
    // Undo and redo: the widgets as they were before each change, and after each undo.
    @State private var past: [[WidgetDesign]] = []
    @State private var future: [[WidgetDesign]] = []
    @State private var lastChange = Date.distantPast
    @State private var restored: [WidgetDesign]?
    @State private var photos = StudioPhotoSession()
    /// What « Contenu » shows: the widgets inside, one of them, or the choice of a widget to add or put in its place.
    @State private var partsPanel: StudioPartsPanel = .list
    /// Where « Fermer » of the choice of a widget goes back to (the list, or the widget it was opened from).
    @State private var pickerBack: StudioPartsPanel = .list
    /// After an edit of the widgets inside: the size that changed (with « Annuler »), or why nothing changed.
    @State private var comboNote: StudioComboNote?
    /// « Sur mon écran »: the widget on a Home Screen, at its real size.
    @State private var showsOnMyScreen = false
    /// « Enregistrer le widget » touched in « Sur mon écran »: saved once it has closed.
    @State private var savesAfterPreview = false

    private let isNew: Bool
    private let originals: [WidgetDesign]

    init(request: EditorRequest, isPushed: Bool, onChangeWidget: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        // SwiftUI builds a navigation destination before it is shown, sometimes before the widgets
        // are ready: never an empty list.
        let designs = request.designs.isEmpty ? [request.design] : request.designs
        _designs = State(initialValue: designs)
        // The size the request asks for (a Lock Screen size from its creator) when the widget has it, else its own.
        var opening = request.design.displayFormat.family
        if let asked = request.family, request.design.families.contains(asked) { opening = asked }
        _family = State(initialValue: opening)
        _backgroundTab = State(initialValue: BackgroundKind(request.design.background))
        // « Contenu » (where « Taille » and « Contenu » now are), or « Style » on the tool the request names.
        var tool: StudioSection?
        if let asked = request.section.flatMap(StudioSection.init(name:)), asked != .size, asked != .content { tool = asked }
        let first: StudioChapter = tool == nil ? .content : .style
        _chapter = State(initialValue: first)
        _visitedChapters = State(initialValue: [first])
        _section = State(initialValue: tool ?? .theme)
        _sharesLook = State(initialValue: designs.count > 1 && designs.dropFirst().allSatisfy { $0.withLook(of: designs[0]) == $0 })
        isNew = request.isNew
        originals = designs
        self.isPushed = isPushed
        self.onClose = onClose
        self.onChangeWidget = onChangeWidget
    }

    private var design: WidgetDesign { designs[index] }
    private var edited: Binding<WidgetDesign> { $designs[index] }
    private var hasChanges: Bool { isNew || designs != originals }
    private var needsPremium: Bool { !model.isPremium && designs.contains(where: \.usesPremiumFeatures) }
    /// The widgets this save keeps: every new one in order within the free limit (photos and quotes always),
    /// all of them with Premium or once saved.
    private var savedDesigns: [WidgetDesign] { isNew ? model.fitting(designs) : designs }
    /// New widgets beyond the free limit (photos and quotes never count): the Studio says so from the start.
    private var exceedsFreeLimit: Bool { isNew && savedDesigns.count < designs.count }

    private var title: String {
        // In the Créer tab the Studio is the tab itself: it carries the tab's name, as in the « Atelier » design.
        if onChangeWidget != nil { return tr("Créer") }
        if !isNew { return tr("Studio") }
        return designs.count > 1 ? tr("Nouveaux widgets") : tr("Nouveau widget")
    }

    // The body is split in parts so each is type-checked on its own.
    var body: some View {
        let input = studioInput
        let sections = Self.sections(for: input)
        observed(dialogs(screen(input, sections: sections)), sections: sections)
            .interactiveDismissDisabled(hasChanges && !isNew)
    }

    private func screen(_ input: StudioInput, sections: [StudioSection]) -> some View {
        VStack(spacing: 0) {
            // Always in view: every change shows at once.
            stage
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
            if designs.count > 1 { widgetSwitcher }
            if let comboNote {
                StudioComboNoteView(note: comboNote, onUndo: undo, onClose: closeNote)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
            StudioChapterBar(selection: $chapter, visited: visitedChapters)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, chapter == .style ? 0 : 8)
            if chapter == .style {
                StudioSectionBar(sections: Self.styleTools(sections), selection: $section)
            }
            Divider()
            settings(input)
        }
        .cristalScreen()
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    /// The widget, which the person acts on: a touch on a widget inside opens it (not on the Lock Screen).
    private var stage: some View {
        StudioStage(
            design: design, family: $family, payload: payload, isExample: !model.hasOwnData(for: design),
            selectedPart: chapter == .content ? shownPanel.partIndex : nil, onPart: stagePartAction
        ) {
            stageFooter
        }
    }

    private var stagePartAction: ((Int) -> Void)? {
        if isLockScreen { return nil }
        return { part in openPart(part) }
    }

    /// On the stage, under the widget: « Changer de widget » (Créer), « + » while there is room, « Sur mon écran ».
    private var stageFooter: some View {
        HStack(spacing: 10) {
            if let onChangeWidget { changeWidgetButton(onChangeWidget) }
            Spacer(minLength: 0)
            if canAddPart {
                StudioRoundButton(symbol: "plus", title: tr("Ajouter un widget"), identifier: "stage-add") {
                    openPicker(.adding)
                }
            }
            StudioRoundButton(symbol: "eye", title: tr("Sur mon écran"), identifier: "studio-on-my-screen") {
                showsOnMyScreen = true
            }
        }
    }

    /// Créer: the other widgets (every space, photos and quotes, Lock Screen) open in a sheet.
    private func changeWidgetButton(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(tr("Changer de widget"), systemImage: "square.grid.2x2")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .cristalGlass(in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("create-change")
    }

    private func settings(_ input: StudioInput) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if needsPremium {
                    premiumNotice
                } else if exceedsFreeLimit {
                    limitNotice
                }
                chapterContent(input)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        // Another chapter, tool, widget of the set or panel: back to the top.
        .id("\(chapter.rawValue)-\(section.rawValue)-\(index)-\(shownPanel.key)")
        .scrollDismissesKeyboard(.interactively)
        .screenshotScroll()
    }

    private func dialogs<Content: View>(_ content: Content) -> some View {
        content
            .confirmationDialog(tr("Abandonner les modifications ?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(tr("Abandonner"), role: .destructive) { onClose() }
            }
            .confirmationDialog(tr("Supprimer ce widget ?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(tr("Supprimer"), role: .destructive, action: deleteDesign)
            } message: {
                Text(tr("Les widgets qui l'affichent reviendront au modèle par défaut."))
            }
            .sheet(item: $paywall) { PaywallView(context: $0) }
            .fullScreenCover(isPresented: $showsOnMyScreen, onDismiss: saveAfterPreview) {
                HomeScreenPreview(design: design, family: family, payload: payload) {
                    if showsOnMyScreen {
                        // Still on screen: saved once it has closed.
                        savesAfterPreview = true
                        showsOnMyScreen = false
                    } else {
                        // It closed itself first.
                        save()
                    }
                }
            }
    }

    private func observed<Content: View>(_ content: Content, sections: [StudioSection]) -> some View {
        content
            .task(id: partKinds) { await model.prepare(design) }
            .task(id: design.options.coinID) { if design.kind == .crypto { await model.prepare(design) } }
            .task { await prepareOthers() }
            .onChange(of: photoItem) { _, item in importPhoto(item) }
            .onChange(of: designs) { old, new in record(from: old, to: new) }
            .onChange(of: design.background) { _, background in backgroundTab = BackgroundKind(background) }
            .onChange(of: index) { _, _ in
                showCurrent()
                partsPanel = .list
                comboNote = nil
            }
            .onChange(of: chapter) { _, opened in
                _ = visitedChapters.insert(opened)
                // Leaving « Contenu »: its choice and widget panels close (opening a widget or the choice from
                // elsewhere sets the panel along with the chapter, so only leaving resets it).
                if opened != .content { partsPanel = .list }
                // A refusal is stale in another chapter; a note with « Annuler » stays until another change.
                if let comboNote, !comboNote.canUndo { self.comboNote = nil }
            }
            .onChange(of: sections) { _, shown in
                if !shown.contains(section) { section = .theme }
            }
            .onChange(of: sharesLook) { _, shares in
                if shares { shareLook() }
            }
    }

    /// The kinds drawn (every widget inside of a combined widget): one added is prepared too.
    private var partKinds: [WidgetKind] {
        design.isCombo ? design.options.parts.map(\.kind) : [design.kind]
    }

    private func prepareOthers() async {
        for other in designs.dropFirst() { await model.prepare(other) }
    }

    /// Another widget of the set chosen, or a step undone: its size and background are shown. A Lock Screen size
    /// stays while the widget has it (opened from the Lock Screen creator).
    private func showCurrent() {
        if !(family.isAccessory && design.families.contains(family)) {
            family = design.displayFormat.family
        }
        backgroundTab = BackgroundKind(design.background)
    }

    /// « Même style » turned on: every widget takes the look of the one being edited.
    private func shareLook() {
        let lead = design
        withAnimation { designs = designs.map { $0.id == lead.id ? $0 : $0.withLook(of: lead) } }
    }

    private func deleteDesign() {
        // The saved version: its own photo goes with it.
        model.delete(originals.first { $0.id == design.id } ?? design)
        onClose()
    }

    /// « Graphique » only for widgets that draw one.
    private static func sections(for input: StudioInput) -> [StudioSection] {
        let chart: ChartFamily = input.tile?.visual.chartFamily ?? ChartFamily.none
        return StudioSection.allCases.filter { $0 != .chart || chart != ChartFamily.none }
    }

    /// The tools of « Style »: every section but « Taille » and « Contenu », which are in the chapter « Contenu ».
    private static func styleTools(_ sections: [StudioSection]) -> [StudioSection] {
        sections.filter { $0 != .size && $0 != .content }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if !isPushed {
            ToolbarItem(placement: .cancellationAction) {
                Button(tr("Annuler")) {
                    if hasChanges && !isNew { confirmDiscard = true } else { onClose() }
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(past.isEmpty)
            .accessibilityLabel(Text(tr("Retour en arrière")))
            .accessibilityIdentifier("studio-undo")
            Button(action: redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(future.isEmpty)
            .accessibilityLabel(Text(tr("Retour en avant")))
            .accessibilityIdentifier("studio-redo")
        }
    }

    /// Widgets made together: which one is being edited, and whether they share their look.
    private var widgetSwitcher: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                switcherChips
                    .padding(.horizontal, 20)
            }
            // The widget being edited stays in view, with the next one beside it.
            .onChange(of: index) { _, current in
                guard designs.indices.contains(current) else { return }
                withAnimation { proxy.scrollTo(designs[current].id, anchor: .center) }
            }
        }
        .padding(.top, 8)
    }

    private var switcherChips: some View {
        // Beyond the free limit, a widget carries a lock: it isn't saved without Premium.
        let savedIDs = Set(savedDesigns.map(\.id))
        let premium = tr("Premium")
        return HStack(spacing: 8) {
            ForEach(Array(designs.enumerated()), id: \.element.id) { pair in
                let isLocked = !savedIDs.contains(pair.element.id)
                FilterChip(title: "\(pair.offset + 1) · \(pair.element.name)", symbol: isLocked ? "lock.fill" : nil, isSelected: pair.offset == index) {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { index = pair.offset }
                }
                .id(pair.element.id)
                .accessibilityIdentifier("studio-widget-\(pair.offset + 1)")
                .accessibilityLabel(Text(tr("Widget \(pair.offset + 1) sur \(designs.count) : \(pair.element.name)")))
                .accessibilityValue(isLocked ? premium : "")
            }
            Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 24)
            FilterChip(title: tr("Même style"), symbol: sharesLook ? "link" : "link.badge.plus", isSelected: sharesLook) {
                Haptics.tap()
                sharesLook.toggle()
            }
            .accessibilityIdentifier("studio-share-look")
            .accessibilityHint(Text(tr("Le thème, les couleurs, le fond et la bordure vont à tous les widgets")))
        }
    }

    // MARK: Studio

    private var payload: WidgetPayload { model.previewPayload(for: design) }

    /// The size used for the small previews: the one shown, or the widget's own on the Lock Screen.
    private var gridFamily: WidgetFamily {
        family.isAccessory ? design.displayFormat.family : family
    }

    private var studioInput: StudioInput {
        let payload = self.payload
        var tile: Tile?
        if design.kind.usesTileLayout && !design.isCombo {
            let context = RenderContext(design: design, style: ResolvedStyle(design: design), family: gridFamily, date: Date(), payload: payload, isInteractive: false)
            let made = TileFactory.make(context)
            tile = made.empty == nil ? made : nil
        }
        return StudioInput(payload: payload, family: gridFamily, tile: tile)
    }

    // MARK: Chapters

    @ViewBuilder private func chapterContent(_ input: StudioInput) -> some View {
        switch chapter {
        case .content:
            contentChapter(input)
        case .layout:
            layoutChapter
        case .style:
            styleTool(input)
        }
    }

    /// « Contenu »: the list, one widget inside, or the choice of a widget, in the panel under the stage.
    @ViewBuilder private func contentChapter(_ input: StudioInput) -> some View {
        switch shownPanel {
        case .list:
            contentList(input)
        case let .part(part):
            partDetail(part, input: input)
        case .adding:
            kindPicker(replacing: nil)
        case let .replacing(part):
            kindPicker(replacing: part)
        }
    }

    /// « Suivant › » at the top of « Contenu » and « Disposition ».
    private var nextLink: StudioPanelLink? {
        guard let next = chapter.next else { return nil }
        return StudioPanelLink(title: tr("Suivant"), symbol: "chevron.right", identifier: "studio-next") { goTo(next) }
    }

    /// The size, the widgets inside (« + » while there is room), then what the widget shows.
    @ViewBuilder private func contentList(_ input: StudioInput) -> some View {
        StudioPanelHeader(title: tr("Contenu"), link: nextLink)
        VStack(alignment: .leading, spacing: 18) {
            StudioSizePanel(design: edited, family: $family, isNew: isNew, onFormat: comboFormatAction)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("studio-size")
        StudioPartsList(
            design: design, parts: parts, payload: input.payload, capacity: partsCapacity, canAdd: canAddPart,
            onOpen: { openPart($0) }, onAdd: { openPicker(.adding) }
        )
        if parts.count > 1 && !isLockScreen {
            StudioNote(text: tr("Touche une partie du widget pour la changer."), symbol: "hand.tap")
        }
        currentContent(input, showsDelete: true)
    }

    /// What the widget shows: its name, the data it needs, its options (a widget alone; those of the widgets inside
    /// are in each one's panel), the elements shown, and « Supprimer » for a saved widget.
    @ViewBuilder private func currentContent(_ input: StudioInput, showsDelete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !model.hasOwnData(for: design) && !design.dataItems.isEmpty {
                Text(tr("Aperçu avec des données d'exemple. Renseigne tes données ci-dessous : ton widget affichera les tiennes."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            nameSection
            // What the widget needs from the person, asked here and shared with every widget.
            if !design.dataItems.isEmpty {
                WidgetDataSection(items: design.dataItems)
            }
            if !design.isCombo {
                KindOptionsSection(design: edited)
            }
            StudioElementsPanel(design: edited, tile: input.tile)
            if showsDelete && !isNew && designs.count == 1 { deleteButton }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("studio-content")
    }

    /// One widget inside: « Remplacer », « Retirer » (not the last one), its settings (a widget alone: what it shows),
    /// « Va bien avec », and « Fermer » back to the list.
    @ViewBuilder private func partDetail(_ part: Int, input: StudioInput) -> some View {
        if parts.indices.contains(part) {
            let shown = parts[part]
            StudioPanelHeader(title: shown.name, detail: partSubtitle(shown))
            StudioPartActions(
                canReplace: !isLockScreen, canRemove: parts.count > 1,
                onReplace: { openPicker(.replacing(part)) }, onRemove: { removePart(part) }
            )
            if parts.count > 1 {
                ComboPartSettingsView(design: edited, index: part)
            } else {
                currentContent(input, showsDelete: false)
            }
            if !isLockScreen && parts.count < 4 {
                StudioGoesWellWith(
                    base: design, kinds: goesWellWith, groupTitle: groupTitle,
                    onAdd: { addPart($0) }, onShowAll: { openPicker(.adding) }
                )
            }
            closePartButton
        }
    }

    private var closePartButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) { partsPanel = .list }
        } label: {
            Text(tr("Fermer"))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("part-close")
    }

    /// The choice of a widget to add next to the others, or to put in the place of one.
    @ViewBuilder private func kindPicker(replacing target: Int?) -> some View {
        let current = parts
        if let target, current.indices.contains(target) {
            let replaced = current[target]
            StudioKindPicker(
                title: tr("Remplacer \(replaced.name)"), kinds: partCandidates, base: design, currentKind: replaced.kind,
                refusal: { StudioPartRules.refusal(replacing: target, with: $0, in: current) },
                identifierPrefix: "replace-kind-",
                onPick: { kind in
                    // The same widget again would lose its settings: nothing to replace.
                    if kind == replaced.kind { closePicker() } else { replacePart(target, with: kind) }
                },
                onClose: closePicker
            )
        } else {
            StudioKindPicker(
                title: tr("Ajouter à côté de \(design.name)"), kinds: partCandidates, base: design, currentKind: nil,
                refusal: { StudioPartRules.refusal(adding: $0, to: current) },
                identifierPrefix: "add-kind-",
                onPick: { addPart($0) },
                onClose: closePicker
            )
        }
    }

    /// « Disposition »: the layouts proposed and the order of the widgets inside.
    @ViewBuilder private var layoutChapter: some View {
        StudioPanelHeader(title: tr("Disposition"), link: nextLink)
        StudioLayoutPanel(
            parts: parts, isLockScreen: isLockScreen, canAdd: canAddPart,
            onPlan: { applyPlan($0) }, onMove: { movePart(from: $0, to: $1) }, onAdd: { openPicker(.adding) }
        )
    }

    /// « Style »: the tool chosen in the row under the chapters, its panel as before.
    @ViewBuilder private func styleTool(_ input: StudioInput) -> some View {
        switch section {
        case .size, .content:
            // In the chapter « Contenu », never a tool of « Style ».
            EmptyView()
        case .theme:
            StudioThemePanel(design: edited, input: input)
        case .style:
            StudioStylePanel(design: edited, input: input)
        case .colors:
            StudioColorsPanel(design: edited, input: input)
        case .background:
            backgroundSection
            textureSection
            StudioNote(text: tr("iOS ne laisse pas un widget montrer le fond d'écran à travers lui : une vraie transparence n'est pas possible. Ardane propose le Verre (givre et reflets dessinés), les dégradés doux et ta photo. Les apparences « Teinté » ou transparentes d'iOS (Personnaliser l'écran d'accueil) s'appliquent aussi aux widgets Ardane."))
        case .border:
            StudioBorderPanel(design: edited)
        case .chart:
            StudioChartPanel(design: edited, input: input)
        case .density:
            StudioDensityPanel(design: edited, input: input)
        case .myStyles:
            StudioMyStylesPanel(design: edited, input: input)
        }
    }

    // MARK: Sections

    private var premiumNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.premiumInk)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Ce widget utilise Premium"))
                    .font(.subheadline.weight(.semibold))
                Text(design.premiumFeatures.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { paywall = .designs(designs.filter(\.usesPremiumFeatures)) } label: {
                Text(tr("Débloquer")).foregroundStyle(.onAccent)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(14)
        .background(Color.premiumFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// More new widgets than the free plan keeps: the ones beyond the limit are locked, or none fits.
    private var limitNotice: some View {
        let context = PaywallContext.designLimit
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: context.symbol)
                .foregroundStyle(Color.premiumInk)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.title)
                    .font(.subheadline.weight(.semibold))
                Text(savedDesigns.isEmpty ? context.detail : tr("Sans Premium, les widgets marqués d'un cadenas ne seront pas enregistrés."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { paywall = context } label: {
                Text(tr("Débloquer")).foregroundStyle(.onAccent)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(14)
        .background(Color.premiumFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var nameSection: some View {
        EditorSection(title: tr("Nom")) {
            TextField(tr("Nom du widget"), text: edited.name)
                .accessibilityIdentifier("widget-name")
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(12)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var backgroundSection: some View {
        EditorSection(title: tr("Fond"), isPremium: !model.isPremium) {
            VStack(alignment: .leading, spacing: 14) {
                Picker(tr("Fond"), selection: $backgroundTab) {
                    Text(tr("Style")).tag(BackgroundKind.theme)
                    Text(tr("Couleur")).tag(BackgroundKind.color)
                    Text(tr("Dégradé")).tag(BackgroundKind.gradient)
                    Text(tr("Verre")).tag(BackgroundKind.glass)
                    Text(tr("Photo")).tag(BackgroundKind.photo)
                }
                .pickerStyle(.segmented)
                .onChange(of: backgroundTab) { _, tab in
                    switch tab {
                    case .theme: designs[index].background = .theme
                    case .color:
                        if case .color = design.background {} else { designs[index].background = .color(Palette.backgrounds[0].hex) }
                    case .gradient: designs[index].background = .gradient
                    case .glass: designs[index].background = .glass
                    case .photo: break
                    }
                }

                switch backgroundTab {
                case .color:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Palette.backgrounds) { swatch in
                            ColorDot(hex: swatch.hex, isSelected: design.background == .color(swatch.hex), size: 40) {
                                designs[index].background = .color(swatch.hex)
                            }
                            .accessibilityLabel(Text(swatch.name))
                        }
                    }
                    ColorPicker(tr("Autre couleur"), selection: Binding(
                        get: {
                            if case let .color(hex) = design.background { return Color(hex: hex) }
                            return Color(hex: Palette.backgrounds[0].hex)
                        },
                        set: { designs[index].background = .color($0.hexString) }
                    ), supportsOpacity: false)
                    .font(.subheadline)
                case .gradient:
                    gradientSettings
                case .glass:
                    Text(tr("Du verre dépoli teinté de la couleur principale, avec ses reflets. Change la couleur principale pour le teinter."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .theme:
                    Text(tr("Le fond du style choisi, clair ou sombre selon le style."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .photo:
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(BackgroundKind(design.background) == .photo ? tr("Changer de photo") : tr("Choisir une photo"))
                            Spacer()
                            if isImportingPhoto { ProgressView() }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    if case .photo = design.background {
                        StudioSlider(title: tr("Voile pour la lisibilité"), value: Binding(
                            get: { design.style.veil ?? 0.28 },
                            set: { designs[index].style.veil = $0 }
                        ), range: 0...0.75)
                    }
                    StudioNote(text: tr("La photo est réduite pour tenir dans la mémoire limitée des widgets."))
                }
            }
        }
    }

    /// Automatic (from the main color) or the person's own: two colors, a direction and an intensity.
    @ViewBuilder private var gradientSettings: some View {
        Toggle(tr("Mon propre dégradé"), isOn: Binding(
            get: { design.style.gradient != nil },
            set: { isOn in
                designs[index].style.gradient = isOn
                    ? GradientSpec(startHex: ColorMath.shade(design.accentHex, 0.18), endHex: ColorMath.shade(design.accentHex, -0.45))
                    : nil
            }
        ))
        .font(.subheadline)
        if let spec = design.style.gradient {
            HStack(spacing: 16) {
                ColorPicker(tr("Couleur 1"), selection: Binding(
                    get: { Color(hex: spec.startHex) },
                    set: { designs[index].style.gradient?.startHex = $0.hexString }
                ), supportsOpacity: false)
                ColorPicker(tr("Couleur 2"), selection: Binding(
                    get: { Color(hex: spec.endHex) },
                    set: { designs[index].style.gradient?.endHex = $0.hexString }
                ), supportsOpacity: false)
            }
            .font(.subheadline)
            StudioChoices(
                options: GradientDirection.allCases,
                selection: Binding(get: { spec.direction }, set: { designs[index].style.gradient?.direction = $0 }),
                title: \.title,
                symbol: { $0.symbol }
            )
            StudioSlider(title: tr("Intensité"), value: Binding(
                get: { spec.intensity },
                set: { designs[index].style.gradient?.intensity = $0 }
            ), range: 0.1...1)
            FlowLayout(spacing: 8) {
                ForEach(Array(Self.gradientIdeas.enumerated()), id: \.offset) { _, idea in
                    Button {
                        withAnimation { designs[index].style.gradient = GradientSpec(startHex: idea.0, endHex: idea.1, direction: spec.direction, intensity: 1) }
                    } label: {
                        LinearGradient(colors: [Color(hex: idea.0), Color(hex: idea.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: 44, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(tr("Dégradé")))
                }
            }
        } else {
            Text(tr("Le dégradé suit la couleur principale."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static let gradientIdeas: [(String, String)] = [
        ("FF9A62", "8E3BA8"), ("0B8FAC", "063A6B"), ("1B2250", "05060F"), ("F6D365", "FDA085"),
        ("84FAB0", "8FD3F4"), ("A18CD1", "FBC2EB"), ("434343", "000000"), ("F5F7FA", "C3CFE2"),
        ("FF5F6D", "FFC371"), ("11998E", "38EF7D"),
    ]

    private var textureSection: some View {
        EditorSection(title: tr("Texture"), isPremium: !model.isPremium) {
            VStack(alignment: .leading, spacing: 12) {
                StudioChoices(options: TextureKind.allCases, selection: edited.style.texture, title: \.title, identifier: { "texture-\($0.rawValue)" })
                if design.effectiveStyle.texture != .none {
                    StudioSlider(title: tr("Intensité"), value: edited.style.textureOpacity, range: 0.1...1)
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label(tr("Supprimer ce widget"), systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: save) {
                Text(saveTitle)
                    .font(.headline)
                    .foregroundStyle(hasChanges ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .disabled(!hasChanges)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var saveTitle: String {
        let count = savedDesigns.count
        if needsPremium || count == 0 { return tr("Débloquer et enregistrer") }
        if !isNew { return tr("Enregistrer") }
        // Beyond the free limit, only the widgets without a lock.
        return count > 1 ? tr("Enregistrer les \(count) widgets") : tr("Enregistrer le widget")
    }

    // MARK: Undo and redo

    /// Keeps what the widgets were before a change. A slider being dragged or a name being typed
    /// counts as one change. Widgets that share their look get the change too.
    private func record(from old: [WidgetDesign], to new: [WidgetDesign]) {
        if let restored, restored == new {
            self.restored = nil
            return
        }
        if sharesLook && new.count > 1 && new.indices.contains(index) {
            let lead = new[index]
            let synced = new.map { $0.id == lead.id ? $0 : $0.withLook(of: lead) }
            if synced != new { designs = synced }
        }
        let now = Date()
        if now.timeIntervalSince(lastChange) > 0.6 {
            past.append(old)
            if past.count > 80 { past.removeFirst() }
        }
        lastChange = now
        future.removeAll()
        // Another change came after the note's: its « Annuler » would no longer take back what it says.
        if comboNote != nil { comboNote = nil }
    }

    private func undo() {
        guard let previous = past.popLast() else { return }
        future.append(designs)
        restore(previous)
    }

    private func redo() {
        guard let next = future.popLast() else { return }
        past.append(designs)
        restore(next)
    }

    private func restore(_ value: [WidgetDesign]) {
        Haptics.tap()
        // The next change is a new step, however soon it comes.
        lastChange = .distantPast
        withAnimation(.easeInOut(duration: 0.2)) { comboNote = nil }
        guard value != designs else { return }
        restored = value
        withAnimation(.easeInOut(duration: 0.2)) { designs = value }
        // A step may have had another number of widgets (several made together, or widgets inside).
        index = min(index, value.count - 1)
        showCurrent()
        // A widget inside that is gone (an addition undone): back to the list.
        if let open = partsPanel.partIndex, !design.editableParts.indices.contains(open) { partsPanel = .list }
    }

    // MARK: Widgets inside

    /// The widget being edited as the widgets inside it (one: the widget alone). Only this widget of a set.
    private var parts: [ComboPart] { design.editableParts }

    /// On the Lock Screen a widget stays alone: no « + », no touch zones, nothing to lay out.
    private var isLockScreen: Bool { family.isAccessory }

    /// The panel shown: the one asked for, while the widget it is about still exists (else the list).
    private var shownPanel: StudioPartsPanel {
        switch partsPanel {
        case .list:
            return .list
        case let .part(part):
            return parts.indices.contains(part) ? partsPanel : .list
        case .adding:
            return isLockScreen ? .list : .adding
        case let .replacing(part):
            return !isLockScreen && parts.indices.contains(part) ? partsPanel : .list
        }
    }

    /// The widgets that can join this one: its space's, or its catalog category's outside the spaces.
    private var partCandidates: [WidgetKind] {
        StudioPartRules.candidates(for: parts.first?.kind ?? design.kind)
    }

    /// « + »: room for another widget (4 at most) that isn't inside yet, and not on the Lock Screen.
    private var canAddPart: Bool {
        guard !isLockScreen, parts.count < 4 else { return false }
        let inside = Set(parts.map(\.kind))
        return partCandidates.contains { !inside.contains($0) }
    }

    /// « N sur M »: the most the widget can reach (4 while « + » is there, since adding grows the size), else what it
    /// holds now. 0 on the Lock Screen: no count.
    private var partsCapacity: Int {
        if isLockScreen { return 0 }
        return canAddPart ? Composer.maxCount(for: .large) : parts.count
    }

    private var groupTitle: String {
        StudioPartRules.groupTitle(for: parts.first?.kind ?? design.kind)
    }

    /// « Petit · Fitness ».
    private func partSubtitle(_ part: ComboPart) -> String {
        let size = isLockScreen ? family.shortTitle : part.size.title
        return "\(size) · \(groupTitle)"
    }

    /// « Va bien avec »: three widgets of the space that can be added now, the free ones and the space's usual
    /// ones first.
    private var goesWellWith: [WidgetKind] {
        let current = parts
        let inside = Set(current.map(\.kind))
        let presets = StudioPartRules.presets(for: current.first?.kind ?? design.kind)
        let addable = partCandidates.filter { !inside.contains($0) && StudioPartRules.refusal(adding: $0, to: current) == nil }
        let ranked = addable.enumerated().sorted { a, b in
            let left = rank(a.element, presets: presets)
            let right = rank(b.element, presets: presets)
            return left == right ? a.offset < b.offset : left < right
        }
        return ranked.prefix(3).map(\.element)
    }

    private func rank(_ kind: WidgetKind, presets: [WidgetKind]) -> Int {
        var rank = presets.contains(kind) ? 0 : 1
        if kind.isPremium && !model.isPremium { rank += 2 }
        return rank
    }

    /// A combined widget: Petit, Moyen, Grand plan its widgets again.
    private var comboFormatAction: ((WidgetFormat) -> Void)? {
        guard design.isCombo else { return nil }
        return { format in changeComboFormat(format) }
    }

    private func goTo(_ next: StudioChapter) {
        withAnimation(.easeInOut(duration: 0.2)) { chapter = next }
    }

    /// A widget inside touched on the stage or in the list: its panel opens (a second touch on the stage closes it).
    private func openPart(_ part: Int) {
        let isOpen = chapter == .content && shownPanel == .part(part)
        withAnimation(.easeInOut(duration: 0.2)) {
            chapter = .content
            partsPanel = isOpen ? .list : .part(part)
        }
    }

    /// The choice of a widget, in « Contenu »; « Fermer » goes back to the widget it was opened from, or the list.
    private func openPicker(_ panel: StudioPartsPanel) {
        alignPreview()
        var back = StudioPartsPanel.list
        if chapter == .content, let open = shownPanel.partIndex { back = .part(open) }
        withAnimation(.easeInOut(duration: 0.2)) {
            pickerBack = back
            chapter = .content
            partsPanel = panel
        }
    }

    private func closePicker() {
        withAnimation(.easeInOut(duration: 0.2)) { partsPanel = pickerBack }
    }

    private func closeNote() {
        withAnimation(.easeInOut(duration: 0.2)) { comboNote = nil }
    }

    /// A saved widget's size chips only preview another size; an edit of the widgets inside works on its real size,
    /// so the preview goes back to it first (else the stage would jump after the edit).
    private func alignPreview() {
        guard !isLockScreen else { return }
        let real = design.displayFormat.family
        if family != real { family = real }
    }

    private func addPart(_ kind: WidgetKind) {
        alignPreview()
        apply(ComboEditing.adding(StudioPartRules.newPart(kind), to: parts), then: .list)
    }

    private func replacePart(_ part: Int, with kind: WidgetKind) {
        apply(ComboEditing.replacing(at: part, with: StudioPartRules.newPart(kind), in: parts), then: .part(part))
    }

    private func removePart(_ part: Int) {
        apply(ComboEditing.removing(at: part, from: parts), then: .list)
    }

    private func movePart(from: Int, to: Int) {
        apply(ComboEditing.moving(from: from, to: to, in: parts), then: .list)
    }

    /// A layout of « Disposition »: the same widgets, in another order or with another one on a whole row.
    private func applyPlan(_ plan: [ComboPart]) {
        let old = ComboEditing.format(of: parts)
        let shown = ComboEditing.inDisplayOrder(plan)
        let now = ComboEditing.format(of: shown)
        apply(.applied(ComboEditing.Outcome(parts: shown, format: now, resizedFrom: now == old ? nil : old)), then: .list)
    }

    /// Petit, Moyen or Grand chosen for a combined widget.
    private func changeComboFormat(_ format: WidgetFormat) {
        apply(StudioPartRules.resizing(parts, to: format), then: shownPanel, isChosenSize: true)
    }

    /// One edit of the widgets inside the widget being edited (never the other widgets of a set). Applied, it is
    /// a step of its own in the history (« Annuler » and the arrows take it back) and the size shown follows, with a
    /// note when the size changed. Refused, nothing changes and the note says why.
    private func apply(_ change: ComboEditing.Change, then panel: StudioPartsPanel, isChosenSize: Bool = false) {
        switch change {
        case let .refused(reason):
            withAnimation(.easeInOut(duration: 0.2)) { comboNote = StudioComboNote(text: reason, canUndo: false) }
        case let .applied(outcome):
            var after = designs
            after[index] = design.applying(outcome)
            guard after != designs else {
                withAnimation(.easeInOut(duration: 0.2)) { partsPanel = panel }
                return
            }
            past.append(designs)
            if past.count > 80 { past.removeFirst() }
            future.removeAll()
            // `record` skips it (already kept), and the next change is a new step however soon it comes.
            restored = after
            lastChange = .distantPast
            withAnimation(.easeInOut(duration: 0.25)) {
                designs = after
                partsPanel = panel
                comboNote = note(for: outcome, isChosenSize: isChosenSize)
            }
            showCurrent()
        }
    }

    /// The note when the size changed: « Passé en Grand pour tout afficher… », and for a widget already saved, that
    /// it must be placed again. A size the person chose needs a word only for a saved widget.
    private func note(for outcome: ComboEditing.Outcome, isChosenSize: Bool) -> StudioComboNote? {
        guard let old = outcome.resizedFrom else { return nil }
        let placeAgain = tr("Déjà posé sur ton écran ? Il faudra le reposer à la nouvelle taille.")
        if isChosenSize {
            return isNew ? nil : StudioComboNote(text: placeAgain, canUndo: true)
        }
        let resized = StudioPartRules.resizeText(to: outcome.format, from: old, count: outcome.parts.count)
        return StudioComboNote(text: isNew ? resized : resized + " " + placeAgain, canUndo: true)
    }

    /// « Enregistrer le widget » in « Sur mon écran »: saved once it has closed (the widget flies from the stage).
    private func saveAfterPreview() {
        guard savesAfterPreview else { return }
        savesAfterPreview = false
        save()
    }

    // MARK: Actions

    private func save() {
        saveGuard.run { performSave() }
    }

    private func performSave() {
        // In the free plan, the new widgets within the limit (the Studio showed the others locked).
        let saved = savedDesigns
        if needsPremium || saved.isEmpty {
            // The paywall says what this save needs: the Premium settings used, or more room.
            paywall = needsPremium ? PaywallContext.designs(designs.filter(\.usesPremiumFeatures)) : PaywallContext.designLimit
            return
        }
        if isNew {
            model.install(designs: saved)
            // A widget made: a good moment (a rating may be asked once the Studio has closed).
            model.celebrate()
            // The new widgets glide into « Mes widgets » as the Studio closes.
            router.saveFlight = SaveFlight(designs: saved, source: previewFrame)
            // The « Ajouter à l'écran d'accueil » guide after each of the first three saves, wherever the Studio was opened from.
            if model.settings.addGuideCount < 3 {
                model.updateSettings { $0.addGuideCount += 1 }
                router.lastSavedName = designs.count == 1 ? design.name : nil
                router.lastSavedID = designs.count == 1 ? design.id : nil
                router.showsAddGuideAfterEditor = true
            }
        } else {
            for design in designs { model.save(design) }
        }
        photos.kept.formUnion(saved.compactMap(\.photoName))
        Haptics.success()
        onClose()
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isImportingPhoto = true
        let target = index
        Task {
            defer {
                isImportingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let name = ImageStore.save(image) else { return }
            photos.imported.append(name)
            if designs.indices.contains(target) { designs[target].background = .photo(name) }
        }
    }
}

/// One widget inside a combined widget, in the Studio's panel: its name, its data and its options.
struct ComboPartSettingsView: View {
    @Binding var design: WidgetDesign
    let index: Int

    private var part: Binding<WidgetDesign> {
        Binding(
            get: {
                let parts = design.options.parts
                return parts.indices.contains(index) ? design.design(for: parts[index]) : design
            },
            set: { updated in
                guard design.options.parts.indices.contains(index) else { return }
                design.options.parts[index].name = updated.name
                var options = updated.options
                options.parts = []
                design.options.parts[index].options = options
            }
        )
    }

    var body: some View {
        let shown = part.wrappedValue
        // In the panel of the widget open, under the stage that shows it ringed: its own name field (not the
        // whole widget's « widget-name »), its data and its options.
        VStack(alignment: .leading, spacing: 18) {
            EditorSection(title: tr("Nom")) {
                TextField(tr("Nom du widget"), text: part.name)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .padding(12)
                    .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if !shown.dataItems.isEmpty {
                WidgetDataSection(items: shown.dataItems)
            }
            KindOptionsSection(design: part)
        }
    }
}

private extension WidgetDesign {
    var photoName: String? {
        if case let .photo(name) = background { return name }
        return nil
    }
}

enum BackgroundKind: Hashable {
    case theme, color, gradient, glass, photo

    init(_ style: BackgroundStyle) {
        switch style {
        case .theme: self = .theme
        case .color: self = .color
        case .gradient: self = .gradient
        case .glass: self = .glass
        case .photo: self = .photo
        }
    }
}

struct EditorSection<Content: View>: View {
    let title: String
    var detail: String?
    var isPremium = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if isPremium { PremiumBadge(compact: true) }
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            content()
                .card(padding: 14)
        }
    }
}

struct ColorDot: View {
    let hex: String
    let isSelected: Bool
    var size: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1) }
                .padding(3)
                .overlay {
                    Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                }
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
