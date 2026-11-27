import SwiftUI
import WidgetKit

/// A mini-app in the Store (PDG, 2026-11-26): its widgets as mosaics of three rows — small, medium, small, then a
/// medium over two smalls beside a large one — seven mosaics (about 50 widgets) that scroll sideways one per swipe.
/// Each tile is a different kind, in the styles that suit the mini-app; the large ones are combined widgets (several
/// widgets of the mini-app in one), except in Planning and Habits where a single large widget may stand alone.
/// The widgets are drawn once into still pictures (`MosaicPictures`): live widgets by the hundred made the Store lag.
struct MiniAppMosaicRow: View {
    let category: WidgetCategory
    let isPremiumUser: Bool
    let open: (WidgetDesign) -> Void
    @State private var rowWidth: CGFloat = 375

    static let mosaics = 7

    var body: some View {
        // Each mosaic as wide as the screen less its margins and the edge of the next one (it shows the row scrolls).
        let width = max(260, rowWidth - 56)
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(0..<Self.mosaics, id: \.self) { block in
                    MiniAppMosaic(category: category, block: block, width: width, isPremiumUser: isPremiumUser, open: open)
                        .frame(width: width)
                }
            }
            .scrollTargetLayout()
        }
        // One swipe, one mosaic, in one movement.
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
    }
}

struct MiniAppMosaic: View {
    let category: WidgetCategory
    let block: Int
    let width: CGFloat
    let isPremiumUser: Bool
    let open: (WidgetDesign) -> Void

    /// One tile: the design to draw (a widget, or several combined) and its size.
    struct Pick {
        let id: String
        let design: WidgetDesign
        let family: WidgetFamily
        let name: String
        let isPremium: Bool
    }

    var body: some View {
        let gap: CGFloat = 10
        let small = floor((width - 3 * gap) / 4)
        let wide = 2 * small + gap
        let picks = Self.picks(for: category, block: block)
        VStack(alignment: .leading, spacing: gap) {
            HStack(spacing: gap) {
                tile(picks[0], width: small, height: small)
                tile(picks[1], width: wide, height: small)
                tile(picks[2], width: small, height: small)
            }
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: gap) {
                    tile(picks[3], width: wide, height: small)
                    HStack(spacing: gap) {
                        tile(picks[4], width: small, height: small)
                        tile(picks[5], width: small, height: small)
                    }
                }
                tile(picks[6], width: wide, height: wide)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    /// The widget's picture, as large as its box allows, centered in it.
    private func tile(_ pick: Pick, width: CGFloat, height: CGFloat) -> some View {
        let fitted = floor(min(width, height * pick.family.aspectRatio))
        let locked = !isPremiumUser && pick.isPremium
        return Button {
            Haptics.tap()
            open(pick.design)
        } label: {
            MosaicPicture(pick: pick, width: fitted)
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.premiumInk)
                            .padding(4)
                            .background(Color.premiumFill, in: Circle())
                            .padding(6)
                    }
                }
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(verbatim: pick.name + (locked ? tr(", Premium") : "")))
    }

    // MARK: - What each mini-app shows

    /// The style families that suit the mini-app, in order of fit.
    static func families(for category: WidgetCategory) -> [String] {
        switch category {
        case .nutrition: ["nature", "rose", "aura", "minimal"]
        case .fitness: ["sport", "gaming", "brutal", "neon"]
        case .wellbeing: ["aura", "nature", "girl", "minimal"]
        case .finance: ["prime", "luxe", "verre", "minimal"]
        case .investing, .markets: ["chrome", "cyberpunk", "prime", "pixel"]
        case .business: ["prime", "luxe", "chrome", "minimal"]
        case .productivity: ["minimal", "verre", "prime", "vintage"]
        case .student: ["illustration", "vintage", "y2k", "pixel"]
        case .time: ["minimal", "chrome", "aura", "retro"]
        case .travel: ["vintage", "retro", "nature", "verre"]
        default: ["verre", "aura", "minimal", "chrome"]
        }
    }

    /// The styles of the mini-app, its families turn by turn, the two free original styles first.
    static func looks(for category: WidgetCategory) -> [StyleLook] {
        let lists = families(for: category).map { StyleCatalog.looks(in: $0) }
        var looks: [StyleLook] = [StyleCatalog.look("dark"), StyleCatalog.look("light")].compactMap { $0 }
        for index in 0..<25 {
            for list in lists where index < list.count { looks.append(list[index]) }
        }
        return looks
    }

    /// Worked out once per mosaic: the body asks again at every frame of a scroll.
    @MainActor private static var cache: [String: [Pick]] = [:]

    @MainActor static func picks(for category: WidgetCategory, block: Int) -> [Pick] {
        let key = "\(category.rawValue)-\(block)"
        if let known = cache[key] { return known }
        let picks = makePicks(for: category, block: block)
        cache[key] = picks
        return picks
    }

    /// The seven tiles of one mosaic: kinds of the mini-app turn by turn (each size only takes kinds that come in it,
    /// none twice in a mosaic), a new style for every tile of the row, a combined widget for the large one.
    static func makePicks(for category: WidgetCategory, block: Int) -> [Pick] {
        let kinds = WidgetKind.kinds(in: category)
        let looks = looks(for: category)
        let slots: [WidgetFamily] = [.systemSmall, .systemMedium, .systemSmall, .systemMedium, .systemSmall, .systemSmall, .systemLarge]
        var used: [WidgetKind] = []
        var picks: [Pick] = []
        func kind(for family: WidgetFamily, turn: Int) -> WidgetKind? {
            let fitting = kinds.filter { $0.families.contains(family) }
            guard !fitting.isEmpty else { return nil }
            let start = (block * 3 + turn) % fitting.count
            let order = Array(fitting[start...] + fitting[..<start])
            return order.first { !used.contains($0) } ?? order.first
        }
        for (index, family) in slots.enumerated() {
            let look = looks[(block * slots.count + index) % max(1, looks.count)]
            let id = "\(category.rawValue)-\(block)-\(index)"
            if family == .systemLarge, let combo = largeCombo(category: category, kinds: kinds, block: block) {
                let design = look.applied(to: combo.makeDesign())
                picks.append(Pick(id: id, design: design, family: .systemLarge, name: combo.name, isPremium: design.usesPremiumFeatures))
                continue
            }
            let chosen = kind(for: family, turn: index) ?? kind(for: .systemSmall, turn: index) ?? kinds.first ?? .note
            used.append(chosen)
            let shown = chosen.families.contains(family) ? family : (chosen.families.first ?? .systemSmall)
            let format = WidgetFormat.allCases.first { $0.family == shown } ?? .small
            let design = look.applied(to: WidgetDesign(kind: chosen, format: format))
            picks.append(Pick(id: id, design: design, family: shown, name: chosen.title,
                              isPremium: design.usesPremiumFeatures || chosen.isPremium))
        }
        return picks
    }

    /// The large tile as several widgets of the mini-app in one: four small ones, or a medium and two small ones, turn
    /// by turn. Nil when the large tile shows a single widget: in Planning and Habits every other mosaic (their large
    /// widgets, the week's timetable and the habits grid, stand alone), or when the mini-app has too few widgets.
    static func largeCombo(category: WidgetCategory, kinds: [WidgetKind], block: Int) -> StoreCombo? {
        if [.student, .wellbeing].contains(category), block % 2 == 0,
           kinds.contains(where: { $0.families.contains(.systemLarge) }) {
            return nil
        }
        let smalls = kinds.filter { $0.families.contains(.systemSmall) }
        let mediums = kinds.filter { $0.families.contains(.systemMedium) }
        func rotated<T>(_ list: [T], by step: Int) -> [T] {
            guard !list.isEmpty else { return list }
            let start = step % list.count
            return Array(list[start...] + list[..<start])
        }
        var parts: [StoreCombo.Part] = []
        if block % 2 == 1, let medium = rotated(mediums, by: block).first {
            let others = rotated(smalls, by: block + 1).filter { $0 != medium }.prefix(2)
            if others.count == 2 {
                parts = [StoreCombo.Part(kind: medium, size: .medium)] + others.map { StoreCombo.Part(kind: $0, size: .small) }
            }
        }
        if parts.isEmpty {
            let four = Array(rotated(smalls, by: block).prefix(4))
            guard four.count == 4 else { return nil }
            parts = four.map { StoreCombo.Part(kind: $0, size: .small) }
        }
        let combo = StoreCombo(id: "mosaic-\(category.rawValue)-\(block)", name: category.title, tagline: "",
                               parts: parts, theme: .dark, accent: "F2A33A")
        return combo.format == .large ? combo : nil
    }
}

/// A widget of the mosaic as a still picture, drawn once and kept: scrolling moves pictures, not live widgets.
struct MosaicPicture: View {
    let pick: MiniAppMosaic.Pick
    let width: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var scale
    @State private var picture: UIImage?

    private var key: String { "\(pick.id)-\(Int(width))-\(scheme == .dark ? "d" : "l")" }

    var body: some View {
        let height = floor(width / pick.family.aspectRatio)
        Group {
            if let picture {
                Image(uiImage: picture)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius * width / WidgetMetrics.size(pick.family).width, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
        }
        .frame(width: width, height: height)
        .task(id: key) {
            picture = MosaicPictures.picture(for: pick, width: width, scheme: scheme, scale: scale, key: key)
        }
    }
}

@MainActor
enum MosaicPictures {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()

    static func picture(for pick: MiniAppMosaic.Pick, width: CGFloat, scheme: ColorScheme, scale: CGFloat, key: String) -> UIImage? {
        if let known = cache.object(forKey: key as NSString) { return known }
        let view = WidgetPreview(design: pick.design, family: pick.family, payload: SamplePayload.make(for: pick.design), width: width)
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.uiImage else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

/// What a touch on a widget of the Store offers (PDG, 2026-11-26): keep it as it is, in this style, straight into
/// « Mes widgets », or open it in the Studio to change it first. Either way it can be changed later from « Mes widgets ».
struct StoreWidgetChoice: View {
    let design: WidgetDesign
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    private var family: WidgetFamily { design.format?.family ?? .systemSmall }

    var body: some View {
        VStack(spacing: 18) {
            WidgetPreview(design: design, family: family, payload: SamplePayload.make(for: design),
                          width: family == .systemSmall ? 170 : 330)
                .frame(maxHeight: 340)
                .padding(.top, 26)
            VStack(spacing: 4) {
                Text(design.name.isEmpty ? design.kind.title : design.name)
                    .font(.title3.weight(.bold))
                Text(tr("Tu pourras le modifier plus tard dans « Mes widgets »."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                Button(action: saveAsIs) {
                    Label(tr("Enregistrer ce style"), systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("store-choice-save")
                Button {
                    dismiss()
                    router.openEditor(design, isNew: true)
                } label: {
                    Label(tr("Personnaliser"), systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("store-choice-customize")
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Straight into « Mes widgets », as the Studio would save it: Premium settings and the free limit ask first.
    private func saveAsIs() {
        if design.usesPremiumFeatures && !model.isPremium {
            dismiss()
            router.showPaywall(.designs([design]))
            return
        }
        let fitting = model.fitting([design])
        guard !fitting.isEmpty else {
            dismiss()
            router.showPaywall(.designLimit)
            return
        }
        _ = model.install(designs: fitting)
        Haptics.success()
        dismiss()
    }
}
