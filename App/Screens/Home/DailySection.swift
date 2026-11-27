import SwiftUI

/// Where a tap on Home leads, inside the Home tab.
enum HomeRoute: Hashable {
    case space(Space)
    case info
    /// Kept for old links only (screenshot mode, saved paths): there is no page per category any more,
    /// it opens the mini-app of the area (see `InfoArea.homeRoute`). New code uses `homeRoute`.
    case infoArea(InfoArea)
    /// A mini-app (Nutrition, Fitness…), and one of its detailed pages.
    case app(MiniApp)
    case page(MiniAppPage)
}

extension InfoArea {
    /// The mini-app where this area's information is filled in (Studies have their own, Habits live in Planning).
    /// Nil for the areas without a mini-app: investments, listed companies, « Ma vie » and the general settings.
    var miniApp: MiniApp? {
        switch self {
        case .nutrition: .nutrition
        case .fitness: .fitness
        case .habits, .productivity: .planning
        case .student: .studies
        case .budget: .finances
        case .business: .business
        case .travel: .travel
        case .car: .car
        case .investing, .markets, .life, .general: nil
        }
    }

    /// Where a tap on this area leads: its mini-app, else the data of its space, else « Mes informations »
    /// (the general settings: city, calendar).
    var homeRoute: HomeRoute {
        if let miniApp { return .app(miniApp) }
        if let space { return .space(space) }
        return .info
    }
}

extension AppModel {
    /// Where « Complète tes informations » leads: the mini-app of the first area that still misses something
    /// its « À remplir » block asks for (the person's interests come first), else « Mes informations » for
    /// the general ones. A missing item no block shows (tasks, bills…) never picks a mini-app.
    var firstMissingInfoRoute: HomeRoute {
        let app = completion.missing.lazy.compactMap { item -> MiniApp? in
            // The mini-app whose « À remplir » block asks for it (the timetable is asked by Planning, though its
            // area is the studies').
            MiniApp.allCases.first { $0.toFillItems.contains(item) }
        }.first
        return app.map { HomeRoute.app($0) } ?? .info
    }
}

/// « Mon Quotidien »: the figures of the day as a dashboard of tiles, only for what the person
/// entered, ordered by what matters now (see `DailyBrief`).
struct DailySection: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var editingLayout = false
    @State private var addingCategory = false
    // Edit mode (long press): the cards wiggle, one is dragged, + and - resize.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing = false
    /// The order while a card is dragged (saved at the drop); nil otherwise.
    @State private var liveOrder: [String]?
    @State private var draggingID: String?
    @State private var dragOffset: CGSize = .zero
    /// Where the finger took the dragged card, from its top left corner.
    @State private var grab: CGPoint = .zero
    /// Where the finger took the dragged card, in the « daily-grid » space.
    @State private var dragStart: CGPoint = .zero
    @State private var frames: [String: CGRect] = [:]
    @State private var lastSwap = Date.distantPast
    /// The cards that changed rows at the last move of the drag: not taken again until the finger leaves them
    /// (`DailyLayoutRules.changedRows`).
    @State private var settled: Set<String> = []
    private var steps: StepCounter { .shared }

    var body: some View {
        let now = Date()
        let settings = model.settings
        // The categories of the person's interests (a dotted « Ajouter » card while empty), the ones with data
        // and the ones they added; the others are offered by the « + » at the bottom.
        let automatic = DailyCategories.home(model: model, now: now, steps: steps.status == .allowed ? steps.stepsToday : nil)
        let arrangedTiles = DailyBrief.arranged(automatic, order: settings.dailyOrder, hidden: settings.dailyHidden)
        let tiles = DailyLayoutRules.ordered(arrangedTiles, by: liveOrder)
        let addable = DailyCategories.addable(shown: arrangedTiles)
        // Real figures entered by the person (invitations to fill in a category don't count).
        let hasData = automatic.contains { tile in
            switch tile {
            case .invite, .empty, .miniApp(_, caption: nil): false
            // The week's schedule is there for everyone: empty, it isn't something the person entered.
            case let .planning(items) where items.isEmpty: false
            default: true
            }
        }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Mon Quotidien").uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.secondary)
                    HStack(alignment: .center, spacing: 10) {
                        Text(DailyBrief.Moment(now).title)
                            .font(.largeTitle.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("daily-title")
                        // Without Premium, its gold sign by the title opens the offer; it goes away once bought.
                        if !model.isPremium && !editing {
                            Spacer(minLength: 0)
                            PremiumGoldBadge { router.showPaywall() }
                        }
                    }
                }
                Spacer(minLength: 0)
                if editing { editBar }
            }
            .tutorialTarget(.dailyHeader, radius: 12)
            if editing {
                Text(tr("Maintiens une carte puis glisse-la pour la déplacer. + et − changent sa taille."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Nothing entered yet: Mon Quotidien asks for the information, the invitations follow.
            if !hasData {
                emptyState
            }
            if !tiles.isEmpty {
                let wides = tiles.map { DailyLayoutRules.size(of: $0, wide: settings.dailyWide) == .wide }
                let paired = Set(DailyLayoutRules.rows(wides: wides).filter { $0.count > 1 }.flatMap { $0 }.map { tiles[$0].id })
                let wideIDs = Set(zip(tiles, wides).filter { $0.1 }.map { $0.0.id })
                // As they are read on screen: « before » and « after » are the neighbours the person sees.
                let movable = DailyLayoutRules.readingOrder(tiles.filter(DailyLayoutRules.isMovable).map(\.id),
                                                            isWide: { wideIDs.contains($0) })
                DailyGridLayout(wides: wides) {
                    ForEach(tiles) { tile in
                        gridCard(tile, compact: paired.contains(tile.id), movable: movable, wideIDs: wideIDs, wide: settings.dailyWide)
                    }
                }
                .coordinateSpace(name: "daily-grid")
                .onPreferenceChange(DailyFramesKey.self) { frames = $0 }
            }
            // The categories not on Mon Quotidien (never chosen, or removed): one dotted « + », gone once all are there.
            if !addable.isEmpty {
                AddCategoryCard { addingCategory = true }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-section")
        // Editing: a tap on an empty zone ends the mode (the cards and buttons take their own taps first).
        .background {
            if editing {
                Color.clear.contentShape(Rectangle()).onTapGesture { finishEditing() }
            }
        }
        .task { await steps.refresh() }
        .sheet(isPresented: $editingLayout) {
            DailyLayoutEditor(available: automatic)
        }
        .sheet(isPresented: $addingCategory) {
            AddCategorySheet(categories: addable)
        }
    }

    /// The « OK » (ends the mode) and the way to the full editor (hidden cards, automatic layout).
    private var editBar: some View {
        HStack(spacing: 6) {
            Button {
                editingLayout = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(tr("Cartes masquées et disposition automatique")))
            .accessibilityIdentifier("daily-edit-more")
            Button {
                finishEditing()
            } label: {
                Text(tr("OK"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.onAccent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("daily-edit-done")
        }
        .padding(.horizontal, 4)
        .cristalGlass(in: Capsule())
    }

    private var moveAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.82)
    }

    private func enterEditing() {
        guard !editing else { return }
        Haptics.tap()
        withAnimation(moveAnimation) { editing = true }
    }

    private func finishEditing() {
        withAnimation(moveAnimation) {
            editing = false
            draggingID = nil
            dragOffset = .zero
            liveOrder = nil
        }
    }

    /// What a card does in edit mode and for VoiceOver. Every change is saved at once, in the same settings as the
    /// layout editor.
    private func gridCard(_ tile: DailyBrief.Tile, compact: Bool, movable: [String], wideIDs: Set<String>,
                          wide: [String: Bool]) -> some View {
        let actions = cardActions(tile)
        let dragging = draggingID == tile.id
        let canMove = DailyLayoutRules.isMovable(tile)
        let handlers = DailyEditHandlers(
            grow: { resize(tile, to: .wide) },
            shrink: { resize(tile, to: .half) },
            moveBefore: { moveByRank(tile, movable: movable, wideIDs: wideIDs, by: -1) },
            moveAfter: { moveByRank(tile, movable: movable, wideIDs: wideIDs, by: 1) },
            remove: actions.remove,
            organize: actions.organize,
            drag: { drag in if canMove { dragChanged(tile, drag, movable: movable, wideIDs: wideIDs) } },
            drop: { dropCard() }
        )
        return DailyEditableCard(
            tile: tile, title: DailyLayoutEditor.info(tile).title, editing: editing, isDragging: dragging,
            dragOffset: dragging ? dragOffset : .zero,
            canGrow: DailyLayoutRules.canGrow(tile, wide: wide), canShrink: DailyLayoutRules.canShrink(tile, wide: wide),
            canMoveBefore: DailyLayoutRules.canMove(movable, id: tile.id, by: -1),
            canMoveAfter: DailyLayoutRules.canMove(movable, id: tile.id, by: 1),
            handlers: handlers
        ) {
            // Two cards side by side: each lays itself out for half the width.
            DailyTileView(tile: tile)
                .frame(maxWidth: .infinity)
                // What the tutorial lights up on « Mon Quotidien » when the whole section is too tall.
                .tutorialTarget(.dailyNutrition, radius: 24, when: tile.id == "nutrition")
                .tutorialTarget(.dailyFitness, radius: 24, when: tile.id == "workout")
                .environment(\.dailyCompact, compact)
                .environment(\.dailyEditing, editing)
                .environment(\.dailyCardActions, actions)
        }
    }

    private func resize(_ tile: DailyBrief.Tile, to size: DailyLayoutRules.Size) {
        Haptics.tap()
        withAnimation(moveAnimation) {
            model.updateSettings { $0.dailyWide = DailyLayoutRules.resized($0.dailyWide, tile: tile, to: size) }
        }
    }

    /// VoiceOver « Déplacer avant » / « Déplacer après »: the card goes where its neighbour on screen is, the way a drop
    /// onto that neighbour would put it (a wide card trades rows with the two half cards under it).
    private func moveByRank(_ tile: DailyBrief.Tile, movable: [String], wideIDs: Set<String>, by delta: Int) {
        let ids = DailyLayoutRules.moved(movable, id: tile.id, by: delta, isWide: { wideIDs.contains($0) })
        guard ids != movable else { return }
        Haptics.tap()
        withAnimation(moveAnimation) { model.updateSettings { $0.dailyOrder = ids } }
    }

    /// The finger moves the card (it was held): it follows the finger, and takes the place of the card it is over,
    /// the others slide aside.
    private func dragChanged(_ tile: DailyBrief.Tile, _ drag: DailyCardDrag, movable: [String], wideIDs: Set<String>) {
        guard editing, let layout = frames[tile.id] else { return }
        if draggingID != tile.id {
            draggingID = tile.id
            liveOrder = movable
            grab = drag.grab
            dragStart = CGPoint(x: layout.minX + drag.grab.x, y: layout.minY + drag.grab.y)
            dragOffset = .zero
            settled = []
            Haptics.tap()
        }
        // In the « daily-grid » space: where the finger took the card, plus how far it went.
        let location = CGPoint(x: dragStart.x + drag.translation.width, y: dragStart.y + drag.translation.height)
        dragOffset = CGSize(width: location.x - grab.x - layout.minX, height: location.y - grab.y - layout.minY)
        let found = DailyLayoutRules.target(at: location, frames: frames, excluding: tile.id)
        // Over a card that just made room: nothing until the finger leaves it. Anywhere else, every card counts again.
        if let found, settled.contains(found) { return }
        settled = []
        guard Date().timeIntervalSince(lastSwap) > 0.25,
              let order = liveOrder,
              let target = found,
              order.contains(target) else { return }
        let isWide: (String) -> Bool = { wideIDs.contains($0) }
        let next = DailyLayoutRules.moved(order, id: tile.id, onto: target, isWide: isWide)
        guard next != order else { return }
        lastSwap = Date()
        settled = DailyLayoutRules.changedRows(from: order, to: next, isWide: isWide).subtracting([tile.id])
        withAnimation(moveAnimation) { liveOrder = next }
    }

    /// The finger leaves: the order is saved, the card settles in its place.
    private func dropCard() {
        guard draggingID != nil else { return }
        let order = liveOrder
        Haptics.tap()
        withAnimation(moveAnimation) {
            if let order { model.updateSettings { $0.dailyOrder = order } }
            draggingID = nil
            dragOffset = .zero
            liveOrder = nil
        }
    }

    /// What the card's menu and VoiceOver actions do. Removing hides the card for good (even once it holds data) and
    /// puts it back in the list of the « + »: the mini-app's data is never touched. Organizing starts the edit mode.
    private func cardActions(_ tile: DailyBrief.Tile) -> DailyCardActions {
        DailyCardActions(
            remove: {
                Haptics.tap()
                model.updateSettings { DailyCategories.remove(tileID: tile.id, in: &$0) }
            },
            organize: { enterEditing() }
        )
    }

    /// Nothing entered yet: « Mon Quotidien » asks for the person's information. No fake figure.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("Complète tes informations pour personnaliser ton Mon Quotidien."), systemImage: "sun.max")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(tr("Tes repas, ta séance, tes cours, tes habitudes… Renseigne ce qui te concerne : Ardane réunit chaque jour ce qui compte."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // The mini-app with something left to fill in (its « À remplir » block), else « Mes informations ».
            NavigationLink(value: model.firstMissingInfoRoute) {
                Text(tr("Ajouter mes informations"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("daily-empty-add")
        }
        .card()
    }
}

// MARK: - Tiles

private struct DailyCompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// A card of « Mon Quotidien » at half width, next to another one: only what matters, laid out
    /// for the narrow space (not the wide card made smaller).
    var dailyCompact: Bool {
        get { self[DailyCompactKey.self] }
        set { self[DailyCompactKey.self] = newValue }
    }
}

private struct DailyEditingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// « Mon Quotidien » in its edit mode (« Organiser… »): the cards are moved and resized, never swiped.
    var dailyEditing: Bool {
        get { self[DailyEditingKey.self] }
        set { self[DailyEditingKey.self] = newValue }
    }
}

/// What the menu and the VoiceOver actions of a card of Mon Quotidien do (set by `DailySection` on each card).
struct DailyCardActions {
    var remove: () -> Void
    var organize: () -> Void
}

private struct DailyCardActionsKey: EnvironmentKey {
    static let defaultValue: DailyCardActions? = nil
}

extension EnvironmentValues {
    /// The long-press actions of the card (nil outside Mon Quotidien).
    var dailyCardActions: DailyCardActions? {
        get { self[DailyCardActionsKey.self] }
        set { self[DailyCardActionsKey.self] = newValue }
    }
}

/// The entries of a card's menu (the finished session only): take it off Mon Quotidien (its data stays in
/// the mini-app), or start the edit mode to order and size the cards.
struct DailyCardMenuItems: View {
    let actions: DailyCardActions

    var body: some View {
        Button(role: .destructive, action: actions.remove) {
            Label(tr("Retirer de Mon Quotidien"), systemImage: "minus.circle")
        }
        Button(action: actions.organize) {
            Label(tr("Organiser…"), systemImage: "arrow.up.arrow.down")
        }
    }
}

private struct DailyTileView: View {
    let tile: DailyBrief.Tile
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        switch tile {
        case let .nutrition(nutrition):
            DailyPager(id: "nutrition", titles: [tr("Aujourd'hui"), tr("Repas"), tr("7 jours")]) { page in
                switch page {
                case 1: NutritionMealsTile(nutrition: nutrition)
                case 2: NutritionWeekTile(nutrition: nutrition)
                default: NutritionDayTile(nutrition: nutrition)
                }
            }
        case let .workout(workout):
            DailyPager(id: "workout", titles: [tr("Séance"), tr("Semaine")]) { page in
                if page == 1 { WorkoutWeekTile() } else { WorkoutDayTile(workout: workout) }
            }
        case let .planning(items): PlanningDayTile(items: items)
        case let .habits(done, items): HabitsDayTile(done: done, items: items)
        case let .steps(steps, goal):
            DailyPager(id: "steps", titles: [tr("Aujourd'hui"), tr("7 jours")]) { page in
                if page == 1 { StepsWeekTile(goal: goal) } else { StepsDayTile(steps: steps, goal: goal) }
            }
        case let .budget(spent, perDay): BudgetDayTile(spent: spent, perDayLeft: perDay)
        case let .reminders(items): RemindersDayTile(items: items)
        case let .invite(area): InviteDayTile(area: area)
        case let .empty(category):
            InviteCard(title: category.title, symbol: category.symbol, colorHex: category.colorHex, text: category.invitation,
                       route: category.route, identifier: "daily-empty-\(category.rawValue)")
        case let .miniApp(raw, caption):
            if let app = MiniApp(rawValue: raw) {
                DayCard(title: app.title, symbol: app.symbol, colorHex: app.colorHex, route: .app(app)) {
                    Text(caption ?? tr("Rien pour l'instant : touche pour ajouter tes données."))
                        .font(caption == nil ? .caption : .headline)
                        .foregroundStyle(caption == nil ? Color.secondary : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    MiniAppDayDetails(app: app)
                }
                .accessibilityIdentifier("daily-app-\(raw)")
            }
        }
    }
}

/// The label of a card: its round pastille, its title and a chevron. The card to do right now shows its « Maintenant » tag
/// instead of the title (the design), the title staying for VoiceOver.
private struct DayHeader: View {
    let title: String
    let symbol: String
    let colorHex: String
    var badge: String? = nil
    var showsChevron = false
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dailyPager) private var pager

    var body: some View {
        let tint = style.cristal.category(colorHex)
        let hasDots = (pager?.count ?? 0) > 1
        // The header never cuts its title or its tag: in a narrow card it first drops the chevron, then tightens,
        // and only as a last resort hides the page dots (the swipe and VoiceOver keep working without them).
        ViewThatFits(in: .horizontal) {
            row(tint, dots: hasDots, chevron: showsChevron, compact: false, flexible: false)
            row(tint, dots: hasDots, chevron: false, compact: false, flexible: false)
            row(tint, dots: hasDots, chevron: false, compact: true, flexible: false)
            row(tint, dots: false, chevron: false, compact: true, flexible: true)
        }
        .modifier(HeaderLabel(label: badge.map { "\(title), \($0)" }))
    }

    private func row(_ tint: Color, dots: Bool, chevron: Bool, compact: Bool, flexible: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)
                .background(tint.opacity(scheme == .dark ? 0.20 : 0.13), in: Circle())
            if let badge {
                if dots, let pager { DailyPagerDots(info: pager) }
                Spacer(minLength: 0)
                Text(badge)
                    .font((compact ? Font.caption2 : Font.caption).weight(.bold))
                    .foregroundStyle(.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(flexible ? 0.7 : 1)
                    .fixedSize(horizontal: !flexible, vertical: false)
                    .padding(.horizontal, compact ? 8 : 12)
                    .frame(minHeight: compact ? 22 : 24)
                    .background(Color.accentColor, in: Capsule())
            } else {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(flexible ? 0.7 : 1)
                    .fixedSize(horizontal: !flexible, vertical: false)
                if dots, let pager { DailyPagerDots(info: pager) }
                Spacer(minLength: 0)
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
            }
        }
    }
}

/// With a tag instead of the title, the header reads as « title, tag » for VoiceOver.
private struct HeaderLabel: ViewModifier {
    let label: String?

    @ViewBuilder func body(content: Content) -> some View {
        if let label {
            content.accessibilityElement(children: .ignore).accessibilityLabel(Text(label))
        } else {
            content
        }
    }
}

/// The frame of a tile: its label on top, the content below, on a Cristal panel (glass for the card to do right now).
private struct DayCard<Content: View>: View {
    let title: String
    let symbol: String
    let colorHex: String
    var route: HomeRoute?
    /// A tag next to the title (« Maintenant »): the card to do right now.
    var badge: String? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = style.cristal
        let card = VStack(alignment: .leading, spacing: 8) {
            DayHeader(title: title, symbol: symbol, colorHex: colorHex, badge: badge, showsChevron: route != nil)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        if let route {
            NavigationLink(value: route) { surface(card, radius: palette.radius) }
                .buttonStyle(.pressable)
        } else {
            surface(card, radius: palette.radius)
                .accessibilityElement(children: .contain)
        }
    }

    /// The same panel with or without « Maintenant » (PDG, 2026-11-16: only the information changes). The glass
    /// it used to wear for the card to do now changed its look, and its blur was cut square by the card's pager.
    private func surface<V: View>(_ view: V, radius: CGFloat) -> some View {
        view.cristalPanel(radius: radius)
    }
}

private struct NutritionDayTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(Router.self) private var router
    @Environment(\.dailyCompact) private var compact
    @Environment(\.appStyle) private var style

    var body: some View {
        if compact { compactBody } else { wideBody }
    }

    /// Half width: the ring with what is left beside it, the three macros on one line each, then
    /// the scanner and the meals.
    private var compactBody: some View {
        let nutritionColor = style.cristal.category("F08A24")
        return VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: HomeRoute.app(.nutrition)) {
                VStack(alignment: .leading, spacing: 10) {
                    DayHeader(title: tr("Nutrition"), symbol: "fork.knife", colorHex: "F08A24", showsChevron: true)
                    HStack(spacing: 10) {
                        RingView(progress: nutrition.knowsKcal ? nutrition.eaten.kcal / max(1, nutrition.goals.kcal) : 0, lineWidth: 7, color: nutritionColor, track: NutritionColors.track)
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(TF.int(abs(nutrition.kcalLeft ?? nutrition.eaten.kcal)))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(nutrition.kcalLeft.map { $0 >= 0 ? tr("kcal restantes") : tr("kcal en trop") } ?? tr("kcal mangées"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    VStack(spacing: 6) {
                        compactMacro(tr("Protéines"), nutrition.eaten.protein, nutrition.knowsProtein ? nutrition.goals.protein : nil, NutritionColors.proteinHex, incomplete: nutrition.eaten.isIncomplete)
                        compactMacro(tr("Glucides"), nutrition.eaten.carbs, nutrition.knowsCarbs ? nutrition.goals.carbs : nil, NutritionColors.carbsHex, incomplete: nutrition.eaten.isIncomplete)
                        compactMacro(tr("Lipides"), nutrition.eaten.fat, nutrition.knowsFat ? nutrition.goals.fat : nil, NutritionColors.fatHex, incomplete: nutrition.eaten.isIncomplete)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("daily-nutrition-open")
            HStack(spacing: 6) {
                Button {
                    router.isFoodScanPresented = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.onAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(tr("Scanner")))
                .accessibilityIdentifier("daily-scan")
                NavigationLink(value: HomeRoute.app(.nutrition)) {
                    Text(mealsText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(style.cristal.tintColor, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .cristalPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-nutrition")
    }

    /// A macro on one line: its colour, its name, eaten over the target; a thin bar under it.
    private func compactMacro(_ name: String, _ eaten: Double, _ goal: Double?, _ hex: String, incomplete: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(style.cristal.category(hex)).frame(width: 6, height: 6)
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Text((incomplete ? NutritionTotals.minimumMarker : "") + (goal.map { "\(TF.int(eaten))/\(TF.int($0))" } ?? "\(TF.int(eaten)) g"))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if let goal {
                BarView(progress: eaten / max(1, goal), color: style.cristal.category(hex), track: style.cristal.category(hex).opacity(0.15), height: 4)
            }
        }
    }

    private var wideBody: some View {
        let nutritionColor = style.cristal.category("F08A24")
        return VStack(alignment: .leading, spacing: 10) {
            // The label of the card (the pager's dots sit under it).
            NavigationLink(value: HomeRoute.app(.nutrition)) {
                DayHeader(title: tr("Nutrition"), symbol: "fork.knife", colorHex: "F08A24", showsChevron: true)
            }
            .buttonStyle(.pressable)
            NavigationLink(value: HomeRoute.app(.nutrition)) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        RingView(progress: nutrition.knowsKcal ? nutrition.eaten.kcal / max(1, nutrition.goals.kcal) : 0, lineWidth: 9, color: nutritionColor, track: NutritionColors.track)
                        VStack(spacing: 0) {
                            if let left = nutrition.kcalLeft {
                                Text(TF.int(abs(left)))
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                Text(left >= 0 ? tr("kcal restantes") : tr("kcal en trop"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(TF.int(nutrition.eaten.kcal))
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                Text(tr("kcal mangées"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(8)
                    }
                    .frame(width: 90, height: 90)
                    VStack(alignment: .leading, spacing: 9) {
                        if !nutrition.knowsKcal {
                            Text(tr("Objectif à définir"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        macro(tr("Protéines"), nutrition.eaten.protein, nutrition.knowsProtein ? nutrition.goals.protein : nil, NutritionColors.proteinHex, incomplete: nutrition.eaten.isIncomplete)
                        macro(tr("Glucides"), nutrition.eaten.carbs, nutrition.knowsCarbs ? nutrition.goals.carbs : nil, NutritionColors.carbsHex, incomplete: nutrition.eaten.isIncomplete)
                        macro(tr("Lipides"), nutrition.eaten.fat, nutrition.knowsFat ? nutrition.goals.fat : nil, NutritionColors.fatHex, incomplete: nutrition.eaten.isIncomplete)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("daily-nutrition-open")
            HStack(spacing: 10) {
                Button {
                    router.isFoodScanPresented = true
                } label: {
                    Label(tr("Scanner"), systemImage: "barcode.viewfinder")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(style.cristal.tintColor, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("daily-scan")
                NavigationLink(value: HomeRoute.app(.nutrition)) {
                    Text(mealsText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.pressable)
            }
            if let meal = nutrition.nextMeal, let kcal = nutrition.nextMealKcal, kcal > 0 {
                Text(tr("Prochain repas : \(meal.lowercased()), environ \(TF.int(kcal)) kcal"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .cristalPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-nutrition")
    }

    private var mealsText: String {
        nutrition.foods == 0 ? tr("Rien noté") : Fmt.plural(nutrition.meals, tr("repas", context: "one"), tr("repas"))
    }

    private func macro(_ name: String, _ eaten: Double, _ goal: Double?, _ hex: String, incomplete: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.subheadline.weight(.semibold))
                Spacer()
                Text((incomplete ? NutritionTotals.minimumMarker : "") + (goal.map { "\(TF.int(eaten))/\(TF.int($0)) g" } ?? "\(TF.int(eaten)) g"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let goal {
                BarView(progress: eaten / max(1, goal), color: style.cristal.category(hex), track: style.cristal.category(hex).opacity(0.15), height: 6)
            }
        }
    }
}

/// The long-press menu of today's finished session: delete it, or arrange the cards. Without a finished session there
/// is no menu, so the long press reaches « Mon Quotidien » (edit mode).
private struct WorkoutMenu: ViewModifier {
    let doneTodayID: UUID?
    @Binding var deleting: UUID?
    let actions: DailyCardActions?

    @ViewBuilder func body(content: Content) -> some View {
        if let id = doneTodayID {
            content.contextMenu {
                Button(role: .destructive) {
                    deleting = id
                } label: {
                    Label(tr("Supprimer la séance"), systemImage: "trash")
                }
                if let actions {
                    DailyCardMenuItems(actions: actions)
                }
            }
        } else {
            content
        }
    }
}

private struct WorkoutDayTile: View {
    let workout: DailyBrief.Workout
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCardActions) private var cardActions
    @Environment(\.appStyle) private var style
    /// Today's session recorded by mistake, to delete once confirmed (it can then be done again).
    @State private var deleting: UUID?

    /// Today's finished session (the « Faite » card), the one « Supprimer la séance » removes.
    private var doneTodayID: UUID? {
        guard case .done = workout.stage else { return nil }
        let now = Date()
        return FitnessMath.sessions(model.fitness).last { DateMath.isSameDay($0.start, now) && $0.isFinished }?.id
    }

    var body: some View {
        DayCard(title: title, symbol: "figure.strengthtraining.traditional", colorHex: "E5484D", route: .space(.fitness), badge: nowBadge) {
            switch workout.stage {
            case .planned:
                Text(tr("Séance du jour"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(Fmt.plural(workout.exercises.count, tr("exercice"), tr("exercices"))) · \(Fmt.plural(workout.totalSets, tr("série"), tr("séries")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                actionButton(tr("Commencer"), symbol: "play.fill") {
                    model.update(\.fitness) { state in
                        if let routine = state.routine(for: Date()) { state.startSession(routine, at: Date()) }
                    }
                }
            case let .inProgress(exercise, set, sets, reps, weight, restEndsAt):
                Text(tr("Séance en cours"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(exercise)
                    .font(.headline)
                    .lineLimit(1)
                Text(tr("Série \(set)/\(sets) · \(reps) × \(weight > 0 ? Units.loadText(kilograms: weight, in: model.settings.unitSystem) : tr("poids du corps"))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // The rest: counting down with a pause button, or paused with a button to start again.
                if let paused = model.fitness.active?.restPausedRemaining {
                    restControl(Text(tr("Pause · \(Duration.seconds(paused).formatted(.time(pattern: .minuteSecond)))")), symbol: "play.fill",
                                label: tr("Reprendre le repos")) { $0.resumeRest(at: Date()) }
                } else if let restEndsAt, restEndsAt > Date() {
                    restControl(Text(timerInterval: Date()...restEndsAt, countsDown: true), symbol: "pause.fill",
                                label: tr("Mettre le repos en pause")) { $0.pauseRest(at: Date()) }
                }
                Spacer(minLength: 4)
                actionButton(tr("Série faite"), symbol: "checkmark") {
                    var accepted = false
                    model.update(\.fitness) { accepted = $0.completeNextSet(at: Date()) }
                    if accepted { Haptics.tap() }
                }
            case let .done(sets, volume):
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                Label(tr("Faite · \(Fmt.plural(sets, tr("série"), tr("séries")))"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.cristal.okColor)
                if volume > 0 {
                    Text(tr("\(Units.loadText(kilograms: volume, in: model.settings.unitSystem, digits: 0)) soulevés"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case let .rest(nextName, nextDay):
                Text(tr("Repos aujourd'hui"))
                    .font(.headline)
                if let nextName, let nextDay {
                    Text("\(nextDay) : \(nextName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        // A menu only for a session to delete (it takes the long press); otherwise the long press starts the edit mode.
        .modifier(WorkoutMenu(doneTodayID: doneTodayID, deleting: $deleting, actions: cardActions))
        .confirmsWorkoutDeletion($deleting)
        .accessibilityIdentifier("daily-workout")
    }

    /// The session to do right now: in progress, or still planned from the afternoon on (the moment
    /// where Mon Quotidien puts it first).
    private var isNow: Bool {
        switch workout.stage {
        case .inProgress: true
        case .planned: DailyBrief.Moment(Date()) != .morning
        default: false
        }
    }

    /// The card to do right now: a session in progress, or a planned one from the afternoon on.
    private var nowBadge: String? {
        isNow ? tr("Maintenant") : nil
    }

    private var title: String {
        switch workout.stage {
        case .inProgress, .planned: tr("Séance")
        case .done: tr("Séance du jour")
        case .rest: tr("Sport")
        }
    }

    private func restControl(_ time: Text, symbol: String, label: String, change: @escaping (inout FitnessState) -> Void) -> some View {
        HStack(spacing: 8) {
            time
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
            Button {
                Haptics.tap()
                model.update(\.fitness, change)
            } label: {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 24)
                    .background(style.cristal.tintColor, in: Capsule())
                    .tapAreaOutset(10)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(label))
        }
    }

    private func actionButton(_ title: String, symbol: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.onAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.pressable)
    }
}

/// The week as a table: classes, work, appointments, tasks, workouts and the events of the Apple
/// calendar, a column a day. A touch anywhere on the card opens Planning, where a touch on a free time of
/// the calendar creates an event. Half width: the same table, its blocks without text. While the Apple
/// calendar isn't linked, its button stays apart: the table opens Planning, the button links the calendar.
private struct PlanningDayTile: View {
    let items: [DailyBrief.TimedItem]
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCompact) private var compact
    @State private var events: [EventSnapshot] = []
    @State private var askingCalendar = false

    private let colorHex = "3366FF"

    var body: some View {
        let week = Agenda.week(containing: Date(), model: model, events: events)
        let isEmpty = week.allSatisfy { $0.items.isEmpty }
        Group {
            if model.events == .needsAccess {
                DayCard(title: tr("Planning"), symbol: "calendar.day.timeline.left", colorHex: colorHex) {
                    NavigationLink(value: HomeRoute.app(.planning)) {
                        table(week, isEmpty: isEmpty)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(tr("Planning")))
                    .accessibilityValue(Text(isEmpty ? tr("Rien de prévu cette semaine.") : ""))
                    .accessibilityIdentifier("daily-planning-week")
                    calendarButton
                }
            } else {
                DayCard(title: tr("Planning"), symbol: "calendar.day.timeline.left", colorHex: colorHex, route: .app(.planning)) {
                    table(week, isEmpty: isEmpty)
                        .accessibilityIdentifier("daily-planning-week")
                }
                // VoiceOver: the card reads as Planning, not as every block of the table.
                .accessibilityLabel(Text(tr("Planning")))
                .accessibilityValue(Text(isEmpty ? tr("Rien de prévu cette semaine.") : ""))
            }
        }
        .accessibilityIdentifier("daily-planning")
        .onAppear(perform: loadEvents)
        .onChange(of: model.events) { _, _ in loadEvents() }
        .permissionSheet(.calendar, isPresented: $askingCalendar, request: requestCalendar) { _ in
            model.refreshEvents()
            loadEvents()
        }
    }

    private func requestCalendar() async {
        _ = await CalendarService.requestAccess()
    }

    private func table(_ week: [(day: Date, items: [AgendaItem])], isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if compact {
                if isEmpty {
                    emptyText
                } else {
                    WeekTimetable(days: week, compact: true, hourHeight: 12)
                }
            } else {
                // Empty, the table stays: Planning is where its free times are filled.
                if isEmpty { emptyText }
                WeekTimetable(days: week, hourHeight: 22)
            }
            if compact { Spacer(minLength: 0) }
            weekLabel
                .frame(minHeight: compact ? nil : 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The Apple calendar, one tap away when it isn't linked yet.
    private var calendarButton: some View {
        Button {
            Task {
                // Explanation first (once); refused, the sheet offers the settings and the card keeps working.
                if let state = await AppPermission.calendar.requestOrExplain(isPresented: $askingCalendar, request: requestCalendar), state == .granted {
                    model.refreshEvents()
                    loadEvents()
                }
            }
        } label: {
            Label(tr("Relier le calendrier Apple"), systemImage: "calendar.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("daily-planning-calendar")
    }

    private var emptyText: some View {
        Text(tr("Rien de prévu cette semaine."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var weekLabel: some View {
        HStack(spacing: 3) {
            Text(tr("Toute la semaine"))
            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.accentColor)
    }

    /// The calendar events of the whole week, the days already gone included.
    private func loadEvents() {
        guard CalendarService.hasAccess, let first = DateMath.week(containing: Date()).first else { return }
        events = CalendarService.events(from: first, to: first.addingTimeInterval(7 * 86_400))
    }
}

private struct HabitsDayTile: View {
    let done: Int
    let items: [DailyBrief.Check]
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCompact) private var compact
    @Environment(\.appStyle) private var style
    /// The height of a habit's row on the wide card, with the text size.
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 20

    /// The habits shown, the others counted (« +2 »).
    private static let limit = 5

    /// The longest run of days in a row among the habits (nothing shown without one).
    private var streak: Int { items.map(\.streak).max() ?? 0 }

    private var names: String { items.map { $0.isDone ? "\($0.title) ✓" : $0.title }.joined(separator: ", ") }

    var body: some View {
        DayCard(title: tr("Habitudes"), symbol: "repeat", colorHex: "5C8424", route: .page(.planningHabits)) {
            if compact {
                // One ring a habit, in its own color: full with a check when done today.
                HStack(spacing: 6) {
                    ForEach(items.prefix(Self.limit)) { item in
                        ring(item, size: 22)
                    }
                    if items.count > Self.limit { more }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(names))
                    .padding(.top, 4)
                count
                Text(tr("faites aujourd'hui"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if streak > 0 {
                    streakText(bold: true)
                } else {
                    Text(names)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                // The whole width (request of 2026-11-08): one row a habit, its ring of today and its last days as
                // small squares, like the medium Habits widget.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    count
                    Spacer(minLength: 8)
                    if streak > 0 { streakText(bold: false) }
                }
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(items.prefix(Self.limit)) { item in
                        row(item)
                    }
                    if items.count > Self.limit { more }
                }
            }
        }
        .accessibilityIdentifier("daily-habits")
    }

    /// Today's state of a habit, in its own color: a ring, full with a check when done.
    private func ring(_ item: DailyBrief.Check, size: CGFloat) -> some View {
        let color = style.cristal.category(item.colorHex ?? "7FA33A")
        return ZStack {
            Circle().strokeBorder(color, lineWidth: 2.5)
            if item.isDone {
                Circle().fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(style.cristal.panelSolidColor)
            }
        }
        .frame(width: size, height: size)
    }

    private var count: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(done)")
                .font(.largeTitle.weight(.bold))
            Text("/\(items.count)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func streakText(bold: Bool) -> some View {
        Text(tr("Série de \(Fmt.plural(streak, tr("jour"), tr("jours")))"))
            .font(bold ? Font.caption.weight(.semibold) : Font.caption)
            .foregroundStyle(bold ? Color.primary : Color.secondary)
            .lineLimit(2)
    }

    private var more: some View {
        Text("+\(items.count - Self.limit)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    /// One habit across the card: its ring of today, its name, then its last days, today last, as many small squares
    /// as the width holds (done in the habit's color, not done faint), the same way as the Habits widget.
    private func row(_ item: DailyBrief.Check) -> some View {
        let color = style.cristal.category(item.colorHex ?? "7FA33A")
        let habit = model.content.habits.first { $0.id.uuidString == item.id }
        let ringSize = min(rowHeight, 22)
        return GeometryReader { proxy in
            let nameWidth = min(max(proxy.size.width * 0.32, 64), 140)
            let gridWidth = max(0, proxy.size.width - ringSize - nameWidth - 16)
            HStack(spacing: 8) {
                ring(item, size: ringSize)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: nameWidth, alignment: .leading)
                if let habit, gridWidth > 0 {
                    // Cells of 12 points at most: one row of recent days, never the weeks of seven rows.
                    let days = HabitHeatmap.layout(width: gridWidth, height: 12).columns
                    HabitHeatmapGrid(columns: HabitHeatmap.recent(for: habit, days: days),
                                     doneColor: color, emptyColor: color.opacity(0.16))
                        .frame(width: gridWidth, alignment: .leading)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label(item, habit: habit)))
    }

    /// What VoiceOver says of a row: the habit (checked when done today) and its regularity over 30 days, as the
    /// Habits widget says it.
    private func label(_ item: DailyBrief.Check, habit: Habit?) -> String {
        let name = item.isDone ? "\(item.title) ✓" : item.title
        guard let habit, let rate = HabitHeatmap.rate(of: habit) else { return name }
        return "\(name), \(tr("Régularité")) : \(Fmt.percent(rate))"
    }
}

private struct StepsDayTile: View {
    let steps: Int
    let goal: Int?
    @Environment(\.appStyle) private var style

    var body: some View {
        DayCard(title: tr("Pas"), symbol: "figure.walk", colorHex: "12A4B5", route: .page(.fitnessActivity)) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Fmt.number(steps))
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                if let goal {
                    Text("/ \(Fmt.number(goal))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if let goal {
                BarView(progress: Double(steps) / Double(max(1, goal)), color: style.cristal.category("12A4B5"), track: style.cristal.category("12A4B5").opacity(0.15), height: 6)
            } else {
                Text(tr("Objectif à définir"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("daily-steps")
    }
}

/// What a mini-app card shows under its figure (PDG, 2026-11-25): Études, the classes entered; Business, two
/// figures that matter (profit and orders of the month) next to the revenue of the caption. Nothing for the others.
private struct MiniAppDayDetails: View {
    let app: MiniApp
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        switch app {
        case .studies:
            let courses = model.student.courses
            if !courses.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(courses.prefix(5)) { course in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(style.cristal.category(course.colorHex))
                                .frame(width: 8, height: 8)
                            Text(course.name)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                    if courses.count > 5 {
                        Text("+\(courses.count - 5)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        case .business:
            if !model.business.sales.isEmpty {
                let now = Date()
                let currency = model.settings.currencyCode
                let profit = BusinessMath.profit(model.business, month: now)
                let kpis = BusinessMath.kpis(model.business, month: now)
                VStack(alignment: .leading, spacing: 5) {
                    figure(tr("Bénéfice"), (profit.profit < 0 ? "−" : "") + TF.money(abs(profit.profit), currency))
                    if kpis.orders > 0 {
                        figure(tr("Commandes"), Fmt.number(kpis.orders))
                    }
                }
                .padding(.top, 2)
            }
        default:
            EmptyView()
        }
    }

    private func figure(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}

/// Finances (PDG, 2026-11-25): the balance with its curve over the month, then the next money in and out by date.
/// Without anything that gives a balance, the old daily view (left per day, spent today).
private struct BudgetDayTile: View {
    let spent: Double
    let perDayLeft: Double?
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        let currency = model.settings.currencyCode
        let now = Date()
        let budget = model.budget
        let hasBalance = budget.openingBalance != nil || !budget.incomes.isEmpty || !budget.fixedFlows.isEmpty
        let points = hasBalance ? BudgetMath.balanceHistory(budget, from: BudgetMath.monthInterval(now).start, now: now) : []
        let upcoming = Array(BudgetMath.upcoming(budget, at: now, within: 30).prefix(3))
        DayCard(title: tr("Finances"), symbol: "creditcard.fill", colorHex: "2F8F7A", route: .space(.budget)) {
            if let current = points.last?.balance {
                Text((current < 0 ? "−" : "") + TF.money(abs(current), currency))
                    .font(.title.weight(.bold))
                    .foregroundStyle(current < 0 ? Color.red : .primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(tr("Solde"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if points.count >= 2 {
                    SparklineShape(values: points.map(\.balance))
                        .stroke(style.cristal.category("2F8F7A"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .frame(height: 40)
                        .padding(.vertical, 2)
                        .accessibilityHidden(true)
                }
            } else {
                if let perDayLeft {
                    Text(TF.money(perDayLeft, currency))
                        .font(.title.weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(tr("à dépenser par jour d'ici la fin du mois"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(tr("Dépensé aujourd'hui : \(TF.money(spent, currency))"))
                    .font(perDayLeft == nil ? .headline : .caption.weight(.semibold))
                    .foregroundStyle(perDayLeft == nil ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(upcoming) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(item.isIncome ? Color.green : style.cristal.category("2F8F7A"))
                    Text(item.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(item.days < 7 ? Fmt.weekday(item.due) : Fmt.shortDay(item.due))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text((item.isIncome ? "+" : "−") + TF.money(item.amount, currency))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.isIncome ? Color.green : .primary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("daily-budget")
    }
}

/// « À ne pas oublier »: the tasks the person noted (it replaced the Top 3, PDG 2026-11-25; build 582). A tap on the circle
/// checks the task; the field adds one; the footer opens the whole list (« Mes tâches »).
private struct RemindersDayTile: View {
    let items: [DailyBrief.Reminder]
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCompact) private var compact
    @State private var draft = ""

    var body: some View {
        DayCard(title: tr("À ne pas oublier"), symbol: "checklist", colorHex: "6B7280", route: nil) {
            VStack(alignment: .leading, spacing: 7) {
                if items.isEmpty {
                    Text(tr("Aucune tâche"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    Button {
                        if let id = UUID(uuidString: item.id) {
                            model.updateContent { $0.toggleTask(id) }
                            Haptics.tap()
                        }
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityValue(tr("À faire"))
                }
                footer
            }
        }
        .accessibilityIdentifier("daily-reminders")
    }

    private func row(_ item: DailyBrief.Reminder) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
            Text(item.title)
                .font(compact ? .caption.weight(.semibold) : .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(compact ? 2 : 1)
            Spacer(minLength: 6)
            if !item.when.isEmpty {
                Text(item.when)
                    .font(.caption)
                    .foregroundStyle(item.when == tr("En retard") ? Color.red : .secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    /// The field to add a task in one gesture, and the way to the whole list.
    private var footer: some View {
        HStack(spacing: 8) {
            TextField(tr("Ajouter une tâche"), text: $draft)
                .font(.subheadline)
                .submitLabel(.done)
                .onSubmit(add)
                .accessibilityIdentifier("daily-quick-task-field")
            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(draft.trimmed.isEmpty ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.pressable)
            .disabled(draft.trimmed.isEmpty)
            .accessibilityLabel(Text(tr("Ajouter une tâche")))
            .accessibilityIdentifier("daily-quick-task-add")
            NavigationLink(value: HomeRoute.page(.planningTasks)) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .tapAreaOutset(4)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(tr("Mes tâches")))
            .accessibilityIdentifier("daily-all-tasks")
        }
        .padding(.top, items.isEmpty ? 0 : 2)
    }

    private func add() {
        let title = draft.trimmed
        guard !title.isEmpty else { return }
        model.updateContent { $0.tasks.append(TaskItem(title: title)) }
        Haptics.tap()
        draft = ""
    }
}

private struct InviteDayTile: View {
    let area: InfoArea

    var body: some View {
        InviteCard(title: area.title, symbol: area.symbol, colorHex: area.colorHex, text: invitation,
                   route: area.homeRoute, identifier: "daily-invite-\(area.rawValue)")
    }

    private var invitation: String {
        switch area {
        case .nutrition: tr("Donne ton objectif calorique ou scanne un repas : tes calories du jour apparaîtront ici.")
        case .fitness: tr("Crée ton programme : ta séance du jour apparaîtra ici.")
        case .student: tr("Ajoute tes cours : ton horaire du jour apparaîtra ici.")
        case .budget: tr("Donne ton budget du mois pour voir ce qu'il te reste chaque jour.")
        case .habits: tr("Ajoute une habitude à suivre chaque jour.")
        case .productivity: tr("Ajoute tes tâches ou ton top 3 du jour.")
        default: area.items.first?.purpose ?? ""
        }
    }
}

/// The dotted card of a category with nothing entered yet: its icon, name and what will show here,
/// « Ajouter » on the right; a tap opens the mini-app, where the missing information is filled in.
private struct InviteCard: View {
    let title: String
    let symbol: String
    let colorHex: String
    let text: String
    let route: HomeRoute
    let identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.appStyle) private var style
    @Environment(\.dailyCompact) private var compact

    var body: some View {
        let tint = style.cristal.category(colorHex)
        NavigationLink(value: route) {
            Group {
                if compact { compactContent(tint) } else { wideContent(tint) }
            }
            .padding(14)
            .cristalPanel(radius: style.cristal.radius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }

    /// Half width, next to another card: the name on top, the invitation under it, « Ajouter » at the bottom.
    private func compactContent(_ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !typeSize.isAccessibilitySize {
                Text(tr("Ajouter"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(style.cristal.tintColor, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func wideContent(_ tint: Color) -> some View {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                // At the biggest text sizes « Ajouter » would squeeze the invitation: the whole card is the button.
                if !typeSize.isAccessibilitySize {
                    Text(tr("Ajouter"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(style.cristal.tintColor, in: Capsule())
                        .layoutPriority(1)
                }
            }
    }
}

/// The grey dotted « + » at the bottom of Mon Quotidien: it opens the list of the categories not on it yet.
/// Same shape and dashes as the invitation cards, but compact and neutral.
private struct AddCategoryCard: View {
    let action: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, minHeight: 64)
                .cristalPanel(radius: style.cristal.radius)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(tr("Ajouter une catégorie")))
        .accessibilityIdentifier("daily-add-category")
    }
}

/// The categories missing from Mon Quotidien, one row each (its symbol and color, its name): a touch adds
/// it (an empty card if nothing is filled yet, never a made-up figure) and closes the list.
private struct AddCategorySheet: View {
    let categories: [DailyBrief.Category]
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var style

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        let tint = style.cristal.category(category.colorHex)
                        Button {
                            Haptics.tap()
                            model.updateSettings { DailyCategories.add(category, in: &$0) }
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(tint)
                                    .frame(width: 30, height: 30)
                                    .background(tint.opacity(0.14), in: Circle())
                                Text(category.title)
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("daily-add-\(category.rawValue)")
                    }
                } footer: {
                    Text(tr("Une carte vide s'affiche tant que tu n'as rien rempli : aucune donnée n'est inventée."))
                }
            }
            .styledList()
            .navigationTitle(tr("Ajouter une catégorie"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Fermer")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Other views of the cards (swiped left or right)

private struct NutritionMealsTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCompact) private var compact

    var body: some View {
        let state = model.nutrition
        DayCard(title: tr("Repas du jour"), symbol: "fork.knife", colorHex: "F08A24", route: .app(.nutrition)) {
            VStack(spacing: compact ? 5 : 6) {
                ForEach(MealType.allCases) { meal in
                    let kcal = NutritionMath.totals(of: meal, state, on: Date()).kcal
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(meal.title)
                            .font((compact ? Font.caption : .subheadline).weight(kcal > 0 ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Text(kcal > 0 ? (compact ? TF.int(kcal) : tr("\(TF.int(kcal)) kcal")) : "—")
                            .font(compact ? .caption : .subheadline)
                            .monospacedDigit()
                            .foregroundStyle(kcal > 0 ? .primary : .secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
                Divider()
                if compact {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Total")).font(.caption.weight(.bold))
                        Text(nutrition.knowsKcal ? tr("\(TF.int(nutrition.eaten.kcal)) / \(TF.int(nutrition.goals.kcal)) kcal") : tr("\(TF.int(nutrition.eaten.kcal)) kcal"))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Text(tr("Total")).font(.subheadline.weight(.bold))
                        Spacer()
                        Text(nutrition.knowsKcal ? tr("\(TF.int(nutrition.eaten.kcal)) / \(TF.int(nutrition.goals.kcal)) kcal") : tr("\(TF.int(nutrition.eaten.kcal)) kcal"))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityIdentifier("daily-nutrition-meals")
    }
}

private struct NutritionWeekTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(AppModel.self) private var model

    var body: some View {
        let days = NutritionMath.dailyCalories(model.nutrition, days: 7, until: Date())
        let logged = days.filter { $0 > 0 }
        DayCard(title: tr("Calories · 7 jours"), symbol: "chart.bar.fill", colorHex: "F08A24", route: .page(.nutritionHistory)) {
            DailyWeekBars(values: days, goal: nutrition.knowsKcal ? nutrition.goals.kcal : nil, colorHex: "F08A24")
            Text(logged.isEmpty ? tr("Rien noté cette semaine") : tr("Moyenne : \(TF.int(logged.reduce(0, +) / Double(logged.count))) kcal par jour noté"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("daily-nutrition-week")
    }
}

private struct WorkoutWeekTile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        let state = model.fitness
        let now = Date()
        let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: now)
        let done = FitnessMath.sessions(state).filter { session in
            session.isFinished && (week?.contains(session.start) ?? false)
        }
        let goal = state.weeklyGoal
        DayCard(title: tr("Cette semaine"), symbol: "calendar", colorHex: "E5484D", route: .space(.fitness)) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done.count)")
                    .font(.title.weight(.bold))
                Text(tr("/\(goal) séances"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = week.flatMap { DateMath.calendar.date(byAdding: .day, value: offset, to: $0.start) } ?? now
                    let trained = done.contains { DateMath.isSameDay($0.start, day) }
                    Circle()
                        .fill(trained ? style.cristal.category("E5484D") : Color.secondary.opacity(DateMath.isSameDay(day, now) ? 0.45 : 0.18))
                        .frame(width: 12, height: 12)
                        .frame(maxWidth: .infinity)
                }
            }
            Text(done.count >= goal ? tr("Objectif de la semaine atteint") : tr("Encore \(Fmt.plural(goal - done.count, tr("séance"), tr("séances")))"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("daily-workout-week")
    }
}

private struct StepsWeekTile: View {
    let goal: Int?
    private var counter: StepCounter { .shared }

    var body: some View {
        let days = counter.week.suffix(7)
        let values = days.map { Double($0.steps) }
        DayCard(title: tr("Pas · 7 jours"), symbol: "figure.walk", colorHex: "12A4B5", route: .page(.fitnessActivity)) {
            if values.isEmpty {
                Text(tr("La semaine apparaîtra ici."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                DailyWeekBars(values: Array(values), goal: goal.map(Double.init), colorHex: "12A4B5", height: 44)
                Text(tr("Moyenne : \(Fmt.number(Int(values.reduce(0, +) / Double(values.count)))) pas"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await counter.refreshWeek() }
        .accessibilityIdentifier("daily-steps-week")
    }
}

/// The gold « Premium » sign of Home, by the title of « Mon Quotidien », shown only to whoever hasn't Premium:
/// a touch opens the offer. Dark brown on gold, readable in light and dark mode.
private struct PremiumGoldBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                // The Ardane A in place of the crown, in the same dark brown (CEO, 2026-11-24).
                ArdaneGlyph(size: 14, color: Color(hex: "3D2A00"))
                Text(tr("Premium"))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(hex: "3D2A00"))
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(
                LinearGradient(colors: [Color(hex: "FCE9A8"), Color(hex: "E8BE55"), Color(hex: "D3A23C")],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8) }
            .shadow(color: Color(hex: "B8862B").opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .fixedSize()
        .accessibilityLabel(Text(tr("Premium")))
        .accessibilityHint(Text(tr("Découvrir Premium")))
        .accessibilityIdentifier("daily-premium")
    }
}
