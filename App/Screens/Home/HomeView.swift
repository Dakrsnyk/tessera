import SwiftUI
import WidgetKit

/// Home: the greeting, the person's widgets as they sit on a Home Screen, the categories to create
/// from, and a taste of the Store.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var storeShelf: StoreShelf = .new

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    myWidgets
                    createStrip
                    storeSample
                    if !model.isPremium {
                        PremiumBanner { router.isPaywallPresented = true }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(.screenFill)
            .screenshotScroll()
            .navigationTitle("Tessera")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        router.openExplore(search: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(Text("Rechercher un widget"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.isProfilePresented = true
                    } label: {
                        ProfileAvatar(name: model.settings.profileName.trimmed, size: 32)
                    }
                    .accessibilityLabel(Text("Profil et réglages"))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.longDay(Date()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(greetingWithName)
                .font(.title2.weight(.semibold))
        }
    }

    private var greetingWithName: String {
        let first = model.settings.profileName.trimmed.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? greeting : "\(greeting) \(first)"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }

    // MARK: Mes widgets

    private static let wallpaper = LinearGradient(
        colors: [Color(hex: "22324F"), Color(hex: "4A3F5E"), Color(hex: "92596A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    @ViewBuilder private var myWidgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mes widgets", actionTitle: model.designs.isEmpty ? nil : "Tout voir") {
                router.tab = .mine
            }
            if model.designs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Crée ton premier widget")
                        .font(.headline)
                    Text("Choisis une catégorie, personnalise ton widget, puis ajoute-le à ton écran d'accueil.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        router.tab = .spaces
                    } label: {
                        Label("Créer un widget", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
                .card()
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(homeRows.enumerated()), id: \.offset) { pair in
                        HStack(spacing: 14) {
                            ForEach(pair.element) { design in
                                Button {
                                    router.openEditor(design, isNew: false)
                                } label: {
                                    WidgetPreview(design: design, family: design.displayFormat.family, payload: model.payload(for: design))
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                            // A small widget alone on its row keeps its size, like on the Home Screen.
                            if pair.element.count == 1, pair.element[0].displayFormat == .small {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Self.wallpaper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text("Tes widgets comme sur ton écran d'accueil · touche-en un pour le modifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// The latest widgets laid out like a Home Screen: two small ones side by side, a medium one across,
    /// a large one over two rows; three rows at most.
    private var homeRows: [[WidgetDesign]] {
        var rows: [[WidgetDesign]] = []
        var used = 0
        var waitingSmall: Int?
        for design in model.recentDesigns {
            switch design.displayFormat {
            case .small:
                if let index = waitingSmall {
                    rows[index].append(design)
                    waitingSmall = nil
                } else if used < 3 {
                    rows.append([design])
                    waitingSmall = rows.count - 1
                    used += 1
                }
            case .medium:
                if used < 3 {
                    rows.append([design])
                    used += 1
                }
            case .large:
                if used + 2 <= 3 {
                    rows.append([design])
                    used += 2
                }
            }
            if used >= 3 && waitingSmall == nil { break }
        }
        return rows
    }

    // MARK: Créer

    /// Every category, on two rows that scroll together.
    private static let createRows: [[Space]] = [
        [.nutrition, .fitness, .budget, .travel, .productivity, .business],
        [.habits, .student, .investing, .car, .markets, .life],
    ]

    private var createStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Créer", actionTitle: "Tout voir") { router.tab = .spaces }
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Self.createRows, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row) { space in
                                CreatePill(space: space) {
                                    // Opens that category's widget creator in the Créer tab.
                                    router.requestedCreator = space
                                    router.tab = .spaces
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    // MARK: Store

    private enum StoreShelf: String, CaseIterable, Identifiable {
        case new = "Nouveautés"
        case popular = "Populaires"
        case free = "Gratuits"
        var id: String { rawValue }
    }

    /// A few Store widgets of the chosen shelf, one per kind.
    private var shelfTemplates: [WidgetTemplate] {
        let source: [WidgetTemplate]
        switch storeShelf {
        case .new: source = TemplateCatalog.all.filter { $0.kind.isNew }
        case .popular: source = TemplateCatalog.featured
        case .free: source = TemplateCatalog.all.filter { !$0.isPremium }
        }
        var seen = Set<WidgetKind>()
        let picked = source.filter { seen.insert($0.kind).inserted }
        return Array((picked.isEmpty ? TemplateCatalog.featured : picked).prefix(10))
    }

    private var storeSample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                router.openExplore()
            } label: {
                HStack(spacing: 4) {
                    Text("Store")
                        .font(.title3.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(Text("Ouvre le Store"))
            HStack(spacing: 8) {
                ForEach(StoreShelf.allCases) { shelf in
                    let isOn = storeShelf == shelf
                    Button {
                        withAnimation(.snappy) { storeShelf = shelf }
                    } label: {
                        Text(shelf.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(isOn ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(Color.primary))
                            .background(isOn ? AnyShapeStyle(Color.primary) : AnyShapeStyle(AppFill.cardFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(shelfTemplates) { template in
                        Button {
                            router.openEditor(template.makeDesign(), isNew: true)
                        } label: {
                            TemplateCard(template: template, width: 150, isPremiumUser: model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            .id(storeShelf)
            .transition(.opacity)
        }
    }
}

/// A category to create from: its colour and symbol, and its name.
private struct CreatePill: View {
    let space: Space
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: space.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: space.colorHex), in: Circle())
                Text(space.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(.cardFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Créer un widget \(space.title)"))
    }
}

struct PremiumBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.premiumInk)
                    .frame(width: 48, height: 48)
                    .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tessera Premium")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Plus de 70 widgets en plus, 12 styles, fonds photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
