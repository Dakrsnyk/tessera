#if DEBUG
import SwiftUI
import WidgetKit

/// App Store screenshots drawn by the app itself, so they show the real screens and widgets.
/// Each scene is laid out on a 440 × 956 pt canvas: a 6.9" iPhone captures it at 1320 × 2868 px.
/// Mode: `-screenshotScreen marketing-<scene>`; the scenes are listed in scripts/marketing_scenes.txt
/// (the CI renders them with `[marketing]` in a commit message, scripts/marketing_compose.py assembles them).
/// `pano-<name>-1` and `pano-<name>-2` are the two halves of one scene twice as wide.
struct MarketingView: View {
    let scene: String

    /// « marketing-pano-sport-2 » → « pano-sport-2 ».
    private var name: String { String(scene.dropFirst("marketing-".count)) }

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
        if name.hasPrefix("pano-"), let half = Int(name.suffix(1)) {
            panorama(String(name.dropLast(2)))
                .frame(width: MK.wide.width, height: MK.wide.height)
                .offset(x: half == 2 ? -MK.canvas.width : 0)
                .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
                .clipped()
        } else {
            single(name)
        }
    }

    @ViewBuilder private func panorama(_ base: String) -> some View {
        switch base {
        case "pano-nutrition": MarketingPanoNutrition()
        case "pano-style": MarketingPanoStyle()
        default: MarketingPanoSport()
        }
    }

    @ViewBuilder private func single(_ name: String) -> some View {
        switch name {
        case "lock": MarketingLock()
        case "nutrition": MarketingNutrition()
        case "fitness": MarketingFitness()
        case "daily": MarketingDaily()
        case "store": MarketingStore()
        case "planning": MarketingPlanning()
        case "finances": MarketingFinances()
        case "wall": MarketingWall()
        case "apps": MarketingApps()
        case "privacy": MarketingPrivacy()
        case "finale": MarketingFinale()
        case "hero-lock": MarketingHero(showsLockScreen: true)
        default: MarketingHero()
        }
    }
}

// MARK: - Design tokens (from the app icon: cream, charcoal, red and orange tiles)

enum MK {
    static let canvas = CGSize(width: 440, height: 956)
    /// A panorama: two screenshots side by side.
    static let wide = CGSize(width: 880, height: 956)
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

    static let red = Color(hex: "E5383B")
    static let orange = Color(hex: "FF8A3D")
    static let jade = Color(hex: "2F8F7A")
    static let jadeLight = Color(hex: "6CCBB0")
    static let amber = Color(hex: "F2A33A")
    static let cream = Color(hex: "F7F4EF")
    static let ink = Color(hex: "1A1516")
    static let paperTop = Color(hex: "FAF8F4")
    static let paperBottom = Color(hex: "EEE8DF")
    static let deepTop = Color(hex: "2A2223")
    static let deepBottom = Color(hex: "0E0C0C")

    /// The accent of the app style the screens are captured with.
    static var appAccent: Color { AppStyle.style(SharedStore.shared.settings.appStyle).accent }

    static func design(_ kind: WidgetKind, _ theme: ThemeID, _ accent: String = Palette.defaultAccent) -> WidgetDesign {
        WidgetDesign(kind: kind, themeID: theme, accentHex: accent)
    }

    static func payload(_ design: WidgetDesign) -> WidgetPayload {
        SamplePayload.make(for: design, now: now)
    }

    /// The demo session in progress (the one the Fitness screen shows), 1:24 into a two-minute rest.
    static var workout: (attributes: WorkoutActivityAttributes, state: WorkoutActivityAttributes.ContentState) {
        if var live = WorkoutLiveActivity.content(for: SharedStore.shared.state(FitnessState.self), now: now) {
            live.1.restStart = now.addingTimeInterval(-36)
            live.1.restEnd = now.addingTimeInterval(84)
            live.1.restPaused = nil
            return (attributes: live.0, state: live.1)
        }
        return (
            WorkoutActivityAttributes(routineName: tr("Haut du corps")),
            WorkoutActivityAttributes.ContentState(
                exercise: tr("Développé couché"),
                setNumber: 3,
                sets: 4,
                load: tr("\(8) × \(60) kg"),
                doneSets: 2,
                totalSets: 14,
                restStart: now.addingTimeInterval(-36),
                restEnd: now.addingTimeInterval(84),
                restPaused: nil
            )
        )
    }
}

// MARK: - Building blocks

/// A soft ground with two glows. Their centers are relative: the same view fills a screenshot or a panorama.
struct MarketingGround: View {
    var dark = false
    var glow: Color = MK.orange
    var glowCenter = UnitPoint(x: 0.5, y: 0.62)
    var second: Color = MK.red
    var secondCenter = UnitPoint(x: 0.95, y: 0.05)

    var body: some View {
        ZStack {
            if dark {
                LinearGradient(colors: [MK.deepTop, MK.deepBottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [glow.opacity(0.34), .clear], center: glowCenter, startRadius: 10, endRadius: 430)
                RadialGradient(colors: [second.opacity(0.22), .clear], center: secondCenter, startRadius: 0, endRadius: 360)
            } else {
                LinearGradient(colors: [MK.paperTop, MK.paperBottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [glow.opacity(0.17), .clear], center: glowCenter, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [second.opacity(0.10), .clear], center: secondCenter, startRadius: 0, endRadius: 360)
            }
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
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(dark ? MK.orange : MK.red)
            }
            Text(title)
                .font(.system(size: 40, weight: .bold))
                .tracking(-0.9)
                .lineSpacing(-2)
                .multilineTextAlignment(.center)
                .foregroundStyle(dark ? MK.cream : MK.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 18, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(dark ? MK.cream.opacity(0.7) : MK.ink.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 26)
        .frame(width: MK.canvas.width)
    }
}

struct MarketingBrand: View {
    var dark = true

    var body: some View {
        HStack(spacing: 10) {
            TesseraMark(size: 30)
            Text(tr("Tessera"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(dark ? MK.cream : MK.ink)
        }
    }
}

/// A plain iPhone: dark titanium frame, Dynamic Island, the screen drawn at iPhone 16 Pro Max size.
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
        let bezel = width * 0.03
        let screenWidth = width - bezel * 2
        let scale = screenWidth / MK.screen.width
        let screenHeight = MK.screen.height * scale
        let outerRadius = width * 0.16
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color(hex: "16171A"))
                .overlay {
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Color(hex: "8A8D93"), Color(hex: "2B2D32"), Color(hex: "6A6D73")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
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
        .shadow(color: .black.opacity(0.28), radius: 40, x: 0, y: 26)
    }
}

struct MarketingStatusBar: View {
    var light = false
    /// The Lock Screen shows the big clock instead of the time in the status bar.
    var showsTime = true

    var body: some View {
        HStack {
            Text(showsTime ? "9:41" : "")
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

/// The Home Screen wallpaper: the icon's charcoal, warmed by its red and orange.
struct MarketingWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "3A2A2B"), Color(hex: "151112")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [MK.red.opacity(0.75), .clear], center: .init(x: 0.12, y: 0.06), startRadius: 0, endRadius: 430)
            RadialGradient(colors: [MK.orange.opacity(0.55), .clear], center: .init(x: 0.95, y: 0.92), startRadius: 0, endRadius: 400)
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

/// The Lock Screen as iOS draws it: the date, the clock, widgets under it, the workout's Live Activity.
struct MarketingLockScreen: View {
    var circular: [WidgetDesign]
    var rectangular: WidgetDesign?
    var showsWorkout = true

    var body: some View {
        ZStack(alignment: .top) {
            MarketingWallpaper()
            VStack(spacing: 0) {
                Text(MK.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Fmt.locale)))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.top, 68)
                Text("9:41")
                    .font(.system(size: 112, weight: .bold))
                    .tracking(-2)
                    .foregroundStyle(Color.white.opacity(0.96))
                    .padding(.top, -12)
                HStack(spacing: 14) {
                    if let rectangular {
                        lockWidget(rectangular, .accessoryRectangular)
                    }
                    ForEach(Array(circular.enumerated()), id: \.offset) { pair in
                        lockWidget(pair.element, .accessoryCircular)
                    }
                }
                .padding(.top, -4)
                Spacer(minLength: 0)
                if showsWorkout {
                    MarketingLiveActivity()
                        .padding(.horizontal, 12)
                }
                HStack {
                    MarketingLockButton(symbol: "flashlight.off.fill")
                    Spacer()
                    MarketingLockButton(symbol: "camera.fill")
                }
                .padding(.horizontal, 44)
                .padding(.top, 28)
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 148, height: 5)
                    .padding(.top, 20)
                    .padding(.bottom, 9)
            }
            MarketingStatusBar(light: true, showsTime: false)
        }
        .frame(width: MK.screen.width, height: MK.screen.height)
    }

    private func lockWidget(_ design: WidgetDesign, _ family: WidgetFamily) -> some View {
        WidgetPreview(design: design, family: family, payload: MK.payload(design), width: WidgetMetrics.size(family).width, date: MK.now)
    }
}

struct MarketingLockButton: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.3), in: Circle())
    }
}

/// The workout's Live Activity, drawn by the same view as the real one.
struct MarketingLiveActivity: View {
    var body: some View {
        let workout = MK.workout
        WorkoutActivityView(attributes: workout.attributes, state: workout.state, isLive: false, now: MK.now)
            .background(WorkoutActivityView.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}

/// The Dynamic Island while resting: the session's symbol and the countdown.
struct MarketingIsland: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(MK.appAccent)
            Spacer()
            Text("1:24")
                .monospacedDigit()
                .foregroundStyle(Color.white)
        }
        .font(.system(size: 24, weight: .semibold))
        .padding(.horizontal, 26)
        .frame(width: 300, height: 66)
        .background(Color.black, in: Capsule())
        .environment(\.colorScheme, .dark)
    }
}

/// Lock Screen widgets enlarged, on a piece of wallpaper so their white ink shows on a light ground.
struct MarketingLockChip: View {
    let designs: [(WidgetDesign, WidgetFamily)]
    var scale: CGFloat = 1.45

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(designs.enumerated()), id: \.offset) { pair in
                let family = pair.element.1
                WidgetPreview(design: pair.element.0, family: family, payload: MK.payload(pair.element.0), width: WidgetMetrics.size(family).width * scale, date: MK.now)
            }
        }
        .padding(18)
        .background {
            MarketingWallpaper()
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .shadow(color: .black.opacity(0.24), radius: 26, x: 0, y: 16)
    }
}

/// A real widget floating over the composition.
struct MarketingFloating: View {
    let item: MKWidget
    let width: CGFloat

    var body: some View {
        WidgetPreview(design: item.design, family: item.family, payload: MK.payload(item.design), width: width, date: MK.now)
            .shadow(color: .black.opacity(0.2), radius: 26, x: 0, y: 16)
    }
}

/// Title at the top, the phone below it bleeding off the bottom edge, then whatever floats over it.
/// The phone's screen is the placeholder the real capture replaces.
struct MarketingFeature<Extra: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String?
    var glow: Color = MK.orange
    let extra: Extra

    init(eyebrow: String, title: String, subtitle: String? = nil, glow: Color = MK.orange, @ViewBuilder extra: () -> Extra) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.glow = glow
        self.extra = extra()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround(glow: glow, glowCenter: UnitPoint(x: 0.5, y: 0.7))
            MarketingTitle(eyebrow: eyebrow, title: title, subtitle: subtitle)
                .padding(.top, 70)
            MarketingPhone(width: 340) { MK.placeholder }
                .padding(.leading, 50)
                .padding(.top, 280)
            extra
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

/// A wide ring around the seam of a panorama: it joins the two screenshots without cutting any text.
struct MarketingArc: View {
    let colors: [Color]
    var diameter: CGFloat = 700
    var opacity: Double = 0.22

    var body: some View {
        Circle()
            .trim(from: 0.06, to: 0.78)
            .stroke(AngularGradient(colors: colors + [colors[0]], center: .center), style: StrokeStyle(lineWidth: 26, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
            .opacity(opacity)
    }
}

/// Places a view by its top-leading corner on the canvas.
private extension View {
    func at(_ x: CGFloat, _ y: CGFloat) -> some View {
        padding(.leading, x).padding(.top, y)
    }
}

// MARK: - Panoramas (two screenshots that make one picture)

/// The workout on the Lock Screen, then its Live Activity and the Dynamic Island up close.
struct MarketingPanoSport: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround(dark: true, glow: MK.red, glowCenter: UnitPoint(x: 0.5, y: 0.64), second: MK.orange, secondCenter: UnitPoint(x: 0.98, y: 0.04))
            MarketingArc(colors: [MK.red, MK.orange, MK.amber])
                .at(90, 420)
            HStack(alignment: .top, spacing: 0) {
                MarketingTitle(eyebrow: tr("Écran verrouillé"), title: tr("Ta séance,\nen direct."), subtitle: tr("Sans déverrouiller ton iPhone."), dark: true)
                MarketingTitle(eyebrow: tr("Activité en direct"), title: tr("Repos, séries,\ncharges."), subtitle: tr("Touche « Série faite », le repos démarre."), dark: true)
            }
            .padding(.top, 70)
            MarketingPhone(width: 330) {
                MarketingLockScreen(circular: [MK.design(.caloriesLeft, .minimal), MK.design(.proteinLeft, .minimal), MK.design(.hydration, .minimal)])
            }
            .at(55, 290)
            MarketingLiveActivity()
                .frame(width: 404)
                .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 18)
                .at(458, 312)
            MarketingIsland()
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                .at(510, 548)
            MarketingLockChip(designs: [(MK.design(.nextSet, .minimal), .accessoryRectangular), (MK.design(.caloriesLeft, .minimal), .accessoryCircular)], scale: 1.3)
                .at(480, 690)
        }
        .frame(width: MK.wide.width, height: MK.wide.height, alignment: .topLeading)
    }
}

/// The real Nutrition screen, then its widgets: on the Home Screen and on the Lock Screen.
struct MarketingPanoNutrition: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround(glow: Color(hex: "F08A24"), glowCenter: UnitPoint(x: 0.5, y: 0.6), second: MK.red, secondCenter: UnitPoint(x: 0.98, y: 0.04))
            MarketingArc(colors: [Color(hex: "F08A24"), MK.amber, MK.red], opacity: 0.16)
                .at(90, 420)
            HStack(alignment: .top, spacing: 0) {
                MarketingTitle(eyebrow: tr("Nutrition"), title: tr("Tes calories,\nen un regard."), subtitle: tr("Scanne un code-barres, c'est noté."))
                MarketingTitle(eyebrow: tr("Widgets"), title: tr("Sur ton écran\nd'accueil."), subtitle: tr("Et sur l'écran verrouillé."))
            }
            .padding(.top, 70)
            MarketingPhone(width: 330) { MK.placeholder }
                .at(55, 290)
            MarketingFloating(item: MKWidget(.mealsToday, .systemMedium, .light), width: 392)
                .at(464, 286)
            MarketingFloating(item: MKWidget(.proteinLeft, .systemSmall, .light), width: 186)
                .at(464, 494)
            MarketingFloating(item: MKWidget(.macros, .systemSmall, .light), width: 186)
                .at(670, 494)
            MarketingLockChip(designs: [(MK.design(.caloriesLeft, .minimal), .accessoryRectangular), (MK.design(.proteinLeft, .minimal), .accessoryCircular)], scale: 1.3)
                .at(480, 712)
        }
        .frame(width: MK.wide.width, height: MK.wide.height, alignment: .topLeading)
    }
}

/// The real Studio, then one widget in six styles.
struct MarketingPanoStyle: View {
    private let styles: [(ThemeID, String)] = [
        (.liquidGlass, "8C6CFF"), (.retro, "F2A33A"),
        (.neon, "FF4F9A"), (.paper, "2F8F7A"),
        (.luxury, "C9A45C"), (.pastel, "5B8DEF"),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround(glow: Color(hex: "8C6CFF"), glowCenter: UnitPoint(x: 0.5, y: 0.6), second: MK.orange, secondCenter: UnitPoint(x: 0.98, y: 0.04))
            MarketingArc(colors: [Color(hex: "8C6CFF"), Color(hex: "FF4F9A"), MK.orange], opacity: 0.16)
                .at(90, 420)
            HStack(alignment: .top, spacing: 0) {
                MarketingTitle(eyebrow: tr("Personnalisation"), title: tr("À ton image."), subtitle: tr("Styles, couleurs, photos, polices."))
                MarketingTitle(eyebrow: tr("Studio"), title: tr("Un widget,\nmille styles."))
            }
            .padding(.top, 70)
            MarketingPhone(width: 330) { MK.placeholder }
                .at(55, 290)
            VStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 18) {
                        ForEach(0..<2, id: \.self) { column in
                            let style = styles[row * 2 + column]
                            MarketingFloating(item: MKWidget(.caloriesLeft, .systemSmall, style.0, style.1), width: 180)
                        }
                    }
                }
            }
            .at(471, 262)
        }
        .frame(width: MK.wide.width, height: MK.wide.height, alignment: .topLeading)
    }
}

// MARK: - Scenes

/// What Tessera is, at a glance: the Home Screen, or the Lock Screen with the workout in progress.
struct MarketingHero: View {
    var showsLockScreen = false

    var body: some View {
        ZStack(alignment: .top) {
            MarketingGround(dark: true, glow: MK.red, glowCenter: UnitPoint(x: 0.5, y: 0.66), second: MK.orange, secondCenter: UnitPoint(x: 0.95, y: 0.05))
            VStack(spacing: 20) {
                MarketingBrand()
                MarketingTitle(title: tr("Ton iPhone,\nà ton image."), subtitle: tr("Widgets et mini-apps pour toute ta journée."), dark: true)
            }
            .padding(.top, 66)
            MarketingPhone(width: 340) {
                if showsLockScreen {
                    MarketingLockScreen(circular: [MK.design(.proteinLeft, .minimal), MK.design(.hydration, .minimal)], rectangular: MK.design(.caloriesLeft, .minimal))
                } else {
                    MarketingHomeScreen(rows: [
                        [MKWidget(.mealsToday, .systemMedium, .light)],
                        [MKWidget(.caloriesLeft, .systemSmall, .aurora), MKWidget(.nextSet, .systemSmall, .dark, "FF6B57")],
                        [MKWidget(.habitStreak, .systemSmall, .retro, "F2A33A"), MKWidget(.weather, .systemSmall, .light, "3366FF")],
                    ])
                }
            }
            .padding(.top, 300)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }
}

/// The Lock Screen: nutrition widgets under the clock, the workout in progress.
struct MarketingLock: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround(glow: MK.red, glowCenter: UnitPoint(x: 0.5, y: 0.66))
            MarketingTitle(eyebrow: tr("Écran verrouillé"), title: tr("L'essentiel,\nd'un regard."), subtitle: tr("Calories, protéines, eau, séance."))
                .padding(.top, 70)
            MarketingPhone(width: 340) {
                MarketingLockScreen(circular: [MK.design(.proteinLeft, .minimal), MK.design(.hydration, .minimal)], rectangular: MK.design(.caloriesLeft, .minimal))
            }
            .at(50, 280)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

/// Nutrition: food → calories → macros → what's left.
struct MarketingNutrition: View {
    var body: some View {
        MarketingFeature(eyebrow: tr("Nutrition"), title: tr("Nutrition,\nsimplifiée."), subtitle: tr("Scanne, note, suis tes macros."), glow: Color(hex: "F08A24")) {
            MarketingFloating(item: MKWidget(.caloriesLeft, .systemSmall, .aurora), width: 164)
                .at(262, 760)
        }
    }
}

/// Training: the real session screen and its Live Activity.
struct MarketingFitness: View {
    var body: some View {
        MarketingFeature(eyebrow: tr("Sport"), title: tr("Chaque série\ncompte."), subtitle: tr("Séances, repos et records."), glow: MK.red) {
            MarketingLiveActivity()
                .frame(width: 404)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 18)
                .at(18, 740)
        }
    }
}

/// Mon Quotidien: the whole day on one screen.
struct MarketingDaily: View {
    var body: some View {
        MarketingFeature(eyebrow: tr("Mon Quotidien"), title: tr("Ta journée,\nen un écran."), subtitle: tr("Repas, séance, eau, pas, météo.")) {
            EmptyView()
        }
    }
}

struct MarketingStore: View {
    var body: some View {
        MarketingFeature(eyebrow: tr("Store"), title: tr("Des styles\npour tout."), subtitle: tr("Packs, collections, fonds d'écran."), glow: Color(hex: "8C6CFF")) {
            EmptyView()
        }
    }
}

struct MarketingPlanning: View {
    var body: some View {
        MarketingFeature(eyebrow: tr("Planning"), title: tr("Ta semaine,\nbien en main."), subtitle: tr("Horaire, tâches, habitudes, focus."), glow: Color(hex: "3366FF")) {
            MarketingFloating(item: MKWidget(.priorities, .systemSmall, .dark, "5B8DEF"), width: 186)
                .at(240, 738)
        }
    }
}

struct MarketingFinances: View {
    var body: some View {
        MarketingFeature(eyebrow: tr("Finances"), title: tr("Ton budget,\nsous contrôle."), subtitle: tr("Dépenses, revenus, catégories."), glow: MK.jade) {
            MarketingFloating(item: MKWidget(.budgetLeft, .systemSmall, .dark), width: 164)
                .at(262, 760)
        }
    }
}

/// The library: many kinds, many styles.
struct MarketingWall: View {
    var body: some View {
        let small: CGFloat = 194
        let wide: CGFloat = 404
        ZStack(alignment: .top) {
            MarketingGround(glow: MK.orange, glowCenter: UnitPoint(x: 0.5, y: 0.6))
            MarketingTitle(eyebrow: tr("Plus de 100 widgets"), title: tr("Tout ce qui\ncompte."))
                .padding(.top, 70)
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
            .padding(.top, 236)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }
}

/// Every mini-app, with what it does.
struct MarketingApps: View {
    private let apps: [(MiniApp, String)] = [
        (.nutrition, tr("Calories, macros, code-barres")),
        (.fitness, tr("Séances, repos, records")),
        (.planning, tr("Horaire, tâches, habitudes")),
        (.finances, tr("Budget, dépenses, revenus")),
        (.business, tr("Ventes, objectifs, MRR")),
        (.travel, tr("Programme, budget, valise")),
        (.car, tr("Plein, entretien, échéances")),
        (.weather, tr("Prévisions, pluie, soleil")),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            MarketingGround(glow: MK.orange, glowCenter: UnitPoint(x: 0.5, y: 0.65))
            MarketingTitle(eyebrow: tr("Mini-apps"), title: tr("Toute ta vie,\nau même endroit."), subtitle: tr("Elles nourrissent tes widgets."))
                .padding(.top, 70)
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { column in
                            card(apps[row * 2 + column])
                        }
                    }
                }
            }
            .padding(.top, 290)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }

    private func card(_ item: (MiniApp, String)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: item.0.symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 46, height: 46)
                .background(item.0.color.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.0.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MK.ink)
                Text(item.1)
                    .font(.system(size: 13.5))
                    .foregroundStyle(MK.ink.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 186, height: 146, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 8)
    }
}

/// Nothing leaves the iPhone: no account, no ads, no tracking.
struct MarketingPrivacy: View {
    var body: some View {
        ZStack(alignment: .top) {
            MarketingGround(dark: true, glow: MK.jade, glowCenter: UnitPoint(x: 0.5, y: 0.5), second: MK.orange, secondCenter: UnitPoint(x: 0.95, y: 0.05))
            MarketingTitle(eyebrow: tr("Confidentialité"), title: tr("Tes données\nrestent à toi."), dark: true)
                .padding(.top, 70)
            VStack(spacing: 46) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 104, weight: .regular))
                    .foregroundStyle(MK.jadeLight, MK.jade.opacity(0.5))
                    .frame(width: 220, height: 220)
                    .background(MK.jade.opacity(0.16), in: Circle())
                    .overlay(Circle().strokeBorder(MK.jadeLight.opacity(0.25), lineWidth: 1))
                VStack(spacing: 12) {
                    row("iphone", tr("Tout reste sur ton iPhone"))
                    row("person.crop.circle.badge.xmark", tr("Aucun compte à créer"))
                    row("eye.slash.fill", tr("Aucune pub, aucun suivi"))
                }
            }
            .padding(.top, 318)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .top)
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MK.jadeLight)
                .frame(width: 30)
            Text(text)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(MK.cream)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(width: 372, height: 66)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

/// The promise, with the brand's mosaic of widgets and Lock Screen widgets.
struct MarketingFinale: View {
    var body: some View {
        let tile: CGFloat = 184
        ZStack(alignment: .top) {
            MarketingGround(dark: true, glow: MK.orange, glowCenter: UnitPoint(x: 0.5, y: 0.6), second: MK.red, secondCenter: UnitPoint(x: 0.05, y: 0.02))
            VStack(spacing: 20) {
                MarketingBrand()
                MarketingTitle(title: tr("Ta vie,\nen widgets."), subtitle: tr("Écran d'accueil et écran verrouillé."), dark: true)
            }
            .padding(.top, 66)
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
