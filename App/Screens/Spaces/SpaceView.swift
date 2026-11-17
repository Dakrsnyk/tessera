import SwiftUI
import WidgetKit

/// A space: its widgets at the top, then everything needed to feed them.
struct SpaceView: View {
    let space: Space
    /// Opened from the widget editor or the space creator: only the data, so going back returns to the
    /// widget being made exactly as it was (the widget strip would open another editor over it).
    var isEmbedded = false
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        List {
            // The strip lives in the header, which isn't clipped like a list row,
            // so the widgets scroll all the way to the screen edges.
            if !isEmbedded {
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Widgets de l'espace"))
                        widgetStrip
                            .padding(.horizontal, -20)
                            .foregroundStyle(Color.primary)
                            .textCase(nil)
                    }
                } footer: {
                    Text(tr("Touche un widget pour le personnaliser, puis ajoute-le à ton écran d'accueil ou verrouillé."))
                }
            }
            content
                .listRowBackground(Rectangle().fill(.cardFill))
        }
        .styledList()
        .hostsSpaceSheets()
        .navigationTitle(space.title)
        .navigationBarTitleDisplayMode(.large)
        .screenshotScroll()
    }

    private var widgetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(SpaceCatalog.kinds(in: space)) { kind in
                    let design = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
                    // A widget with no small size is shown medium, as the editor opens it.
                    let hasSmall = kind.families.contains(.systemSmall)
                    let width: CGFloat = hasSmall ? 128 : 270
                    Button {
                        router.openEditor(design, isNew: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            WidgetPreview(design: design, family: hasSmall ? .systemSmall : .systemMedium, payload: model.payload(for: design), width: width)
                            HStack(spacing: 4) {
                                Text(kind.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                if kind.isPremium && !model.isPremium {
                                    PremiumBadge(compact: true)
                                }
                            }
                            .frame(width: width, alignment: .leading)
                        }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 20)
        }
        // Widgets scroll to the screen edge instead of being cut at the row's inset.
        .scrollClipDisabled()
    }

    @ViewBuilder private var content: some View {
        switch space {
        case .productivity: ProductivitySpaceSections()
        case .habits: HabitsSpaceSections()
        case .nutrition: NutritionSpaceSections()
        case .fitness: FitnessSpaceSections()
        case .budget: BudgetSpaceSections()
        case .investing: PortfolioSpaceSections()
        case .business: BusinessSpaceSections()
        case .markets: MarketsSpaceSections()
        case .student: StudentSpaceSections()
        case .travel: TravelSpaceSections()
        case .car: CarSpaceSections()
        case .life: LifeSpaceSections()
        }
    }
}
