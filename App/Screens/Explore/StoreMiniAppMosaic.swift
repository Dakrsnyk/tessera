import SwiftUI
import WidgetKit

/// A mini-app in the Store (PDG, 2026-11-26): its widgets as mosaics of three rows — small, medium, small, then a
/// medium over two smalls beside a large one — that scroll sideways, seven mosaics (about 50 widgets). Each tile is a
/// different kind, in the styles that suit the mini-app; the large ones are combined widgets (several widgets of the
/// mini-app in one), except in Planning and Habits where a single large widget may stand alone.
struct MiniAppMosaicRow: View {
    let category: WidgetCategory
    let isPremiumUser: Bool
    let open: (WidgetDesign) -> Void

    static let mosaics = 7

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(0..<Self.mosaics, id: \.self) { block in
                    MiniAppMosaic(category: category, block: block, isPremiumUser: isPremiumUser, open: open)
                        // The next mosaic peeks at the edge: the row is seen to scroll.
                        .containerRelativeFrame(.horizontal) { width, _ in width - 56 }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }
}

struct MiniAppMosaic: View {
    let category: WidgetCategory
    let block: Int
    let isPremiumUser: Bool
    let open: (WidgetDesign) -> Void
    @State private var width: CGFloat = 320

    /// One tile: the design to draw (a widget, or several combined) and its size.
    struct Pick {
        let design: WidgetDesign
        let family: WidgetFamily
        let name: String
    }

    var body: some View {
        let gap: CGFloat = 10
        let small = max(40, (width - 3 * gap) / 4)
        let wide = 2 * small + gap
        let picks = Self.picks(for: category, block: block)
        VStack(spacing: gap) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// The widget drawn as large as its box allows, centered in it.
    private func tile(_ pick: Pick, width: CGFloat, height: CGFloat) -> some View {
        let fitted = min(width, height * pick.family.aspectRatio)
        let locked = !isPremiumUser && pick.design.usesPremiumFeatures
        return Button {
            Haptics.tap()
            open(pick.design)
        } label: {
            WidgetPreview(design: pick.design, family: pick.family, payload: SamplePayload.make(for: pick.design), width: fitted)
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

    /// The seven tiles of one mosaic: kinds of the mini-app turn by turn (each size only takes kinds that come in it,
    /// none twice in a mosaic), a new style for every tile of the row, a combined widget for the large one.
    static func picks(for category: WidgetCategory, block: Int) -> [Pick] {
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
            if family == .systemLarge, let combo = largeCombo(category: category, kinds: kinds, block: block) {
                picks.append(Pick(design: look.applied(to: combo.makeDesign()), family: .systemLarge, name: combo.name))
                continue
            }
            let chosen = kind(for: family, turn: index) ?? kind(for: .systemSmall, turn: index) ?? kinds.first ?? .note
            used.append(chosen)
            let shown = chosen.families.contains(family) ? family : (chosen.families.first ?? .systemSmall)
            let format = WidgetFormat.allCases.first { $0.family == shown } ?? .small
            picks.append(Pick(design: look.applied(to: WidgetDesign(kind: chosen, format: format)), family: shown, name: chosen.title))
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
