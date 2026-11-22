import SwiftUI
import Observation

// MARK: - State (pure, testable)

/// Which mini-apps already showed their discovery tour. One list in UserDefaults (`miniAppTourSeen`: the raw values of
/// the `MiniApp`s, and « habits »), so each tour is independent and survives a restart. The defaults are injected for tests.
struct MiniAppTourStore {
    static let key = "miniAppTourSeen"
    var defaults: UserDefaults = .standard

    var seen: Set<String> { Set(defaults.stringArray(forKey: Self.key) ?? []) }

    func isSeen(_ id: String) -> Bool { seen.contains(id) }

    func markSeen(_ id: String) {
        var all = seen
        all.insert(id)
        defaults.set(all.sorted(), forKey: Self.key)
    }

    /// First opening only. Someone who opened the mini-app before this update (`priorOpens` > 0, read BEFORE this
    /// opening is recorded) or who already has data there is an existing user: no tour.
    func shouldShow(_ id: String, priorOpens: Int, hasData: Bool) -> Bool {
        !isSeen(id) && priorOpens == 0 && !hasData
    }

    /// Decides and marks « seen » in the same breath: whatever happens next (the app is left, killed, the tour skipped)
    /// the tour never comes back. An existing user is marked too, so deleting their data later doesn't start a tour.
    func claim(_ id: String, priorOpens: Int, hasData: Bool) -> Bool {
        let show = shouldShow(id, priorOpens: priorOpens, hasData: hasData)
        if !isSeen(id) { markSeen(id) }
        return show
    }
}

/// One step of a tour: a short sentence, an icon, and what it points at.
struct MiniAppTourStep: Equatable {
    enum Target: Equatable {
        /// The view carrying `.tourAnchor(app, step)`.
        case element
        /// The floating action of `MiniAppScaffold` (bottom center, it carries no anchor itself).
        case floatingAction
    }

    let symbol: String
    let text: String
    var target: Target = .element
}

/// The tour of each mini-app: two steps at most, tied to its main functions (« habits »: the Habits page, which is not a `MiniApp`).
enum MiniAppTourContent {
    static let maxSteps = 2
    static let habitsID = "habits"
    static var allIDs: [String] { MiniApp.allCases.map(\.rawValue) + [habitsID] }

    static func steps(_ id: String) -> [MiniAppTourStep] {
        switch id {
        case "nutrition":
            [MiniAppTourStep(symbol: "barcode.viewfinder", text: tr("Scanne un aliment ou photographie ton repas pour le noter.")),
             MiniAppTourStep(symbol: "flame.fill", text: tr("Tes calories et tes macros du jour avancent à chaque repas noté."))]
        case "fitness":
            [MiniAppTourStep(symbol: "plus", text: tr("Compose ton propre entraînement"), target: .floatingAction),
             MiniAppTourStep(symbol: "dumbbell.fill", text: tr("Ajoute des exercices depuis la bibliothèque."))]
        case "planning":
            [MiniAppTourStep(symbol: "calendar", text: tr("Ton emploi du temps de la semaine, en un coup d'œil.")),
             MiniAppTourStep(symbol: "checklist", text: tr("Ajoute une tâche ou un événement avec ces boutons."))]
        case "studies":
            [MiniAppTourStep(symbol: "graduationcap.fill", text: tr("Ajoute tes cours : devoirs, examens et notes s'y rangent.")),
             MiniAppTourStep(symbol: "doc.viewfinder", text: tr("Ou importe ton horaire depuis une photo ou un PDF."))]
        case "finances":
            [MiniAppTourStep(symbol: "plus", text: tr("Note une dépense ou un revenu en un geste."), target: .floatingAction),
             MiniAppTourStep(symbol: "creditcard.fill", text: tr("Ce qu'il te reste du mois se met à jour tout seul."))]
        case "business":
            [MiniAppTourStep(symbol: "plus", text: tr("Note ta première vente : le total du jour suffit.")),
             MiniAppTourStep(symbol: "chart.line.uptrend.xyaxis", text: tr("Ajoute aussi tes dépenses : bénéfice et objectif se calculent seuls."))]
        case "travel":
            [MiniAppTourStep(symbol: "airplane.departure", text: tr("Crée ton voyage : vols, hébergements et programme."), target: .floatingAction),
             MiniAppTourStep(symbol: "checklist", text: tr("Compte à rebours, budget et liste à ne pas oublier, au même endroit."))]
        case "car":
            [MiniAppTourStep(symbol: "fuelpump.fill", text: tr("Note un plein : consommation et autonomie suivent.")),
             MiniAppTourStep(symbol: "speedometer", text: tr("Ajoute aussi ton kilométrage pour suivre ta voiture."))]
        case "photos":
            [MiniAppTourStep(symbol: "photo.on.rectangle.angled", text: tr("Choisis des photos pour créer un widget.")),
             MiniAppTourStep(symbol: "quote.opening", text: tr("Ou écris une citation pour ton écran d'accueil."))]
        case "habits":
            [MiniAppTourStep(symbol: "plus.circle.fill", text: tr("Crée une habitude : lire, marcher, méditer…")),
             MiniAppTourStep(symbol: "checkmark.circle.fill", text: tr("Coche-la chaque jour pour faire grandir ta série."))]
        default:
            []
        }
    }

    static func colorHex(_ id: String) -> String {
        MiniApp(rawValue: id)?.colorHex ?? "7FA33A"
    }
}

/// The tour being shown, if any (one at a time). Not isolated to an actor: it is only touched from views.
@Observable
final class MiniAppTourController {
    static let shared = MiniAppTourController()

    private(set) var id: String?
    private(set) var step = 0
    @ObservationIgnored private let store: MiniAppTourStore

    init(store: MiniAppTourStore = MiniAppTourStore()) {
        self.store = store
    }

    /// Called when a mini-app opens, BEFORE `MiniAppUsage.record` (`priorOpens` is the count so far). Returns whether the
    /// tour starts. It is marked « seen » right here, so leaving the app mid-tour never brings it back.
    @discardableResult
    func begin(_ id: String, priorOpens: Int, hasData: Bool) -> Bool {
        #if DEBUG
        // Captures and UI tests never see a tour, except `-screenshotScreen tour-<app>` (shown whatever was seen).
        if ScreenshotMode.isActive {
            guard ScreenshotMode.screen == "tour-\(id)", !MiniAppTourContent.steps(id).isEmpty else { return false }
            self.id = id
            step = 0
            return true
        }
        #endif
        guard store.claim(id, priorOpens: priorOpens, hasData: hasData), !MiniAppTourContent.steps(id).isEmpty else { return false }
        self.id = id
        step = 0
        return true
    }

    /// Next step; after the last one the tour is over.
    func next() {
        guard let id else { return }
        if step + 1 < MiniAppTourContent.steps(id).count {
            step += 1
        } else {
            end(id)
        }
    }

    /// Closes the tour of `id` (« Passer », the last step, or the screen leaving).
    func end(_ id: String) {
        guard self.id == id else { return }
        self.id = nil
        step = 0
    }
}

// MARK: - Anchors

struct MiniAppTourAnchorID: Hashable {
    let key: String
    let step: Int
}

struct MiniAppTourAnchorKey: PreferenceKey {
    static var defaultValue: [MiniAppTourAnchorID: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [MiniAppTourAnchorID: Anchor<CGRect>], nextValue: () -> [MiniAppTourAnchorID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks the real view a tour step points at (`enabled: false` for the other rows of a list).
    func tourAnchor(_ key: String, _ step: Int, enabled: Bool = true) -> some View {
        anchorPreference(key: MiniAppTourAnchorKey.self, value: .bounds) { anchor in
            enabled ? [MiniAppTourAnchorID(key: key, step: step): anchor] : [:]
        }
    }

    func tourAnchor(_ app: MiniApp, _ step: Int, enabled: Bool = true) -> some View {
        tourAnchor(app.rawValue, step, enabled: enabled)
    }

    /// The discovery tour of a mini-app, posted once on its screen. `onlyStep`: this host shows that step only (Fitness:
    /// the first step on the page, the second in the session editor).
    func miniAppTour(_ app: MiniApp, onlyStep: Int? = nil) -> some View {
        modifier(MiniAppTourModifier(id: app.rawValue, onlyStep: onlyStep))
    }

    /// The same for a page that is not a `MiniApp` (Habits).
    func miniAppTour(id: String, onlyStep: Int? = nil) -> some View {
        modifier(MiniAppTourModifier(id: id, onlyStep: onlyStep))
    }
}

// MARK: - Overlay

private struct MiniAppTourModifier: ViewModifier {
    let id: String
    let onlyStep: Int?
    private let tour = MiniAppTourController.shared

    func body(content: Content) -> some View {
        let step = tour.step
        let running = tour.id == id && (onlyStep == nil || onlyStep == step)
        content
            // A touch anywhere (the real button too) goes to the next step, and still reaches what it touched: never a block.
            .simultaneousGesture(TapGesture().onEnded { if running { tour.next() } }, including: running ? .all : .subviews)
            .overlayPreferenceValue(MiniAppTourAnchorKey.self) { anchors in
                if running {
                    MiniAppTourLayer(id: id, step: step, anchor: anchors[MiniAppTourAnchorID(key: id, step: step)])
                }
            }
            .onDisappear { tour.end(id) }
    }
}

/// A light veil with a hole on the real element, a ring around it, and a short bubble (« Passer », « Suivant »).
private struct MiniAppTourLayer: View {
    let id: String
    let step: Int
    let anchor: Anchor<CGRect>?
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        let steps = MiniAppTourContent.steps(id)
        if step < steps.count {
            let item = steps[step]
            let palette = style.cristal
            let strong = palette.strongHex(MiniAppTourContent.colorHex(id))
            let hex = scheme == .dark ? strong.dark : strong.light
            GeometryReader { proxy in
                let hole = highlight(item, proxy)
                let lower = (hole?.midY ?? proxy.size.height) > proxy.size.height / 2
                ZStack {
                    Color.black.opacity(0.22)
                        .mask {
                            Rectangle()
                                .overlay {
                                    if let hole {
                                        RoundedRectangle(cornerRadius: radius(hole), style: .continuous)
                                            .frame(width: hole.width, height: hole.height)
                                            .position(x: hole.midX, y: hole.midY)
                                            .blendMode(.destinationOut)
                                    }
                                }
                                .compositingGroup()
                        }
                        .allowsHitTesting(false)
                    if let hole {
                        RoundedRectangle(cornerRadius: radius(hole), style: .continuous)
                            .strokeBorder(Color(hex: hex), lineWidth: 3)
                            .frame(width: hole.width, height: hole.height)
                            .scaleEffect(pulse ? 1.04 : 1)
                            .position(x: hole.midX, y: hole.midY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    bubble(item, hex: hex)
                        .padding(.horizontal, 20)
                        .padding(lower ? .bottom : .top, bubbleInset(hole, lower: lower, height: proxy.size.height))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: lower ? .bottom : .top)
                }
            }
            .animation(.snappy, value: step)
            .transition(.opacity)
            .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } } }
        }
    }

    /// Where the highlight goes: the anchored element when it is on screen, the floating action at the bottom, else nothing
    /// (the bubble then stands alone).
    private func highlight(_ item: MiniAppTourStep, _ proxy: GeometryProxy) -> CGRect? {
        switch item.target {
        case .floatingAction:
            let width = min(proxy.size.width - 40, 260)
            return CGRect(x: (proxy.size.width - width) / 2, y: proxy.size.height - 12 - 54, width: width, height: 54)
        case .element:
            guard let anchor else { return nil }
            let rect = proxy[anchor].insetBy(dx: -6, dy: -6)
            return CGRect(origin: .zero, size: proxy.size).intersects(rect) ? rect : nil
        }
    }

    private func radius(_ rect: CGRect) -> CGFloat { min(22, rect.height / 2) }

    private func bubbleInset(_ hole: CGRect?, lower: Bool, height: CGFloat) -> CGFloat {
        guard let hole else { return 96 }
        let inset = lower ? height - hole.minY + 12 : hole.maxY + 12
        return min(max(inset, 12), height * 0.6)
    }

    private func bubble(_ item: MiniAppTourStep, hex: String) -> some View {
        let count = MiniAppTourContent.steps(id).count
        let ink = Color.readableInk(on: hex)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ink)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: hex), in: Circle())
                    .accessibilityHidden(true)
                Text(item.text)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Text("\(step + 1)/\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Button {
                    withAnimation(.snappy) { MiniAppTourController.shared.end(id) }
                } label: {
                    Text(tr("Passer"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("tour-skip")
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { MiniAppTourController.shared.next() }
                } label: {
                    Text(step + 1 < count ? tr("Suivant") : tr("OK"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .background(Color(hex: hex), in: Capsule())
                }
                .accessibilityIdentifier("tour-next")
            }
        }
        .padding(14)
        .frame(maxWidth: 360, alignment: .leading)
        .cristalGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
    }
}
