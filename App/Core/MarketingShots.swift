#if DEBUG
import SwiftUI
import WidgetKit

/// App Store screenshots drawn by the app itself, so they show the real screens and widgets.
/// Each scene is laid out on a 440 × 956 pt canvas: a 6.9" iPhone captures it at 1320 × 2868 px.
/// Mode: `-screenshotScreen marketing-<scene>`; the scenes are listed in scripts/marketing_scenes.txt
/// (the CI renders them with `[marketing]` in a commit message, scripts/marketing_compose.py assembles them).
/// `pano-<name>-1` and `pano-<name>-2` are the two halves of one scene twice as wide.
/// The look: a white-to-grey ground, big dark titles, whole phones (some tilted),
/// real screens and widgets popping out of them.
struct MarketingView: View {
    let scene: String

    /// « marketing-pano-setups-2 » → « pano-setups-2 ».
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
        case "pano-lock": MarketingPanoLock()
        default: MarketingPanoSetups()
        }
    }

    @ViewBuilder private func single(_ name: String) -> some View {
        switch name {
        case "lock": MarketingLock()
        case "nutrition": MarketingNutrition()
        case "fitness": MarketingFitness()
        case "daily": MarketingDaily()
        case "studio": MarketingStudio()
        case "lockscreens": MarketingLockScreens()
        case "store": MarketingStore()
        case "planning": MarketingPlanning()
        case "finances": MarketingFinances()
        case "apps": MarketingApps()
        case "wall": MarketingWall()
        case "privacy": MarketingPrivacy()
        default: MarketingHero()
        }
    }
}

// MARK: - Design tokens (the icon: a red band, an orange tile, a charcoal tile on cream)

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
    static let deepRed = Color(hex: "B3202B")
    static let ink = Color(hex: "1A1516")
    /// The shadows under phones and cards on the light ground.
    static let shadow = Color(hex: "1F2128")
    static let cream = Color(hex: "F7F4EF")

    /// The wallpaper of the Lock Screens drawn by the scenes (one of the Store's wallpapers).
    static let lockWallpaper: SetupWallpaper = .nebula

    static func design(_ kind: WidgetKind, _ theme: ThemeID, _ accent: String = Palette.defaultAccent) -> WidgetDesign {
        WidgetDesign(kind: kind, themeID: theme, accentHex: accent)
    }

    static func payload(_ design: WidgetDesign) -> WidgetPayload {
        SamplePayload.make(for: design, now: now)
    }

    static func setup(_ id: String) -> HomeSetup {
        HomeSetupCatalog.setup(id) ?? HomeSetupCatalog.all[0]
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

    /// Today's demo meals: what was eaten and the targets.
    static var nutrition: (totals: NutritionTotals, goals: NutritionGoals) {
        let state = SharedStore.shared.state(NutritionState.self)
        return (NutritionMath.totals(state, on: now), state.goals)
    }
}

// MARK: - Building blocks

/// The ground of every screenshot: white at the top fading into a soft grey. Relative stops, so the
/// same view fills one screenshot or a panorama.
struct MarketingGround: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.white, Color(hex: "F1F1F3"), Color(hex: "D9DADF")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.9), .clear], center: UnitPoint(x: 0.15, y: 0.02), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color(hex: "C4C6CD").opacity(0.45), .clear], center: UnitPoint(x: 0.95, y: 1), startRadius: 0, endRadius: 520)
        }
    }
}

/// The big title at the top left, as on the best App Store pages.
struct MarketingHeadline: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    var showsBrand = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsBrand {
                HStack(spacing: 9) {
                    TesseraMark(size: 28)
                    Text(tr("Tessera"))
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(MK.ink)
            } else if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(MK.red)
            }
            Text(title)
                .font(.system(size: 44, weight: .bold))
                .tracking(-1.2)
                .lineSpacing(-4)
                .foregroundStyle(MK.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MK.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: MK.canvas.width - 56, alignment: .leading)
        .padding(.leading, 28)
        .frame(width: MK.canvas.width, alignment: .leading)
    }
}

/// A plain iPhone: dark titanium frame, Dynamic Island, the screen drawn at iPhone 16 Pro Max size.
struct MarketingPhone<Screen: View>: View {
    var width: CGFloat
    var showsIsland: Bool
    let screen: Screen

    init(width: CGFloat = 320, showsIsland: Bool = true, @ViewBuilder screen: () -> Screen) {
        self.width = width
        self.showsIsland = showsIsland
        self.screen = screen()
    }

    /// The phone's height for a width (screen proportions plus the frame).
    static func height(_ width: CGFloat) -> CGFloat {
        let bezel = width * 0.03
        return (width - bezel * 2) / MK.screen.width * MK.screen.height + bezel * 2
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
                // Only the body casts a shadow: nothing drawn on the screen darkens the real capture.
                .shadow(color: MK.shadow.opacity(0.25), radius: 36, x: 0, y: 24)
                .overlay {
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Color(hex: "9A9DA3"), Color(hex: "2B2D32"), Color(hex: "6A6D73")], startPoint: .topLeading, endPoint: .bottomTrailing),
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
    }
}

/// A screen drawn at the size of the Store's setups (402 × 874), brought to the phone's screen.
struct MarketingSetupScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: SetupScreen.size.width, height: SetupScreen.size.height)
            .scaleEffect(MK.screen.width / SetupScreen.size.width, anchor: .topLeading)
            .frame(width: MK.screen.width, height: MK.screen.height, alignment: .topLeading)
            .clipped()
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

/// The Lock Screen with a Store wallpaper: the date, the clock, the macros and calories under it,
/// and the workout's Live Activity.
struct MarketingLockScreen: View {
    var circular: [WidgetDesign] = [MK.design(.caloriesLeft, .minimal), MK.design(.proteinLeft, .minimal)]
    var rectangular: WidgetDesign? = MK.design(.macros, .minimal)
    var showsWorkout = true

    var body: some View {
        ZStack(alignment: .top) {
            MarketingSetupScreen { SetupWallpaperView(wallpaper: MK.lockWallpaper) }
            LinearGradient(colors: [Color.black.opacity(0.3), .clear], startPoint: .top, endPoint: .center)
            VStack(spacing: 0) {
                Text(SetupLockScreen.capitalized(Fmt.format(MK.now, template: "EEEEdMMMM")))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.top, 68)
                Text("9:41")
                    .font(.system(size: 116, weight: .bold))
                    .tracking(-2)
                    .foregroundStyle(Color.white.opacity(0.96))
                    .padding(.top, -12)
                HStack(spacing: 12) {
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
                .padding(.top, 26)
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 148, height: 5)
                    .padding(.top, 20)
                    .padding(.bottom, 9)
            }
            MarketingStatusBar(light: true, showsTime: false)
        }
        .frame(width: MK.screen.width, height: MK.screen.height)
        .environment(\.colorScheme, .dark)
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
            .background(Color.white.opacity(0.16), in: Circle())
    }
}

/// The workout's Live Activity, drawn by the same view as the real one, on the night gradient of
/// the Lock Screen preview in the app.
struct MarketingLiveActivity: View {
    var body: some View {
        let workout = MK.workout
        WorkoutActivityView(attributes: workout.attributes, state: workout.state, isLive: false, now: MK.now)
            .background(
                LinearGradient(colors: [Color(hex: "1C2566"), Color(hex: "4A1628")], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .environment(\.colorScheme, .dark)
    }
}

/// The Dynamic Island while resting: the session's symbol and the countdown.
struct MarketingIsland: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(AppStyle.style(SharedStore.shared.settings.appStyle).accent)
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

/// Lock Screen widgets enlarged, on a piece of the Lock Screen wallpaper.
struct MarketingLockChip: View {
    let designs: [(WidgetDesign, WidgetFamily)]
    var scale: CGFloat = 1.45

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(designs.enumerated()), id: \.offset) { pair in
                let family = pair.element.1
                WidgetPreview(design: pair.element.0, family: family, payload: MK.payload(pair.element.0), width: WidgetMetrics.size(family).width * scale, date: MK.now)
            }
        }
        .padding(18)
        .background {
            Color.black
                .overlay {
                    SetupWallpaperView(wallpaper: MK.lockWallpaper)
                        .scaleEffect(1.6)
                        .overlay(Color.black.opacity(0.18))
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .environment(\.colorScheme, .dark)
        .shadow(color: MK.shadow.opacity(0.22), radius: 26, x: 0, y: 16)
    }
}

/// A real widget floating over the composition.
struct MarketingFloating: View {
    let kind: WidgetKind
    var family: WidgetFamily = .systemSmall
    var theme: ThemeID = .light
    var accent: String = Palette.defaultAccent
    let width: CGFloat

    var body: some View {
        let design = MK.design(kind, theme, accent)
        WidgetPreview(design: design, family: family, payload: MK.payload(design), width: width, date: MK.now)
            .shadow(color: MK.shadow.opacity(0.19), radius: 24, x: 0, y: 14)
    }
}

/// A round white bubble with one figure of the day, as the nutrition apps show them.
struct MarketingBubble: View {
    let value: String
    let label: String
    let colorHex: String
    var progress: Double = 0.6
    var size: CGFloat = 104

    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            Circle()
                .stroke(Color(hex: colorHex).opacity(0.16), lineWidth: 6)
                .padding(8)
            Circle()
                .trim(from: 0, to: min(1, max(0.04, progress)))
                .stroke(Color(hex: colorHex), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)
            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(MK.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: size * 0.115, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, size * 0.18)
        }
        .frame(width: size, height: size)
        .shadow(color: MK.shadow.opacity(0.17), radius: 18, x: 0, y: 10)
    }
}

/// A white pill: a symbol and a short label.
struct MarketingPill: View {
    let symbol: String
    let text: String
    var colorHex = "2F8F7A"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: colorHex))
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MK.ink)
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(Color.white, in: Capsule())
        .shadow(color: MK.shadow.opacity(0.17), radius: 18, x: 0, y: 10)
    }
}

/// A wide soft ring around the seam of a panorama: it joins the two screenshots without cutting any text.
struct MarketingArc: View {
    var diameter: CGFloat = 760

    var body: some View {
        Circle()
            .trim(from: 0.04, to: 0.8)
            .stroke(Color.black.opacity(0.045), style: StrokeStyle(lineWidth: 30, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
    }
}

/// Places a view by its top-leading corner on the canvas.
private extension View {
    func at(_ x: CGFloat, _ y: CGFloat) -> some View {
        padding(.leading, x).padding(.top, y)
    }
}

/// The headline at the top, a phone with the real screen (whole, from the status bar to the tab bar)
/// below it, then whatever pops out of the phone.
struct MarketingShowcase<Extra: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String?
    var phoneWidth: CGFloat = 316
    var phoneX: CGFloat?
    let extra: Extra

    init(eyebrow: String, title: String, subtitle: String? = nil, phoneWidth: CGFloat = 316, phoneX: CGFloat? = nil, @ViewBuilder extra: () -> Extra) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.phoneWidth = phoneWidth
        self.phoneX = phoneX
        self.extra = extra()
    }

    var body: some View {
        let height = MarketingPhone<Color>.height(phoneWidth)
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(eyebrow: eyebrow, title: title, subtitle: subtitle)
                .padding(.top, 58)
            MarketingPhone(width: phoneWidth) { MK.placeholder }
                .at(phoneX ?? (MK.canvas.width - phoneWidth) / 2, MK.canvas.height - height - 22)
            extra
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

// MARK: - Panoramas (two screenshots that make one picture)

/// Five ready-made Home Screens from the Store, fanned out across the two screenshots.
struct MarketingPanoSetups: View {
    private let setups = ["aurore", "creme", "jade", "minuit", "ocean"]
    private let tilts: [Double] = [-6, -3, 0, 3, 6]
    private let drops: [CGFloat] = [44, 14, 0, 14, 44]

    var body: some View {
        let width: CGFloat = 220
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingArc()
                .at(60, 380)
            HStack(alignment: .top, spacing: 0) {
                MarketingHeadline(eyebrow: tr("Écrans d'accueil"), title: tr("Ton écran\nd'accueil,\ndéjà stylé."))
                MarketingHeadline(eyebrow: tr("Store"), title: tr("\(HomeSetupCatalog.all.count) écrans prêts\nà installer."), subtitle: tr("Fond, widgets et icônes assortis, en un geste."))
            }
            .padding(.top, 58)
            // The middle one in front, then outwards.
            ForEach([0, 4, 1, 3, 2], id: \.self) { index in
                MarketingPhone(width: width) {
                    MarketingSetupScreen { SetupHomeScreen(setup: MK.setup(setups[index])) }
                }
                .rotationEffect(.degrees(tilts[index]))
                .at(136 + CGFloat(index) * 152 - width / 2, 372 + drops[index])
            }
        }
        .frame(width: MK.wide.width, height: MK.wide.height, alignment: .topLeading)
    }
}

/// The Lock Screen with the workout and the macros, then its pieces up close.
struct MarketingPanoLock: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingArc()
                .at(60, 400)
            HStack(alignment: .top, spacing: 0) {
                MarketingHeadline(eyebrow: tr("Écran verrouillé"), title: tr("Tout, sans\ndéverrouiller."), subtitle: tr("Séance, repos, calories et macros."))
                MarketingHeadline(eyebrow: tr("Activité en direct"), title: tr("Série faite ?\nUn geste."), subtitle: tr("Le repos démarre tout seul."))
            }
            .padding(.top, 58)
            MarketingPhone(width: 316) { MarketingLockScreen() }
                .at(62, 956 - MarketingPhone<Color>.height(316) - 22)
            MarketingLiveActivity()
                .frame(width: 400)
                .rotationEffect(.degrees(-3))
                .shadow(color: MK.shadow.opacity(0.28), radius: 30, x: 0, y: 18)
                .at(460, 300)
            MarketingIsland()
                .shadow(color: MK.shadow.opacity(0.25), radius: 20, x: 0, y: 10)
                .at(510, 528)
            MarketingLockChip(designs: [(MK.design(.macros, .minimal), .accessoryRectangular), (MK.design(.caloriesLeft, .minimal), .accessoryCircular)], scale: 1.3)
                .rotationEffect(.degrees(2.5))
                .at(474, 660)
        }
        .frame(width: MK.wide.width, height: MK.wide.height, alignment: .topLeading)
    }
}

// MARK: - Scenes

/// What Tessera is: a Home Screen made with it, and the Lock Screen during a workout.
struct MarketingHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(title: tr("Ta vie entière\nen widgets."), subtitle: tr("Nutrition, sport, planning, budget."), showsBrand: true)
                .padding(.top, 58)
            MarketingPhone(width: 250) {
                MarketingSetupScreen { SetupHomeScreen(setup: MK.setup("jade")) }
            }
            .rotationEffect(.degrees(-6))
            .at(32, 352)
            MarketingPhone(width: 268) { MarketingLockScreen() }
                .rotationEffect(.degrees(5))
                .at(140, 330)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

/// The Lock Screen alone, its widgets popping out.
struct MarketingLock: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(eyebrow: tr("Écran verrouillé"), title: tr("Tout, sans\ndéverrouiller."), subtitle: tr("Séance, repos, calories et macros."))
                .padding(.top, 58)
            MarketingPhone(width: 316) { MarketingLockScreen() }
                .at(62, 956 - MarketingPhone<Color>.height(316) - 22)
            MarketingLockChip(designs: [(MK.design(.macros, .minimal), .accessoryRectangular)], scale: 1.25)
                .rotationEffect(.degrees(3))
                .at(176, 448)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

/// Nutrition: the real screen and today's figures around it.
struct MarketingNutrition: View {
    var body: some View {
        let day = MK.nutrition
        let left = max(0, day.goals.kcal - day.totals.kcal)
        MarketingShowcase(eyebrow: tr("Nutrition"), title: tr("Scanne.\nC'est noté."), subtitle: tr("Calories et macros calculées pour toi.")) {
            MarketingBubble(value: TF.int(left), label: tr("kcal restantes"), colorHex: "F08A24", progress: day.totals.kcal / max(1, day.goals.kcal), size: 118)
                .at(10, 330)
            MarketingBubble(value: "\(TF.int(day.totals.protein)) g", label: tr("Protéines"), colorHex: "E5484D", progress: day.totals.protein / max(1, day.goals.protein))
                .at(326, 404)
            MarketingBubble(value: "\(TF.int(day.totals.carbs)) g", label: tr("Glucides"), colorHex: "F2A33A", progress: day.totals.carbs / max(1, day.goals.carbs))
                .at(332, 560)
            MarketingBubble(value: "\(TF.int(day.totals.fat)) g", label: tr("Lipides"), colorHex: "3366FF", progress: day.totals.fat / max(1, day.goals.fat))
                .at(8, 600)
            MarketingPill(symbol: "barcode.viewfinder", text: tr("Scanner un aliment"), colorHex: "F08A24")
                .at(176, 846)
        }
    }
}

/// Training: the real screen and the Live Activity.
struct MarketingFitness: View {
    var body: some View {
        MarketingShowcase(eyebrow: tr("Sport"), title: tr("Chaque série\ncompte."), subtitle: tr("Séances, repos, records et progrès.")) {
            MarketingFloating(kind: .nextSet, theme: .dark, accent: "FF6B57", width: 150)
                .rotationEffect(.degrees(6))
                .at(278, 360)
            MarketingLiveActivity()
                .frame(width: 392)
                .shadow(color: MK.shadow.opacity(0.25), radius: 26, x: 0, y: 16)
                .at(24, 778)
        }
    }
}

/// Mon Quotidien: the whole day on one screen.
struct MarketingDaily: View {
    var body: some View {
        MarketingShowcase(eyebrow: tr("Mon Quotidien"), title: tr("Ta journée,\nen un écran."), subtitle: tr("Repas, séance, eau, pas, météo.")) {
            MarketingFloating(kind: .hydration, theme: .aurora, accent: "3366FF", width: 140)
                .rotationEffect(.degrees(-6))
                .at(10, 690)
            MarketingFloating(kind: .caloriesLeft, theme: .colorful, accent: "2F8F7A", width: 140)
                .rotationEffect(.degrees(6))
                .at(292, 760)
        }
    }
}

/// The Studio: one widget, many looks.
struct MarketingStudio: View {
    var body: some View {
        MarketingShowcase(eyebrow: tr("Studio"), title: tr("Un widget,\nmille styles."), subtitle: tr("Styles, couleurs, photos, polices."), phoneWidth: 300, phoneX: 20) {
            MarketingFloating(kind: .caloriesLeft, theme: .neon, accent: "FF4F9A", width: 136)
                .rotationEffect(.degrees(7))
                .at(290, 360)
            MarketingFloating(kind: .caloriesLeft, theme: .retro, accent: "F2A33A", width: 136)
                .rotationEffect(.degrees(-5))
                .at(296, 530)
            MarketingFloating(kind: .caloriesLeft, theme: .liquidGlass, accent: "8C6CFF", width: 136)
                .rotationEffect(.degrees(6))
                .at(288, 700)
        }
    }
}

/// Three Lock Screens of the Store, each with its widgets under the clock.
struct MarketingLockScreens: View {
    private let setups = ["jade", "aurore", "creme"]

    var body: some View {
        let width: CGFloat = 200
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(eyebrow: tr("Écran verrouillé"), title: tr("L'écran\nverrouillé\naussi."), subtitle: tr("Des widgets sous l'heure, assortis à ton fond."))
                .padding(.top, 58)
            ForEach([0, 2, 1], id: \.self) { index in
                MarketingPhone(width: width) {
                    MarketingSetupScreen { SetupLockScreen(setup: MK.setup(setups[index])) }
                }
                .rotationEffect(.degrees(Double(index - 1) * 4))
                .at(116 + CGFloat(index) * 104 - width / 2, 420 + (index == 1 ? 0 : 34))
            }
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

struct MarketingStore: View {
    var body: some View {
        MarketingShowcase(eyebrow: tr("Store"), title: tr("Des styles\npour tout."), subtitle: tr("Packs, collections, fonds d'écran.")) {
            EmptyView()
        }
    }
}

struct MarketingPlanning: View {
    var body: some View {
        MarketingShowcase(eyebrow: tr("Planning"), title: tr("Ta semaine,\nbien en main."), subtitle: tr("Horaire, tâches, habitudes, focus.")) {
            MarketingFloating(kind: .priorities, theme: .dark, accent: "5B8DEF", width: 168)
                .rotationEffect(.degrees(5))
                .at(262, 730)
        }
    }
}

struct MarketingFinances: View {
    var body: some View {
        MarketingShowcase(eyebrow: tr("Finances"), title: tr("Ton budget,\nsous contrôle."), subtitle: tr("Dépenses, revenus, catégories.")) {
            MarketingFloating(kind: .budgetLeft, theme: .dark, width: 164)
                .rotationEffect(.degrees(5))
                .at(266, 736)
        }
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
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(eyebrow: tr("Mini-apps"), title: tr("8 mini-apps,\nune seule app."), subtitle: tr("Elles nourrissent tes widgets."))
                .padding(.top, 58)
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { column in
                            card(apps[row * 2 + column])
                        }
                    }
                }
            }
            .at(28, 300)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
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
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: MK.shadow.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}

/// The library: many kinds, many styles.
struct MarketingWall: View {
    var body: some View {
        let small: CGFloat = 186
        let wide: CGFloat = 384
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(eyebrow: tr("Widgets"), title: tr("Plus de 100\nwidgets."), subtitle: tr("Écran d'accueil et écran verrouillé."))
                .padding(.top, 58)
            VStack(spacing: 12) {
                MarketingFloating(kind: .weather, family: .systemMedium, theme: .aurora, width: wide)
                HStack(spacing: 12) {
                    MarketingFloating(kind: .caloriesLeft, theme: .glass, accent: "8C6CFF", width: small)
                    MarketingFloating(kind: .nextClass, theme: .retro, accent: "F2588F", width: small)
                }
                HStack(spacing: 12) {
                    MarketingFloating(kind: .tripCountdown, theme: .elegant, width: small)
                    MarketingFloating(kind: .revenueGoal, theme: .dark, accent: "F2A33A", width: small)
                }
            }
            .at(28, 300)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }
}

/// Nothing leaves the iPhone: no account, no ads, no tracking.
struct MarketingPrivacy: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            MarketingGround()
            MarketingHeadline(eyebrow: tr("Confidentialité"), title: tr("Tes données\nrestent à toi."), subtitle: tr("Sans compte, sans pub, sans suivi."))
                .padding(.top, 58)
            VStack(spacing: 40) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 100, weight: .regular))
                    .foregroundStyle(MK.ink)
                    .frame(width: 210, height: 210)
                    .background(Color.white, in: Circle())
                    .shadow(color: MK.shadow.opacity(0.14), radius: 24, x: 0, y: 12)
                VStack(spacing: 12) {
                    row("iphone", tr("Tout reste sur ton iPhone"))
                    row("person.crop.circle.badge.xmark", tr("Aucun compte à créer"))
                    row("eye.slash.fill", tr("Aucune pub, aucun suivi"))
                }
            }
            .frame(width: MK.canvas.width)
            .padding(.top, 330)
        }
        .frame(width: MK.canvas.width, height: MK.canvas.height, alignment: .topLeading)
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MK.red)
                .frame(width: 30)
            Text(text)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(MK.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(width: 384, height: 66)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: MK.shadow.opacity(0.11), radius: 14, x: 0, y: 8)
    }
}
#endif
