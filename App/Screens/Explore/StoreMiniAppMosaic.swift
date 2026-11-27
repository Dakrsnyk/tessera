import SwiftUI
import WidgetKit

/// A mini-app in the Store (PDG, 2026-11-26): its widgets as a mosaic of three rows — small, medium, small, then
/// a medium over two smalls beside a large one — each a different kind, in the styles that suit the mini-app.
/// A tap opens the widget in the Studio, in that style.
struct MiniAppMosaic: View {
    let category: WidgetCategory
    let isPremiumUser: Bool
    let open: (WidgetDesign) -> Void
    @State private var width: CGFloat = 350

    /// One tile: the widget kind, its size and its style.
    struct Pick {
        let kind: WidgetKind
        let family: WidgetFamily
        let look: StyleLook
    }

    var body: some View {
        let gap: CGFloat = 10
        let small = max(40, (width - 3 * gap) / 4)
        let wide = 2 * small + gap
        let picks = Self.picks(for: category)
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
        let format = WidgetFormat.allCases.first { $0.family == pick.family } ?? .small
        let design = pick.look.applied(to: WidgetDesign(kind: pick.kind, format: format))
        let fitted = min(width, height * pick.family.aspectRatio)
        let locked = !isPremiumUser && (pick.look.isPremium || pick.kind.isPremium)
        return Button {
            Haptics.tap()
            open(design)
        } label: {
            WidgetPreview(design: design, family: pick.family, payload: SamplePayload.make(for: design), width: fitted)
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
        .accessibilityLabel(Text(verbatim: "\(pick.kind.title), \(pick.look.name)\(locked ? tr(", Premium") : "")"))
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

    /// The seven tiles: kinds of the mini-app turn by turn (each size only takes kinds that come in it), styles of its
    /// families turn by turn, a free original style first so that a free account always has something to take.
    static func picks(for category: WidgetCategory) -> [Pick] {
        let kinds = WidgetKind.kinds(in: category)
        let lists = families(for: category).map { StyleCatalog.looks(in: $0) }
        var looks: [StyleLook] = [StyleCatalog.look("dark"), StyleCatalog.look("light")].compactMap { $0 }
        for index in 0..<25 {
            for list in lists where index < list.count { looks.append(list[index]) }
        }
        let slots: [WidgetFamily] = [.systemSmall, .systemMedium, .systemSmall, .systemMedium, .systemSmall, .systemSmall, .systemLarge]
        var used: [WidgetKind] = []
        var picks: [Pick] = []
        for (index, family) in slots.enumerated() {
            let fitting = kinds.filter { $0.families.contains(family) }
            // Kinds not shown yet first, so that the mosaic shows as many different widgets as the mini-app has.
            let kind = fitting.first { !used.contains($0) } ?? fitting.first ?? kinds.first ?? .note
            let shownFamily = kind.families.contains(family) ? family : (kind.families.first ?? .systemSmall)
            used.append(kind)
            picks.append(Pick(kind: kind, family: shownFamily, look: looks[index % max(1, looks.count)]))
        }
        return picks
    }
}
