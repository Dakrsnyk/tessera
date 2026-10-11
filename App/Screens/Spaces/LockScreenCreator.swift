import SwiftUI
import WidgetKit

/// « Écran verrouillé » in Créer: every widget made for the Lock Screen, by universe, with the
/// interactive ones marked (a set validated, a habit checked… without unlocking), the workout shown
/// live during a session, and how to add them.
struct LockScreenCreator: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var onlyInteractive = false
    @State private var showsGuide = false

    /// Lock Screen widgets, grouped by the space whose data they show (general ones last).
    private var groups: [(title: String, items: [ShowcaseItem])] {
        let kinds = KindCatalog.all.map(\.kind).filter { $0.supportsLockScreen && (!onlyInteractive || $0.isInteractive) }
        var order: [Space?] = Space.allCases.map { Optional($0) }
        order.append(nil)
        return order.compactMap { space in
            let items = kinds.filter { $0.space == space }.map { kind in
                let family: WidgetFamily = kind.families.contains(.accessoryRectangular) ? .accessoryRectangular
                    : kind.families.contains(.accessoryCircular) ? .accessoryCircular : .accessoryInline
                return ShowcaseItem(
                    widget: SetupWidget(kind: kind, family: family, theme: .minimal, accent: space?.colorHex ?? "3366FF"),
                    title: kind.title,
                    subtitle: family.shortTitle
                )
            }
            return items.isEmpty ? nil : (space?.title ?? tr("Général"), items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro
            workoutLive
            Toggle(isOn: $onlyInteractive.animation(.snappy)) {
                HStack(spacing: 6) {
                    InteractiveBadge()
                    Text(tr("Seulement les widgets interactifs"))
                        .font(.subheadline)
                }
            }
            .tint(.accentColor)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("lock-interactive-filter")
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.title)
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .accessibilityAddTraits(.isHeader)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { pair in
                                Button {
                                    router.openEditor(pair.element.widget.makeDesign(), isNew: true)
                                } label: {
                                    LockShowcaseCard(item: pair.element, index: pair.offset, isPremiumUser: model.isPremium)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("lock-\(pair.element.widget.kind.rawValue)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showsGuide) { LockScreenGuide() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lock-creator")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("Sous l'heure, sans déverrouiller"), systemImage: "lock.fill")
                .font(.headline)
            Text("Choisis un widget, règle-le, puis ajoute-le depuis l'écran verrouillé de ton iPhone. Ceux marqués \(Image(systemName: "hand.tap.fill")) s'utilisent directement : valider une série, cocher une habitude, ajouter un verre…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showsGuide = true
            } label: {
                Label(tr("Comment l'ajouter"), systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("lock-guide")
        }
        .card()
        .padding(.horizontal, 20)
    }

    /// The workout in progress, as it appears on the Lock Screen and in the Dynamic Island.
    private var workoutLive: some View {
        let now = Date()
        let attributes = WorkoutActivityAttributes(routineName: tr("Haut du corps"))
        let state = WorkoutActivityAttributes.ContentState(
            exercise: tr("Développé couché"), setNumber: 3, sets: 4, load: tr("8 × 60 kg"),
            doneSets: 6, totalSets: 16, restStart: now.addingTimeInterval(-38), restEnd: now.addingTimeInterval(52)
        )
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(tr("Pendant une séance"))
                    .font(.headline)
                InteractiveBadge(showsText: true)
            }
            Text(tr("Dès ta première série validée, ta séance s'affiche sur l'écran verrouillé et dans la Dynamic Island : l'exercice, la série, le repos qui défile. « Série faite » et « Passer » marchent sans déverrouiller."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            WorkoutActivityView(attributes: attributes, state: state, isLive: false, now: now)
                .environment(\.colorScheme, .dark)
                .background(
                    LinearGradient(colors: [Color(hex: "1C2566"), Color(hex: "4A1628")], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .accessibilityIdentifier("lock-workout-preview")
        }
        .padding(.horizontal, 20)
    }
}

/// The steps to put a widget on the Lock Screen.
struct LockScreenGuide: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("hand.tap", tr("Sur l'écran verrouillé, touche et maintiens un espace vide, puis « Personnaliser ».")),
        ("lock.iphone", tr("Choisis « Écran verrouillé », puis touche la zone sous l'heure.")),
        ("plus.circle", tr("Dans la liste, choisis Ardane, puis le widget voulu.")),
        ("slider.horizontal.3", tr("Touche le widget ajouté pour choisir lequel de tes widgets Ardane il affiche.")),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.0)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Étape \(index + 1)"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(step.1)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Text(tr("Les widgets interactifs et la séance en direct demandent iOS 17. Si une action ne répond pas, déverrouille ton iPhone : iOS peut demander Face ID pour certaines actions."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(tr("Écran verrouillé"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
