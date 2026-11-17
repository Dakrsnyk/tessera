import SwiftUI
import WidgetKit

/// The tutorial, drawn above the whole app: the app dimmed except the part the step talks about,
/// and a card that explains it. The app stays still underneath (the tour changes tabs by itself).
struct TutorialOverlay: View {
    let step: TutorialStep
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var cardSize: CGSize = CGSize(width: 360, height: 260)
    /// False just after a step changes, while the tab it shows lays itself out.
    @State private var settled = false
    @State private var triedStudio = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let origin = proxy.frame(in: .global).origin
            let safe = proxy.safeAreaInsets
            let plan = layout(in: size, origin: origin, safe: safe)
            ZStack(alignment: .top) {
                dimming(size: size, hole: plan.hole, radius: plan.holeRadius)
                if let hole = plan.hole {
                    RoundedRectangle(cornerRadius: plan.holeRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                card
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 14)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: {
                        cardSize = $0
                        TutorialFrames.shared.cardHeight = $0.height
                    }
                    .position(x: size.width / 2, y: plan.card.midY)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86), value: plan)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86), value: step)
        }
        .ignoresSafeArea()
        .task(id: step) { await show(step) }
    }

    // MARK: Layout

    /// Where the light and the card go (rules in `TutorialLayout`). Read here so the overlay follows the parts as they
    /// move (a tab laying itself out, a scroll). Nothing is lit before the tab is laid out, or when no part fits whole.
    private func layout(in size: CGSize, origin: CGPoint, safe: EdgeInsets) -> TutorialLayout.Plan {
        let candidates: [TutorialLayout.Candidate?] = settled
            ? step.targets.map { group in
                TutorialFrames.shared.candidate(for: group).map {
                    TutorialLayout.Candidate(frame: $0.frame.offsetBy(dx: -origin.x, dy: -origin.y), radius: $0.radius)
                }
            }
            : Array(repeating: nil, count: step.targets.count)
        return TutorialLayout.plan(candidates: candidates, screen: size, safeTop: safe.top, safeBottom: safe.bottom, card: cardSize)
    }

    /// The app, dimmed, with a hole where the step looks. It also keeps the app from being touched.
    private func dimming(size: CGSize, hole: CGRect?, radius: CGFloat) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let hole {
                path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
            }
        }
        .fill(Color.black.opacity(0.58), style: FillStyle(eoFill: true))
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityHidden(true)
    }

    // MARK: The card

    private var firstName: String {
        model.settings.profileName.trimmed.split(separator: " ").first.map(String.init) ?? ""
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text(step.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            demo
            buttons
        }
        .padding(18)
        // Opaque on purpose: the bubble sits over the dimmed app, a translucent panel would let it show through.
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tutorial-card")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label(step.place(name: firstName), systemImage: step.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
            Spacer(minLength: 0)
            Text("\(step.number) / \(TutorialStep.allCases.count)")
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(tr("Étape \(step.number) sur \(TutorialStep.allCases.count)")))
                .accessibilityIdentifier("tutorial-step")
            Button {
                finish()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.pressable)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(Text(tr("Quitter le tutoriel")))
            .accessibilityIdentifier("tutorial-close")
        }
    }

    @ViewBuilder private var demo: some View {
        switch step {
        case .studio:
            TutorialStudioDemo(tried: $triedStudio)
        case .homeScreen:
            VStack(alignment: .leading, spacing: 10) {
                AddStepRow(number: 1, symbol: "hand.tap", text: tr("Appuie longuement sur un espace vide de l'écran d'accueil"))
                AddStepRow(number: 2, symbol: "plus", text: tr("Touche « Modifier », puis « Ajouter un widget »"))
                AddStepRow(number: 3, symbol: "magnifyingglass", text: tr("Cherche « Ardane », choisis la taille, puis ton widget"))
            }
        default:
            EmptyView()
        }
    }

    private var progress: some View {
        // Each step can be reached directly: skip several at once.
        HStack(spacing: 4) {
            ForEach(TutorialStep.allCases) { item in
                Button {
                    go(to: item)
                } label: {
                    Capsule()
                        .fill(item.number <= step.number ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 5)
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(tr("Aller à l'étape \(item.number) : \(item.title)")))
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        VStack(spacing: 6) {
            progress
            HStack(spacing: 10) {
                switch step {
                case .welcome:
                    Button(tr("Passer le tutoriel")) { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("tutorial-skip-all")
                case .finish:
                    EmptyView()
                default:
                    Button(tr("Passer l'étape")) { advance() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("tutorial-skip")
                }
                Spacer(minLength: 0)
                Button(action: step == .finish ? finish : advance) {
                    // On one line, whatever the length of the button beside it.
                    Text(primaryTitle)
                        .font(.headline)
                        .foregroundStyle(.onAccent)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 22)
                        .frame(minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("tutorial-next")
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: tr("Commencer")
        case .finish: tr("Terminer")
        default: tr("Suivant")
        }
    }

    // MARK: Actions

    /// Shows the step's tab, at the top, then lights up its part once it is laid out.
    private func show(_ step: TutorialStep) async {
        settled = false
        if router.tab != step.tab {
            router.tab = step.tab
        }
        router.homePath = []
        router.spacePath = []
        router.storePath = []
        // A step that lights something up waits a little longer: the tab may first scroll the part into place.
        try? await Task.sleep(for: .milliseconds(step.targets.isEmpty ? 450 : 900))
        guard !Task.isCancelled else { return }
        settled = true
    }

    private func advance() {
        Haptics.tap()
        if let next = step.next {
            router.tutorialStep = next
        } else {
            finish()
        }
    }

    private func go(to item: TutorialStep) {
        guard item != step else { return }
        Haptics.tap()
        router.tutorialStep = item
    }

    private func finish() {
        Haptics.success()
        model.updateSettings { $0.hasSeenTutorial = true }
        router.tab = .home
        withAnimation(.easeOut(duration: 0.25)) { router.tutorialStep = nil }
    }
}

/// The Studio in miniature: a widget, the main colors, two palettes and the undo and redo arrows,
/// all working, to try what the Studio does.
struct TutorialStudioDemo: View {
    @Binding var tried: Bool
    @State private var design = WidgetDesign(kind: .caloriesLeft, themeID: .modern, accentHex: "2F8F7A", format: .small)
    @State private var past: [WidgetDesign] = []
    @State private var future: [WidgetDesign] = []

    private static let colors = ["2F8F7A", "3366FF", "FF6B57", "F2A33A", "8C6CFF", "F2588F"]
    private static let palettes = ["neon", "sand", "midnight"]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            WidgetPreview(design: design, family: .systemSmall, payload: SamplePayload.make(for: design), width: 112)
                .animation(.easeInOut(duration: 0.25), value: design)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    arrow("arrow.uturn.backward", label: tr("Retour en arrière"), enabled: !past.isEmpty, action: undo)
                    arrow("arrow.uturn.forward", label: tr("Retour en avant"), enabled: !future.isEmpty, action: redo)
                    Spacer(minLength: 0)
                    if tried {
                        Label(tr("Bravo !"), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(tr("Bravo !")))
                            .accessibilityIdentifier("tutorial-bravo")
                    }
                }
                HStack(spacing: 6) {
                    ForEach(Self.colors, id: \.self) { hex in
                        Button {
                            change { $0.recolored(to: hex) }
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Circle().strokeBorder(Color.primary.opacity(design.style.recolor && design.accentHex == hex ? 0.8 : 0.1), lineWidth: 2)
                                }
                                .frame(minWidth: 28, minHeight: 32)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(Text(Palette.name(for: hex)))
                        .accessibilityIdentifier("tutorial-color-\(hex)")
                    }
                }
                HStack(spacing: 6) {
                    ForEach(Self.palettes, id: \.self) { id in
                        if let palette = ColorPalette.palette(id) {
                            Button {
                                change { palette.applied(to: $0) }
                            } label: {
                                Text(palette.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(hex: palette.text))
                                    .padding(.horizontal, 9)
                                    .frame(minHeight: 28)
                                    .background(Color(hex: palette.background[0]), in: Capsule())
                                    .overlay { Capsule().strokeBorder(Color(hex: palette.accent).opacity(0.8), lineWidth: 1.5) }
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel(Text(tr("Palette \(palette.name)")))
                        }
                    }
                }
            }
        }
        .animation(.snappy, value: tried)
    }

    private func arrow(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 30)
                .background(Color.primary.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.pressable)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }

    private func change(_ edit: (WidgetDesign) -> WidgetDesign) {
        Haptics.tap()
        past.append(design)
        future.removeAll()
        design = edit(design)
        tried = true
    }

    private func undo() {
        guard let previous = past.popLast() else { return }
        Haptics.tap()
        future.append(design)
        design = previous
    }

    private func redo() {
        guard let next = future.popLast() else { return }
        Haptics.tap()
        past.append(design)
        design = next
    }
}
