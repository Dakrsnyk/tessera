#if DEBUG
import SwiftUI
import WidgetKit

/// App Store screenshots drawn by the app itself, so they show the real screens and widgets.
/// Each scene is laid out on a 440 × 956 pt canvas: a 6.9" iPhone captures it at 1320 × 2868 px.
/// Mode: `-screenshotScreen marketing-<01…10>` (the CI renders them with `[marketing]` in a commit message).
struct MarketingView: View {
    let scene: String

    private var number: Int { Int(scene.split(separator: "-").last ?? "1") ?? 1 }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / MK.canvas.width
            canvas
                .frame(width: MK.canvas.width, height: MK.canvas.height)
                .clipped()
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder private var canvas: some View {
        switch number {
        case 1: MarketingHero()
        case 2: MarketingWall()
        case 3: MarketingCustomize()
        case 4: MarketingNutrition()
        case 5: MarketingFitness()
        case 6: MarketingMoney()
        case 7: MarketingProductivity()
        case 8: MarketingSpaces()
        case 9: MarketingPremium()
        default: MarketingFinale()
        }
    }
}

// MARK: - Design tokens (from the app icon and the accent palette)

enum MK {
    static let canvas = CGSize(width: 440, height: 956)
    /// The phone's screen, in 6.9" iPhone points (the real screens are captured on that iPhone).
    static let screen = CGSize(width: 440, height: 956)

    /// Every widget is drawn at 9:41, like the status bars.
    static let now: Date = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date()

    /// Where the real app screen goes. The CI renders each scene twice, with this area white then
    /// black, and swaps in a full-resolution capture of the real screen (difference matting keeps the
    /// shadows and edges of anything drawn over it).
    static var placeholder: Color {
        UserDefaults.standard.string(forKey: "marketingScreen") == "black" ? .black : .white
    }

    static let jade = Color(hex: "2F8F7A")
    static let jadeLight = Color(hex: "6CCBB0")
    static let amber = Color(hex: "F2A33A")
    static let cream = Color(hex: "EFEDE6")
    static let ink = Color(hex: "16171A")
    static let paperTop = Color(hex: "F7F5F0")
    static let paperBottom = Color(hex: "ECE8DF")
    static let deepTop = Color(hex: "16302A")
    static let deepBottom = Color(hex: "0A1512")

    static func design(_ kind: WidgetKind, _ theme: ThemeID, _ accent: String = Palette.defaultAccent) -> WidgetDesign {
        WidgetDesign(kind: kind, themeID: theme, accentHex: accent)
    }

    static func payload(_ design: WidgetDesign) -> WidgetPayload {
        SamplePayload.make(for: design, now: now)
    }
}

// MARK: - Building blocks

struct MarketingBackground: View {
    var dark = false

    var body: some View {
        if dark {
            ZStack {
                LinearGradient(colors: [MK.deepTop, MK.deepBottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [MK.jade.opacity(0.35), .clear], center: .init(x: 0.5, y: 0.62), startRadius: 10, endRadius: 360)
            }
        } else {
            LinearGradient(colors: [MK.paperTop, MK.paperBottom], startPoint: .top, endPoint: .bottom)
        }
    }
}

struct MarketingTitle: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    var dark = false

    var body: some View {
        VStack(spacing: 12) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(dark ? MK.jadeLight : MK.jade)
            }
            Text(title)
                .font(.system(size: 40, weight: .bold))
                .tracking(-0.9)
                .multilineTextAlignment(.center)
                .foregroundStyle(dark ? MK.cream : MK.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(dark ? MK.cream.opacity(0.72) : MK.ink.opacity(0.58))
            }
        }
        .padding(.horizontal, 26)
        .frame(width: MK.canvas.width)
    }
}

struct MarketingBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            TesseraMark(size: 28)
                .environment(\.colorScheme, .dark)
            Text(tr("Tessera"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(MK.cream)
        }
    }
}

/// A plain iPhone: dark titanium frame, Dynamic Island, the screen drawn at iPhone 16 Pro size.
struct MarketingPhone<Screen: View>: View {
    var width: CGFloat
    var showsIsland: Bool
    let screen: Screen

    init(width: CGFloat = 340, showsIsland: Bool = true, @ViewBuilder screen: () -> Screen) {
        self.width = width
        self.showsIsland = showsIsland
        self.screen = screen()
    }

    var body: some View {
        let bezel = width * 0.034
        let screenWidth = width - bezel * 2
        let scale = screenWidth / MK.screen.width
        let screenHeight = MK.screen.height * scale
        let outerRadius = width * 0.165
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color(hex: "1A1B1F"))
                .overlay {
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Color(hex: "73767D"), Color(hex: "2B2D32"), Color(hex: "5A5D64")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2.2
                        )
                }
            screen
                .frame(width: MK.screen.width, height: MK.screen.height)
                .clipped()
                .scaleEffect(scale)
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius - bezel, style: .continuous))
                .padding(bezel)
            if showsIsland {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 126 * scale, height: 37 * scale)
                    .padding(.top, bezel + 11 * scale)
            }
        }
        .frame(width: width, height: screenHeight + bezel * 2)
        .shadow(color: .black.opacity(0.26), radius: 38, x: 0, y: 24)
    }
}

struct MarketingStatusBar: View {
    var light = false

    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 100)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 100)
        }
        .padding(.horizontal, 10)
        .padding(.top, 19)
        .frame(width: MK.screen.width, height: 54, alignment: .top)
        .foregroundStyle(light ? Color.white : Color.black)
    }
}

struct MarketingWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1F4A40"), Color(hex: "12302A")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [MK.jade.opacity(0.9), .clear], center: .init(x: 0.15, y: 0.1), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [MK.amber.opacity(0.45), .clear], center: .init(x: 0.95, y: 0.95), startRadius: 0, endRadius: 380)
        }
    }
}

struct MKWidget: Identifiable {
    let id = UUID()
    let design: WidgetDesign
    let family: WidgetFamily

    init(_ kind: WidgetKind, _ family: WidgetFamily = .systemSmall, _ theme: ThemeID, _ accent: String = Palette.defaultAccent) {
        self.design = MK.design(kind, theme, accent)
        self.family = family
    }
}

/// A Home Screen page filled with Tessera widgets, at their real size.
struct MarketingHomeScreen: View {
    let rows: [[MKWidget]]

    var body: some View {
        ZStack(alignment: .top) {
            MarketingWallpaper()
            VStack(spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.offset) { row in
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(row.element) { item in
                            VStack(spacing: 6) {
                                WidgetPreview(design: item.design, family: item.family, payload: MK.payload(item.design), width: WidgetMetrics.size(item.family).width, date: MK.now)
                                Text(tr("Tessera"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.92))
                                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text(tr("Rechercher"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(Color.white.opacity(0.18), in: Capsule())
            }
            .padding(.top, 70)
            .padding(.bottom, 48)
            MarketingStatusBar(light: true)
        }
        .frame(width: MK.screen.width, height: MK.screen.height)
    }
}

/// A real widget floating over the composition.
struct MarketingFloating: View {
    let item: MKWidget
    let width: CGFloat

    var body: some View {
        WidgetPreview(design: item.design, family: item.family, payload: MK.payload(item.design), width: width, date: MK.now)
            .shadow(color: .black.opacity(0.22), radius: 26, x: 0, y: 16)
    }
}

/// Title at the top, the phone below it bleeding off the bottom edge, optional floating widgets.
/// The phone's screen is the placeholder the real capture replaces.
struct MarketingFeature: View {
    let eyebrow: String
    let title: String
    var subtitle: String?
    var floating: [(item: MKWidget, width: CGFloat, center: CGPoint)] = []

    var body: some View {
        ZStack(alignment: .top) {
            MarketingBackground()
            MarketingTitle(eyebrow: eyebrow, title: title, subtitle: subtitle)
                .padding(.top, 72)
            MarketingPhone(showsIsland: false) { MK.placeholder }
                .padding(.top, 292)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
        .overlay {
            ForEach(Array(floating.enumerated()), id: \.offset) { pair in
                MarketingFloating(item: pair.element.item, width: pair.element.width)
                    .position(pair.element.center)
            }
        }
    }
}

// MARK: - Scenes

/// 01 — What Tessera is, at a glance.
struct MarketingHero: View {
    var body: some View {
        ZStack(alignment: .top) {
            MarketingBackground(dark: true)
            VStack(spacing: 20) {
                MarketingBrand()
                MarketingTitle(title: tr("Ton iPhone.\nTon tableau de bord."), dark: true)
            }
            .padding(.top, 70)
            MarketingPhone {
                MarketingHomeScreen(rows: [
                    [MKWidget(.now, .systemMedium, .light)],
                    [MKWidget(.caloriesLeft, .systemSmall, .aurora), MKWidget(.weather, .systemSmall, .light, "3366FF")],
                    [MKWidget(.habitStreak, .systemSmall, .retro, "F2A33A"), MKWidget(.budgetLeft, .systemSmall, .dark)],
                ])
            }
            .padding(.top, 292)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }
}

/// 02 — The library: many kinds, many styles.
struct MarketingWall: View {
    var body: some View {
        let small: CGFloat = 194
        let wide: CGFloat = 404
        ZStack(alignment: .top) {
            MarketingBackground()
            MarketingTitle(eyebrow: tr("103 widgets · 12 styles"), title: tr("Tout ce qui compte,\nd'un coup d'œil."))
                .padding(.top, 72)
            VStack(spacing: 16) {
                MarketingFloating(item: MKWidget(.weather, .systemMedium, .aurora), width: wide)
                HStack(spacing: 16) {
                    MarketingFloating(item: MKWidget(.caloriesLeft, .systemSmall, .glass, "8C6CFF"), width: small)
                    MarketingFloating(item: MKWidget(.nextClass, .systemSmall, .retro, "F2588F"), width: small)
                }
                HStack(spacing: 16) {
                    MarketingFloating(item: MKWidget(.tripCountdown, .systemSmall, .elegant), width: small)
                    MarketingFloating(item: MKWidget(.revenueGoal, .systemSmall, .dark, "F2A33A"), width: small)
                }
                MarketingFloating(item: MKWidget(.tasks, .systemMedium, .light), width: wide)
            }
            .padding(.top, 262)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }
}

/// 03 — Personalization, in the real editor.
struct MarketingCustomize: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Personnalisation"),
            title: tr("À ton image."),
            subtitle: tr("Styles, couleurs, photos, polices."),
            floating: [
                (MKWidget(.caloriesLeft, .systemSmall, .retro, "F2A33A"), 128, CGPoint(x: 71, y: 432)),
                (MKWidget(.caloriesLeft, .systemSmall, .dark), 128, CGPoint(x: 369, y: 432)),
            ]
        )
    }
}

/// 04 — Nutrition: food → calories → macros → what's left.
struct MarketingNutrition: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Nutrition"),
            title: tr("Nutrition,\nsimplifiée."),
            subtitle: tr("Scanne. Note. Suis tes macros."),
            floating: [
                (MKWidget(.caloriesLeft, .systemSmall, .aurora), 150, CGPoint(x: 348, y: 868)),
            ]
        )
    }
}

/// 05 — Training: session, rest, progress.
struct MarketingFitness: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Sport"),
            title: tr("Chaque série\ncompte."),
            subtitle: tr("Séance, repos et records."),
            floating: [
                (MKWidget(.nextSet, .systemSmall, .dark, "FF6B57"), 150, CGPoint(x: 348, y: 868)),
            ]
        )
    }
}

/// 06 — Money and business.
struct MarketingMoney: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Budget · Entreprise"),
            title: tr("Tes finances.\nTon entreprise."),
            subtitle: tr("Budget, ventes, bénéfice, MRR."),
            floating: [
                (MKWidget(.budgetLeft, .systemSmall, .light), 150, CGPoint(x: 336, y: 868)),
            ]
        )
    }
}

/// 07 — The day: priorities, tasks, deadlines, focus.
struct MarketingProductivity: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Productivité"),
            title: tr("Ta journée,\nbien en main."),
            subtitle: tr("Top 3, tâches, échéances, focus."),
            floating: [
                (MKWidget(.priorities, .systemSmall, .retro, "F2A33A"), 150, CGPoint(x: 348, y: 868)),
            ]
        )
    }
}

/// 08 — Every part of life, in one place.
struct MarketingSpaces: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Créer"),
            title: tr("Toute ta vie,\nau même endroit."),
            subtitle: tr("Nutrition, sport, études, voyage, auto…")
        )
    }
}

/// 09 — Premium: every widget, every style, the packs.
struct MarketingPremium: View {
    var body: some View {
        MarketingFeature(
            eyebrow: tr("Tessera Premium"),
            title: tr("Tout Tessera,\nsans limite."),
            subtitle: tr("Tous les widgets, styles et packs."),
            floating: [
                (MKWidget(.yearDots, .systemSmall, .glass, "8C6CFF"), 150, CGPoint(x: 92, y: 868)),
            ]
        )
    }
}

/// 10 — The promise, with the brand's mosaic: a jade column, a cream tile, an amber tile.
struct MarketingFinale: View {
    var body: some View {
        let tile: CGFloat = 184
        ZStack(alignment: .top) {
            MarketingBackground(dark: true)
            VStack(spacing: 20) {
                MarketingBrand()
                MarketingTitle(title: tr("L'essentiel,\nen un regard."), subtitle: tr("Écran d'accueil et écran verrouillé."), dark: true)
            }
            .padding(.top, 70)
            VStack(spacing: 34) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        MarketingFloating(item: MKWidget(.caloriesLeft, .systemSmall, .colorful), width: tile)
                        MarketingFloating(item: MKWidget(.habitStreak, .systemSmall, .colorful), width: tile)
                    }
                    VStack(spacing: 16) {
                        MarketingFloating(item: MKWidget(.weather, .systemSmall, .retro, "3366FF"), width: tile)
                        MarketingFloating(item: MKWidget(.budgetLeft, .systemSmall, .colorful, "F2A33A"), width: tile)
                    }
                }
                HStack(spacing: 18) {
                    ForEach(Array(lockWidgets.enumerated()), id: \.offset) { pair in
                        WidgetPreview(design: pair.element, family: .accessoryCircular, payload: MK.payload(pair.element), width: 76, date: MK.now)
                    }
                }
            }
            .padding(.top, 318)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }

    private var lockWidgets: [WidgetDesign] {
        [MK.design(.caloriesLeft, .minimal), MK.design(.weather, .minimal), MK.design(.habitStreak, .minimal), MK.design(.tripCountdown, .minimal)]
    }
}
#endif
