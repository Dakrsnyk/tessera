import Photos
import SwiftUI

// Provenance : fonds dessinés en code pour Ardane (SwiftUI : dégradés, formes, Canvas, bruit pseudo-aléatoire à
// graine fixe). Aucune image externe, aucune photo, aucune ressource tierce : les captures Pinterest de
// docs/references ne servent que d'ambiance (palettes, minimalisme), rien n'en est copié ni retracé.

// MARK: - Model

/// The moods of the collection.
enum WallpaperCategory: String, CaseIterable, Identifiable {
    case sea, mono, soft, night, forest, cosmos
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sea: tr("Mer et vagues")
        case .mono: tr("Noir et blanc")
        case .soft: tr("Dégradés doux")
        case .night: tr("Nuit et orage")
        case .forest: tr("Forêt et brume")
        case .cosmos: tr("Cosmos")
        }
    }

    var symbol: String {
        switch self {
        case .sea: "water.waves"
        case .mono: "circle.lefthalf.filled"
        case .soft: "sun.haze.fill"
        case .night: "cloud.bolt.rain.fill"
        case .forest: "tree.fill"
        case .cosmos: "sparkles"
        }
    }
}

/// The drawing behind a wallpaper; the palette and the seed make each one different.
enum WallpaperStyle {
    case horizon, waves
    case aura, silk, polka
    case eclipse, rings, stripes, arches, halftone
    case skyline, storm, rain
    case pines
    case nebula, aurora, planet, moon, galaxy
}

struct StoreWallpaper: Identifiable, Hashable {
    let id: String
    let category: WallpaperCategory
    let number: Int
    let isPremium: Bool
    let style: WallpaperStyle
    let palette: [String]
    let seed: UInt64

    /// « Mer et vagues 3 » : the category and the number, so that no name needs its own translation.
    var name: String { "\(category.title) \(number)" }

    /// The name for VoiceOver, with « Premium » when it is.
    var spokenName: String { name + (isPremium ? tr(", Premium") : "") }
}

enum WallpaperCatalog {
    /// Free: two or three per mood, about a third. The most elaborate ones are Premium.
    static let all: [StoreWallpaper] = {
        var list: [StoreWallpaper] = []
        func add(_ category: WallpaperCategory, _ style: WallpaperStyle, _ palette: [String], seed: UInt64 = 1, free: Bool = false) {
            let number = list.filter { $0.category == category }.count + 1
            list.append(StoreWallpaper(id: "\(category.rawValue)-\(number)", category: category, number: number,
                                       isPremium: !free, style: style, palette: palette, seed: seed))
        }

        // Mer et vagues. Horizon: [ciel haut, ciel bas, mer à l'horizon, mer profonde, lueur, lune].
        add(.sea, .horizon, ["070B14", "2C3E55", "1A2A3B", "04070C", "FF7A2F"], seed: 1, free: true)
        add(.sea, .waves, ["8FD3D0", "2A8C9A", "3AA3AE", "1F7F8F", "14606F", "0C3F4D"], seed: 3, free: true)
        add(.sea, .horizon, ["6EC6E8", "BDEBF0", "4FD1C5", "0C7C8C", "FFF2C4"], seed: 2)
        add(.sea, .horizon, ["03060E", "0F1E33", "0B1B2C", "02050A", "6C8FB8", "EAF2FF"], seed: 0)
        add(.sea, .waves, ["182B5C", "070F26", "1F3A78", "163066", "10254F", "0A1A3A", "060F26"], seed: 5)
        add(.sea, .waves, ["FFC38A", "F58A5B", "F29B6A", "E46F66", "B8527A", "5E3A6E"], seed: 7)
        add(.sea, .horizon, ["3A2A55", "F7A8A0", "6F5A8C", "1B1A3A", "FFD9A8"], seed: 3)

        // Noir et blanc. Éclipse: [fond, liseré, disque, lueur].
        add(.mono, .eclipse, ["050505", "F2F2F2", "050505", "FFFFFF"], free: true)
        add(.mono, .rings, ["F2F2EF", "1A1A1A"], seed: 2, free: true)
        add(.mono, .halftone, ["050505", "F4F4F4"], free: true)
        add(.mono, .eclipse, ["EDEDEA", "111111", "111111", "FFFFFF"])
        add(.mono, .stripes, ["080808", "EDEDED", "8A8A8A"], seed: 4)
        add(.mono, .arches, ["0A0A0A", "F1F1EE", "5C5C5A"])
        add(.mono, .waves, ["BDBDBB", "4A4A4A", "8E8E8C", "6A6A68", "484846", "262624", "0E0E0E"], seed: 9)

        // Dégradés doux. Aura / soie: [fond, teinte 1, teinte 2, teinte 3].
        add(.soft, .aura, ["F7DDE6", "F4A9C2", "FBC7D6", "EFA1BE"], seed: 1, free: true)
        add(.soft, .aura, ["FFEBDD", "FFB48A", "FFCFA8", "FF9E8A"], seed: 2, free: true)
        add(.soft, .aura, ["ECE4F7", "C3A8F0", "DCC9F7", "A98BE8"], seed: 3, free: true)
        add(.soft, .silk, ["F6D3DA", "E88CA6", "F9E3D8", "C86B8E"], seed: 1)
        add(.soft, .silk, ["DCE6FB", "8FA8F2", "D6C8F6", "6F7FE0"], seed: 2)
        add(.soft, .polka, ["FADCE3", "2B1A1E", "FFF1F4"])
        add(.soft, .aura, ["E4EBDD", "9CC0A0", "CFDDC4", "7FA98F"], seed: 4)
        add(.soft, .silk, ["FFE4D2", "FF9E7A", "FFD2A6", "F27C88"], seed: 3)

        // Nuit et orage. Orage: [fond haut, fond bas, nuage, nuage éclairé, éclair]; ville: [ciel haut, ciel bas,
        // immeubles, fenêtres, lueur]; pluie: [ciel haut, ciel bas, traînées, lumière 1, lumière 2].
        add(.night, .storm, ["07060D", "1A0F26", "2B1B3D", "6A3FA0", "E6B8FF"], seed: 4, free: true)
        add(.night, .skyline, ["0A0C12", "23272F", "06070A", "FFB45A", "C9803A"], seed: 5, free: true)
        add(.night, .skyline, ["0A0420", "3B0F57", "0A0414", "FF3DBE", "00E5FF"], seed: 9)
        add(.night, .rain, ["06080E", "1B2433", "9FB4CC", "FFB45A", "4FB4FF"], seed: 6)
        add(.night, .skyline, ["050A18", "1B3358", "050812", "8FC4FF", "3F7FD6"], seed: 12)
        add(.night, .storm, ["040A0C", "0C2227", "16363D", "4FD6C8", "B8FFF4"], seed: 8)
        add(.night, .rain, ["0A0508", "2A0F1A", "FF8FA6", "FF2E63", "FFB347"], seed: 3)

        // Forêt et brume. Pins: [ciel, brume, couche 1 à 4, de la plus loin à la plus proche].
        add(.forest, .pines, ["C9D0CD", "A9B5B1", "8E9C98", "5F7470", "3A4F4B", "1C2A28"], seed: 2, free: true)
        add(.forest, .pines, ["3A413F", "262E2D", "2F3836", "1E2726", "131B1A", "090E0E"], seed: 5, free: true)
        add(.forest, .pines, ["BCCBD6", "8FA5B8", "7690A6", "4F6C84", "2C4660", "132436"], seed: 7)
        add(.forest, .pines, ["F5D5C0", "E6B59E", "B58C82", "7A5A5A", "453540", "1E1A26"], seed: 3)
        add(.forest, .waves, ["DDE5DA", "9DB5A0", "B7CBB5", "8FAF93", "5F8A6D", "3A6450", "1E3E32"], seed: 11)
        add(.forest, .pines, ["F2DDB8", "DDB27A", "C08A55", "8A5A3A", "4A3228", "211712"], seed: 9)
        add(.forest, .pines, ["F4F7F9", "DDE6EC", "C5D2DB", "98AEBB", "627C8C", "2E4350"], seed: 4)

        // Cosmos. Nébuleuse: [fond haut, fond bas, 3 nuages]; aurore: [fond haut, fond bas, couleur 1, couleur 2];
        // planète: [fond haut, fond bas, clair, sombre, anneau]; lune: [fond haut, fond bas, clair, sombre, lueur];
        // galaxie: [fond haut, fond bas, cœur, bras 1, bras 2].
        add(.cosmos, .nebula, ["05030F", "110A2A", "7B3FE4", "E04FA3", "3F6FE0"], seed: 3, free: true)
        add(.cosmos, .aurora, ["030712", "0A1A2E", "3FF5C4", "8A7CFF"], seed: 2, free: true)
        add(.cosmos, .planet, ["04030A", "1A1040", "F2C9A0", "7A4A66", "D9B98C"], seed: 2)
        add(.cosmos, .moon, ["02040C", "0B1630", "F1EEE2", "B9B4A4", "8FB4FF"], seed: 6)
        add(.cosmos, .galaxy, ["020208", "0A0A22", "FFF1C9", "8FB4FF", "C77DFF"], seed: 4)
        add(.cosmos, .aurora, ["04020E", "160C2E", "B06BFF", "4FE3FF"], seed: 6)
        add(.cosmos, .nebula, ["020A0E", "06202A", "1FB89A", "2F7FE0", "B35CE0"], seed: 8)
        return list
    }()

    static func wallpapers(in category: WallpaperCategory) -> [StoreWallpaper] {
        all.filter { $0.category == category }
    }
}

// MARK: - Store section

/// The « Fonds d'écran » aisle of the Store: moods as chips, a row of thumbnails per mood (or the grid of one),
/// and a preview sheet that saves the wallpaper to Photos.
struct WallpaperStoreSection: View {
    @State private var selection: WallpaperCategory?
    @State private var opened: StoreWallpaper?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            chips
            if let selection {
                grid(selection)
            } else {
                // Lazy: a row draws its thumbnails only when it comes near the screen (each one is a whole wallpaper).
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(WallpaperCategory.allCases) { category in
                        row(category)
                    }
                }
            }
        }
        .sheet(item: $opened) { wallpaper in
            WallpaperSheet(wallpaper: wallpaper)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: tr("Tous"), isSelected: selection == nil) {
                    withAnimation(.snappy) { selection = nil }
                }
                .accessibilityIdentifier("wallpaper-category-all")
                ForEach(WallpaperCategory.allCases) { category in
                    FilterChip(title: category.title, symbol: category.symbol, isSelected: selection == category) {
                        withAnimation(.snappy) { selection = category }
                    }
                    .accessibilityIdentifier("wallpaper-category-\(category.rawValue)")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func row(_ category: WallpaperCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button {
                    withAnimation(.snappy) { selection = category }
                } label: {
                    HStack(spacing: 3) {
                        Text(tr("Tout voir"))
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                }
                .accessibilityLabel(Text("\(tr("Tout voir")) : \(category.title)"))
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(WallpaperCatalog.wallpapers(in: category)) { wallpaper in
                        WallpaperCard(wallpaper: wallpaper) { opened = wallpaper }
                            .frame(width: 112)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    private func grid(_ category: WallpaperCategory) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), alignment: .leading, spacing: 18) {
            ForEach(WallpaperCatalog.wallpapers(in: category)) { wallpaper in
                WallpaperCard(wallpaper: wallpaper) { opened = wallpaper }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// A thumbnail: the wallpaper in the shape of a screen, a Premium badge when it is, its name below.
private struct WallpaperCard: View {
    let wallpaper: StoreWallpaper
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                WallpaperPreview(wallpaper: wallpaper)
                    .overlay(alignment: .topTrailing) {
                        if wallpaper.isPremium {
                            PremiumBadge(compact: true).padding(6)
                        }
                    }
                Text(wallpaper.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(wallpaper.spokenName))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("wallpaper-\(wallpaper.id)")
    }
}

/// The wallpaper scaled to the width it is given, at the proportions of an iPhone screen. Rasterized once
/// at that size (`drawingGroup`), so that a thumbnail stays light.
struct WallpaperPreview: View {
    let wallpaper: StoreWallpaper

    var body: some View {
        GeometryReader { proxy in
            WallpaperArt(wallpaper: wallpaper)
                .scaleEffect(proxy.size.width / wpW, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .drawingGroup()
                .clipShape(RoundedRectangle(cornerRadius: proxy.size.width * 0.12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: proxy.size.width * 0.12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                }
        }
        .aspectRatio(wpW / wpH, contentMode: .fit)
    }
}

// MARK: - Preview and saving

/// The wallpaper full size, with the button that saves it to Photos (free) or opens the paywall (Premium).
struct WallpaperSheet: View {
    let wallpaper: StoreWallpaper
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var state: SaveState = .idle

    enum SaveState {
        case idle, saving, saved, denied, failed
    }

    private var needsPremium: Bool { wallpaper.isPremium && !model.isPremium }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GeometryReader { proxy in
                    let width = max(120, min(proxy.size.width - 40, proxy.size.height * wpW / wpH))
                    WallpaperPreview(wallpaper: wallpaper)
                        .frame(width: width)
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(wallpaper.spokenName))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)
            .background(.screenGradient)
            .safeAreaInset(edge: .bottom) {
                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if state == .saving { ProgressView().controlSize(.small) }
                        Label(buttonTitle, systemImage: buttonSymbol)
                    }
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(state == .saving || state == .saved)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(AppFill.screenFill.opacity(0.96))
                .accessibilityIdentifier("wallpaper-save")
            }
            .navigationTitle(wallpaper.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Fermer")) { dismiss() }
                }
            }
        }
    }

    private var buttonTitle: String {
        if needsPremium { return tr("Débloquer avec Premium") }
        return state == .saved ? tr("Enregistré dans Photos") : tr("Enregistrer dans Photos")
    }

    private var buttonSymbol: String {
        if needsPremium { return "sparkles" }
        return state == .saved ? "checkmark" : "square.and.arrow.down"
    }

    private var message: String {
        switch state {
        case .denied: return tr("Ardane n'a pas accès à Photos. Autorise l'ajout de photos dans Réglages › Ardane › Photos.")
        case .failed: return tr("L'image n'a pas pu être enregistrée. Réessaie.")
        case .saved: return tr("Dans Photos, ouvre l'image, touche Partager puis « Utiliser en fond d'écran ».")
        case .idle, .saving:
            if needsPremium { return tr("Ce fond fait partie de Premium.") }
            return tr("À la bonne taille pour ton iPhone. Ensuite, dans Photos : Partager › « Utiliser en fond d'écran ».")
        }
    }

    private func primaryAction() {
        if needsPremium {
            dismiss()
            router.showPaywall(PaywallContext(
                symbol: "photo.fill",
                title: tr("Les fonds d'écran Premium"),
                detail: tr("Les plus beaux fonds d'écran du Store sont dans Premium : enregistre-les dans Photos, à la taille de ton iPhone."),
                perk: .styles
            ))
        } else {
            save()
        }
    }

    /// Adds the image to Photos (add-only access: the library is never read), at the size of the screen.
    private func save() {
        state = .saving
        Task { @MainActor in
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                state = .denied
                return
            }
            let renderer = ImageRenderer(content: WallpaperArt(wallpaper: wallpaper))
            renderer.scale = 3
            guard let image = renderer.uiImage else {
                state = .failed
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                state = .saved
                Haptics.success()
            } catch {
                state = .failed
            }
        }
    }
}

// MARK: - Art

private let wpW = SetupScreen.size.width
private let wpH = SetupScreen.size.height

private func pc(_ palette: [String], _ index: Int) -> Color {
    guard !palette.isEmpty else { return .black }
    return Color(hex: palette[min(index, palette.count - 1)])
}

/// Same sequence on every launch: nothing moves from one render to the next.
private struct WpRandom {
    var state: UInt64

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

/// A wallpaper at the size of the screen (402 × 874 pt, as the Home Screens): the calm top is left to the
/// clock, the subject sits in the middle and the lower half.
struct WallpaperArt: View {
    let wallpaper: StoreWallpaper

    var body: some View {
        ZStack { art }
            .frame(width: wpW, height: wpH)
            .clipped()
            .accessibilityHidden(true)
    }

    @ViewBuilder private var art: some View {
        let palette = wallpaper.palette
        let seed = wallpaper.seed
        switch wallpaper.style {
        case .horizon: WpHorizon(palette: palette, seed: seed)
        case .waves: WpWaves(palette: palette, seed: seed)
        case .aura: WpAura(palette: palette, seed: seed)
        case .silk: WpSilk(palette: palette, seed: seed)
        case .polka: WpPolka(palette: palette)
        case .eclipse: WpEclipse(palette: palette)
        case .rings: WpRings(palette: palette, seed: seed)
        case .stripes: WpStripes(palette: palette, seed: seed)
        case .arches: WpArches(palette: palette)
        case .halftone: WpHalftone(palette: palette)
        case .skyline: WpSkyline(palette: palette, seed: seed)
        case .storm: WpStorm(palette: palette, seed: seed)
        case .rain: WpRain(palette: palette, seed: seed)
        case .pines: WpPines(palette: palette, seed: seed)
        case .nebula: WpNebula(palette: palette, seed: seed)
        case .aurora: WpAurora(palette: palette, seed: seed)
        case .planet: WpPlanet(palette: palette, seed: seed)
        case .moon: WpMoon(palette: palette, seed: seed)
        case .galaxy: WpGalaxy(palette: palette, seed: seed)
        }
    }
}

// MARK: Shared pieces

private struct WpStars: View {
    let seed: UInt64
    var count = 160
    var maxY: Double = 1
    var brightness: Double = 1

    var body: some View {
        Canvas { context, size in
            var random = WpRandom(state: seed &* 977 &+ 13)
            for index in 0..<count {
                let x = CGFloat(random.next()) * size.width
                let y = CGFloat(random.next() * maxY) * size.height
                let bright = index % 23 == 0
                let radius: CGFloat = bright ? 1.6 : CGFloat(0.4 + random.next())
                let alpha: Double = (bright ? 0.95 : 0.2 + random.next() * 0.6) * brightness
                if bright {
                    context.fill(Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)), with: .color(.white.opacity(0.08 * brightness)))
                }
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A fine grain over a flat colour, so that a gradient doesn't show bands.
private struct WpGrain: View {
    let seed: UInt64
    var opacity: Double = 0.05

    var body: some View {
        Canvas { context, size in
            var random = WpRandom(state: seed &+ 4242)
            for index in 0..<1200 {
                let x = CGFloat(random.next()) * size.width
                let y = CGFloat(random.next()) * size.height
                let tint: Color = index % 2 == 0 ? .black : .white
                context.fill(Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(tint.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Sea

private struct WpHorizon: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        let horizon = wpH * (0.5 + 0.04 * CGFloat(seed % 4))
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: horizon)
                LinearGradient(colors: [pc(palette, 2), pc(palette, 3)], startPoint: .top, endPoint: .bottom)
            }
            Ellipse()
                .fill(RadialGradient(colors: [pc(palette, 4).opacity(0.9), pc(palette, 4).opacity(0)], center: .center, startRadius: 0, endRadius: 210))
                .frame(width: 440, height: 160)
                .position(x: wpW * 0.62, y: horizon)
            if palette.count > 5 {
                Circle()
                    .fill(pc(palette, 5))
                    .frame(width: 52, height: 52)
                    .shadow(color: pc(palette, 4).opacity(0.8), radius: 20)
                    .position(x: wpW * 0.3, y: horizon * 0.66)
            }
            Canvas { context, size in
                var random = WpRandom(state: seed &* 53 &+ 9)
                let glowX = size.width * 0.62
                let glow = pc(palette, 4)
                // The reflection of the light on the water, wider and sparser towards us.
                for index in 0..<90 {
                    let t = CGFloat(index) / 90
                    let y = horizon + 3 + t * t * (size.height - horizon) * 0.55
                    let width = (20 + 150 * t) * CGFloat(0.4 + random.next())
                    let x = glowX + CGFloat(random.next() - 0.5) * (40 + 120 * t)
                    let rect = CGRect(x: x - width / 2, y: y, width: width, height: 1.4 + 2.2 * t)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(glow.opacity(0.5 * Double(1 - t))))
                }
                // Light chop everywhere on the sea.
                for _ in 0..<150 {
                    let y = horizon + 6 + CGFloat(random.next()) * (size.height - horizon - 6)
                    let x = CGFloat(random.next()) * size.width
                    let width = CGFloat(8 + random.next() * 34)
                    let rect = CGRect(x: x, y: y, width: width, height: 1)
                    context.fill(Path(rect), with: .color(.white.opacity(0.05 + random.next() * 0.1)))
                }
            }
            // The shore, dark and wet, with its line of foam.
            Canvas { context, size in
                var land = Path()
                land.move(to: CGPoint(x: 0, y: size.height * 0.80))
                land.addCurve(to: CGPoint(x: size.width * 0.72, y: size.height),
                              control1: CGPoint(x: size.width * 0.38, y: size.height * 0.76),
                              control2: CGPoint(x: size.width * 0.5, y: size.height * 0.92))
                var foam = land
                land.addLine(to: CGPoint(x: 0, y: size.height))
                land.closeSubpath()
                context.fill(land, with: .color(.black.opacity(0.5)))
                context.stroke(foam, with: .color(.white.opacity(0.32)), lineWidth: 1.6)
                foam = foam.offsetBy(dx: 10, dy: -9)
                context.stroke(foam, with: .color(.white.opacity(0.14)), lineWidth: 1.2)
            }
        }
    }
}

private struct WpWaves: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        let layers = max(1, palette.count - 2)
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [pc(palette, 2).opacity(0.4), pc(palette, 2).opacity(0)], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 260)
            Canvas { context, size in
                var random = WpRandom(state: seed &* 7919 &+ 3)
                for layer in 0..<layers {
                    let t = CGFloat(layer) / CGFloat(max(1, layers - 1))
                    let baseY = size.height * (0.42 + 0.44 * t)
                    let amplitude = Double(10 + 16 * t)
                    let frequency = 1.1 + random.next() * 1.4
                    let second = 2.3 + random.next() * 1.5
                    let phase = random.next() * 6.28
                    let phaseTwo = random.next() * 6.28
                    var points: [CGPoint] = []
                    var x: CGFloat = 0
                    while x <= size.width + 6 {
                        let u = Double(x / size.width)
                        let main = sin(u * frequency * 2 * Double.pi + phase)
                        let ripple = 0.45 * sin(u * second * 2 * Double.pi + phaseTwo)
                        let wave = amplitude * (main + ripple)
                        points.append(CGPoint(x: x, y: baseY + CGFloat(wave)))
                        x += 6
                    }
                    var crest = Path()
                    crest.addLines(points)
                    var area = crest
                    area.addLine(to: CGPoint(x: size.width + 6, y: size.height))
                    area.addLine(to: CGPoint(x: 0, y: size.height))
                    area.closeSubpath()
                    context.fill(area, with: .color(pc(palette, layer + 2)))
                    context.stroke(crest, with: .color(.white.opacity(0.18)), lineWidth: 1.5)
                }
            }
        }
    }
}

// MARK: Soft gradients

private struct WpAura: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        let shift = 0.18 * CGFloat(Int(seed % 3) - 1)
        ZStack {
            pc(palette, 0)
            RadialGradient(colors: [pc(palette, 1).opacity(0.9), pc(palette, 1).opacity(0)], center: UnitPoint(x: 0.5 + shift, y: 0.66), startRadius: 0, endRadius: 360)
            RadialGradient(colors: [pc(palette, 2).opacity(0.8), pc(palette, 2).opacity(0)], center: UnitPoint(x: 0.1, y: 0.92), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [pc(palette, 3).opacity(0.55), pc(palette, 3).opacity(0)], center: UnitPoint(x: 0.95, y: 0.5), startRadius: 0, endRadius: 260)
            WpGrain(seed: seed, opacity: 0.04)
        }
    }
}

private struct WpSilk: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        let tilt = Double(seed % 3) * 8
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            ZStack {
                Ellipse().fill(pc(palette, 1).opacity(0.85)).frame(width: 520, height: 230)
                    .rotationEffect(.degrees(-24 + tilt)).position(x: wpW * 0.35, y: wpH * 0.62)
                Ellipse().fill(pc(palette, 3).opacity(0.7)).frame(width: 480, height: 200)
                    .rotationEffect(.degrees(28 - tilt)).position(x: wpW * 0.8, y: wpH * 0.78)
                Ellipse().fill(pc(palette, 2).opacity(0.9)).frame(width: 440, height: 180)
                    .rotationEffect(.degrees(-12)).position(x: wpW * 0.3, y: wpH * 0.9)
                Ellipse().fill(Color.white.opacity(0.35)).frame(width: 360, height: 140)
                    .rotationEffect(.degrees(35)).position(x: wpW * 0.85, y: wpH * 0.5)
            }
            .blur(radius: 56)
            WpGrain(seed: seed, opacity: 0.035)
        }
    }
}

private struct WpPolka: View {
    let palette: [String]

    var body: some View {
        ZStack {
            pc(palette, 0)
            Canvas { context, size in
                let spacing: CGFloat = 34
                var row = 0
                var y: CGFloat = 17
                while y < size.height {
                    // Nothing in the top third, for the clock; the dots appear gradually.
                    let alpha = min(1, max(0, Double((y - size.height * 0.22) / (size.height * 0.28))))
                    if alpha > 0 {
                        var x: CGFloat = row % 2 == 0 ? 17 : 34
                        while x < size.width + spacing {
                            context.fill(Path(ellipseIn: CGRect(x: x - 6.5, y: y - 6.5, width: 13, height: 13)), with: .color(pc(palette, 1).opacity(alpha)))
                            x += spacing
                        }
                    }
                    y += 30
                    row += 1
                }
            }
            RadialGradient(colors: [pc(palette, 2).opacity(0.9), pc(palette, 2).opacity(0)], center: UnitPoint(x: 0.5, y: 0.1), startRadius: 0, endRadius: 300)
        }
    }
}

// MARK: Black and white

private struct WpEclipse: View {
    let palette: [String]

    var body: some View {
        ZStack {
            pc(palette, 0)
            Circle().fill(pc(palette, 3).opacity(0.5)).frame(width: 300, height: 300).blur(radius: 46)
                .position(x: wpW / 2, y: wpH * 0.6)
            Circle().fill(pc(palette, 2)).frame(width: 220, height: 220)
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(colors: [pc(palette, 1), pc(palette, 1).opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                }
                .position(x: wpW / 2, y: wpH * 0.6)
            Circle().strokeBorder(pc(palette, 1).opacity(0.2), lineWidth: 1).frame(width: 282, height: 282)
                .position(x: wpW / 2, y: wpH * 0.6)
            Circle().strokeBorder(pc(palette, 1).opacity(0.08), lineWidth: 1).frame(width: 350, height: 350)
                .position(x: wpW / 2, y: wpH * 0.6)
        }
    }
}

private struct WpRings: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            pc(palette, 0)
            Canvas { context, size in
                let center = CGPoint(x: size.width * (0.35 + 0.1 * CGFloat(seed % 4)), y: size.height * 0.66)
                for index in 0..<18 {
                    let i = CGFloat(index)
                    let radius = 22 + i * 16 + i * i * 1.1
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    let alpha = max(0.1, 0.85 - Double(index) * 0.045)
                    context.stroke(ring, with: .color(pc(palette, 1).opacity(alpha)), lineWidth: index % 5 == 0 ? 2.4 : 1.1)
                }
            }
            // The rings fade out towards the top: the clock stays readable.
            LinearGradient(colors: [pc(palette, 0), pc(palette, 0).opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.36))
        }
    }
}

private struct WpStripes: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            pc(palette, 0)
            Canvas { context, size in
                var random = WpRandom(state: seed &+ 11)
                let floor = size.height * 0.92
                var index = 0
                var x: CGFloat = 9
                while x < size.width {
                    let u = Double(x / size.width)
                    let envelope = pow(sin(u * Double.pi), 1.3)
                    let jitter = 0.7 + 0.3 * random.next()
                    let height = size.height * CGFloat(0.4 * (0.12 + 0.88 * envelope) * jitter)
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: floor))
                    line.addLine(to: CGPoint(x: x, y: floor - height))
                    let color: Color = index % 11 == 5 ? pc(palette, 2) : pc(palette, 1).opacity(0.35 + 0.65 * envelope)
                    context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    x += 7
                    index += 1
                }
            }
        }
    }
}

private struct WpArches: View {
    let palette: [String]

    var body: some View {
        ZStack {
            pc(palette, 0)
            arch(width: 290, height: 400, color: pc(palette, 1))
            arch(width: 210, height: 310, color: pc(palette, 2))
            arch(width: 130, height: 220, color: pc(palette, 0))
            Rectangle().fill(pc(palette, 1).opacity(0.35)).frame(width: wpW, height: 1)
                .position(x: wpW / 2, y: wpH * 0.9)
        }
    }

    private func arch(width: CGFloat, height: CGFloat, color: Color) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: width / 2, topTrailingRadius: width / 2, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .position(x: wpW / 2, y: wpH * 0.9 - height / 2)
    }
}

private struct WpHalftone: View {
    let palette: [String]

    var body: some View {
        ZStack {
            pc(palette, 0)
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.62)
                let light = CGPoint(x: center.x - 70, y: center.y - 70)
                let radius: CGFloat = 175
                let step: CGFloat = 12
                var y = step / 2
                while y < size.height {
                    var x = step / 2
                    while x < size.width {
                        let distance = hypot(x - center.x, y - center.y)
                        if distance < radius {
                            let fromLight = hypot(x - light.x, y - light.y)
                            let diameter = max(0.6, 5.6 * (1 - fromLight / 300))
                            context.fill(Path(ellipseIn: CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)), with: .color(pc(palette, 1)))
                        }
                        x += step
                    }
                    y += step
                }
            }
        }
    }
}

// MARK: Night and storm

private struct WpSkyline: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.78))
            RadialGradient(colors: [pc(palette, 4).opacity(0.55), pc(palette, 4).opacity(0)], center: UnitPoint(x: 0.5, y: 0.72), startRadius: 0, endRadius: 300)
            Canvas { context, size in
                var random = WpRandom(state: seed &* 31 &+ 5)
                // Far to near: baseline, tallest, opacity, share of lit windows.
                let layers: [(CGFloat, CGFloat, Double, Double)] = [
                    (0.78, 0.22, 0.5, 0.0),
                    (0.84, 0.30, 0.8, 0.22),
                    (0.92, 0.34, 1.0, 0.3)
                ]
                for (base, tallest, alpha, lit) in layers {
                    var x: CGFloat = -8
                    while x < size.width {
                        let width = CGFloat(26 + random.next() * 34)
                        let height = size.height * (0.06 + tallest * CGFloat(random.next()))
                        let top = size.height * base - height
                        let tower = CGRect(x: x, y: top, width: width, height: size.height - top)
                        context.fill(Path(tower), with: .color(pc(palette, 2).opacity(alpha)))
                        if lit > 0 {
                            var wy = top + 8
                            while wy < size.height * 0.97 {
                                var wx = x + 5
                                while wx < x + width - 7 {
                                    if random.next() < lit {
                                        let glow = 0.35 + 0.65 * random.next()
                                        context.fill(Path(CGRect(x: wx, y: wy, width: 3.5, height: 5)), with: .color(pc(palette, 3).opacity(glow)))
                                    }
                                    wx += 8
                                }
                                wy += 10
                            }
                        }
                        x += width
                    }
                }
                // A thin mast over the city.
                let mast = CGRect(x: size.width * 0.62, y: size.height * 0.4, width: 4, height: size.height * 0.6)
                context.fill(Path(mast), with: .color(pc(palette, 2)))
                context.fill(Path(ellipseIn: CGRect(x: size.width * 0.62 - 1, y: size.height * 0.4 - 4, width: 6, height: 6)), with: .color(pc(palette, 3)))
            }
        }
    }
}

private struct WpStorm: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var random = WpRandom(state: seed &* 13 &+ 1)
                for _ in 0..<46 {
                    let x = CGFloat(random.next()) * size.width
                    let y = size.height * (0.30 + 0.6 * CGFloat(random.next()))
                    let radius = CGFloat(50 + random.next() * 90)
                    let rect = CGRect(x: x - radius, y: y - radius * 0.8, width: radius * 2, height: radius * 1.6)
                    let isLit = random.next() < 0.3
                    let color: Color = isLit ? pc(palette, 3).opacity(0.35) : pc(palette, 2).opacity(0.8)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .blur(radius: 22)
            RadialGradient(colors: [pc(palette, 4).opacity(0.22), pc(palette, 4).opacity(0)], center: UnitPoint(x: 0.7, y: 0.5), startRadius: 0, endRadius: 260)
            bolt.blur(radius: 8)
            bolt
        }
    }

    private var bolt: some View {
        Canvas { context, size in
            var random = WpRandom(state: seed &+ 77)
            var x = size.width * (0.55 + 0.25 * CGFloat(random.next()))
            var y = size.height * 0.34
            var points: [CGPoint] = [CGPoint(x: x, y: y)]
            while y < size.height * 0.68 {
                y += CGFloat(24 + random.next() * 26)
                x += CGFloat(random.next() - 0.5) * 60
                points.append(CGPoint(x: x, y: y))
            }
            var path = Path()
            path.addLines(points)
            let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(pc(palette, 4).opacity(0.95)), style: style)
            // A branch from the third point.
            if points.count > 3 {
                var branch = Path()
                var bx = points[2].x
                var by = points[2].y
                branch.move(to: CGPoint(x: bx, y: by))
                for _ in 0..<3 {
                    bx += CGFloat(10 + random.next() * 26)
                    by += CGFloat(14 + random.next() * 20)
                    branch.addLine(to: CGPoint(x: bx, y: by))
                }
                context.stroke(branch, with: .color(pc(palette, 4).opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct WpRain: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            // Lights out of focus behind the glass.
            Canvas { context, size in
                var random = WpRandom(state: seed &* 19 &+ 7)
                for _ in 0..<22 {
                    let x = CGFloat(random.next()) * size.width
                    let y = size.height * (0.45 + 0.5 * CGFloat(random.next()))
                    let radius = CGFloat(10 + random.next() * 34)
                    let color = random.next() < 0.5 ? pc(palette, 3) : pc(palette, 4)
                    let alpha = 0.25 + 0.45 * random.next()
                    context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color.opacity(alpha)))
                }
            }
            .blur(radius: 7)
            Canvas { context, size in
                var random = WpRandom(state: seed &* 23 &+ 3)
                for _ in 0..<140 {
                    let x = CGFloat(random.next()) * (size.width + 80)
                    let y = size.height * (0.1 + 0.9 * CGFloat(random.next()))
                    let length = CGFloat(40 + random.next() * 70)
                    var streak = Path()
                    streak.move(to: CGPoint(x: x, y: y))
                    streak.addLine(to: CGPoint(x: x - length * 0.18, y: y + length))
                    let alpha = 0.05 + 0.18 * random.next()
                    context.stroke(streak, with: .color(pc(palette, 2).opacity(alpha)), lineWidth: 1)
                }
            }
        }
    }
}

// MARK: Forest

/// One fir: tiers of a triangle, narrowing towards the top.
private func pinePath(cx: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat) -> Path {
    let tiers = 5
    var right: [CGPoint] = []
    for tier in 0..<tiers {
        let f = CGFloat(tier + 1) / CGFloat(tiers)
        let y = base - height + height * f
        let reach = width / 2 * f
        right.append(CGPoint(x: reach, y: y))
        if tier < tiers - 1 { right.append(CGPoint(x: reach * 0.5, y: y)) }
    }
    var path = Path()
    path.move(to: CGPoint(x: cx, y: base - height))
    for point in right { path.addLine(to: CGPoint(x: cx + point.x, y: point.y)) }
    for point in right.reversed() { path.addLine(to: CGPoint(x: cx - point.x, y: point.y)) }
    path.closeSubpath()
    return path
}

private struct WpPineLayer: View {
    let color: Color
    let fog: Color
    let base: CGFloat
    let height: CGFloat
    let seed: UInt64
    let showsFog: Bool

    var body: some View {
        ZStack {
            // The haze that rises before the nearer layer hides the one behind.
            if showsFog {
                LinearGradient(colors: [fog.opacity(0), fog.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(width: wpW, height: 280)
                    .position(x: wpW / 2, y: base - 120)
            }
            Canvas { context, size in
                var random = WpRandom(state: seed)
                context.fill(Path(CGRect(x: 0, y: base + 10, width: size.width, height: size.height)), with: .color(color))
                var x: CGFloat = -20
                while x < size.width + 20 {
                    let treeHeight = height * CGFloat(0.55 + random.next() * 0.7)
                    let treeWidth = treeHeight * CGFloat(0.34 + random.next() * 0.1)
                    context.fill(pinePath(cx: x, base: base + 14, height: treeHeight, width: treeWidth), with: .color(color))
                    x += treeWidth * CGFloat(0.45 + random.next() * 0.35)
                }
            }
        }
    }
}

private struct WpPines: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<4, id: \.self) { layer in
                WpPineLayer(
                    color: pc(palette, layer + 2),
                    fog: pc(palette, 1),
                    base: wpH * (0.56 + 0.1 * CGFloat(layer)),
                    height: 120 + 55 * CGFloat(layer),
                    seed: seed &* 101 &+ UInt64(layer),
                    showsFog: layer > 0
                )
            }
        }
    }
}

// MARK: Cosmos

private struct WpNebula: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            ZStack {
                Ellipse().fill(pc(palette, 2).opacity(0.7)).frame(width: 520, height: 300)
                    .rotationEffect(.degrees(-30)).position(x: wpW * 0.3, y: wpH * 0.62)
                Ellipse().fill(pc(palette, 3).opacity(0.6)).frame(width: 440, height: 260)
                    .rotationEffect(.degrees(25)).position(x: wpW * 0.75, y: wpH * 0.5)
                Ellipse().fill(pc(palette, 4).opacity(0.55)).frame(width: 480, height: 240)
                    .rotationEffect(.degrees(-10)).position(x: wpW * 0.5, y: wpH * 0.82)
            }
            .blur(radius: 70)
            WpStars(seed: seed, count: 230, maxY: 1, brightness: 0.9)
        }
    }
}

private struct WpAurora: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            WpStars(seed: seed, count: 120, maxY: 0.8, brightness: 0.7)
            // Curtains of light.
            Canvas { context, size in
                let offset = Double(seed)
                for index in 0..<48 {
                    let t = Double(index) / 47
                    let x = -20 + CGFloat(t) * (size.width + 40)
                    let wave: Double = 70 * sin(t * 5.2 + offset) + 28 * sin(t * 13 + offset)
                    let top = CGFloat(300 + wave)
                    let bottom = top + CGFloat(210 + 80 * sin(t * 3.1 + 1))
                    let drift = CGFloat(26 * sin(t * 4))
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: top))
                    path.addLine(to: CGPoint(x: x + drift, y: bottom))
                    let color = t < 0.55 ? pc(palette, 2) : pc(palette, 3)
                    context.stroke(
                        path,
                        with: .linearGradient(Gradient(colors: [color.opacity(0), color.opacity(0.5), color.opacity(0)]),
                                              startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x, y: bottom)),
                        lineWidth: 7
                    )
                }
            }
            .blur(radius: 9)
            // The ridge in front.
            Canvas { context, size in
                var random = WpRandom(state: seed &* 5 &+ 1)
                var ridge = Path()
                ridge.move(to: CGPoint(x: 0, y: size.height))
                var x: CGFloat = 0
                while x <= size.width + 40 {
                    ridge.addLine(to: CGPoint(x: x, y: size.height * 0.87 - CGFloat(random.next()) * 46))
                    x += 40
                }
                ridge.addLine(to: CGPoint(x: size.width + 40, y: size.height))
                ridge.closeSubpath()
                context.fill(ridge, with: .color(pc(palette, 0).opacity(0.95)))
            }
        }
    }
}

private struct WpPlanet: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            WpStars(seed: seed, count: 150, maxY: 1, brightness: 0.8)
            RadialGradient(colors: [pc(palette, 2).opacity(0.25), pc(palette, 2).opacity(0)], center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: 320)
            if hasRing { ring(isFront: false) }
            Circle()
                .fill(LinearGradient(colors: [pc(palette, 2), pc(palette, 3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 240, height: 240)
                .overlay {
                    ZStack {
                        Capsule().fill(pc(palette, 3).opacity(0.3)).frame(height: 18).offset(y: -44)
                        Capsule().fill(pc(palette, 3).opacity(0.22)).frame(height: 28).offset(y: 22)
                        Capsule().fill(pc(palette, 2).opacity(0.25)).frame(height: 12).offset(y: 62)
                    }
                    .clipShape(Circle())
                }
                .overlay {
                    Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.65)], center: UnitPoint(x: 0.3, y: 0.28), startRadius: 70, endRadius: 210))
                }
                .position(x: wpW / 2, y: wpH * 0.62)
            if hasRing { ring(isFront: true) }
        }
    }

    private var hasRing: Bool { seed % 2 == 0 }

    /// The half of the ring behind the planet, or the half in front of it.
    private func ring(isFront: Bool) -> some View {
        Ellipse()
            .strokeBorder(pc(palette, 4).opacity(0.85), lineWidth: 14)
            .frame(width: 420, height: 100)
            .mask(alignment: isFront ? .bottom : .top) { Rectangle().frame(height: 50) }
            .rotationEffect(.degrees(-16))
            .position(x: wpW / 2, y: wpH * 0.62)
    }
}

private struct WpMoon: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            WpStars(seed: seed, count: 170, maxY: 1, brightness: 0.8)
            Circle().fill(pc(palette, 4).opacity(0.3)).frame(width: 330, height: 330).blur(radius: 44)
                .position(x: wpW / 2, y: wpH * 0.6)
            Circle()
                .fill(RadialGradient(colors: [pc(palette, 2), pc(palette, 3)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 170))
                .frame(width: 220, height: 220)
                .overlay {
                    Canvas { context, size in
                        var random = WpRandom(state: seed &* 41 &+ 2)
                        for _ in 0..<9 {
                            let x = 30 + CGFloat(random.next()) * (size.width - 60)
                            let y = 30 + CGFloat(random.next()) * (size.height - 60)
                            let radius = CGFloat(8 + random.next() * 22)
                            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(pc(palette, 3).opacity(0.35)))
                        }
                    }
                    .clipShape(Circle())
                }
                .position(x: wpW / 2, y: wpH * 0.6)
        }
    }
}

private struct WpGalaxy: View {
    let palette: [String]
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [pc(palette, 0), pc(palette, 1)], startPoint: .top, endPoint: .bottom)
            WpStars(seed: seed, count: 170, maxY: 1, brightness: 0.8)
            dust.blur(radius: 6).opacity(0.8)
            dust
            RadialGradient(colors: [pc(palette, 2).opacity(0.95), pc(palette, 2).opacity(0)], center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: 70)
        }
    }

    /// Two spiral arms of tiny dots, thinning out away from the bright core.
    private var dust: some View {
        Canvas { context, size in
            var random = WpRandom(state: seed &* 17 &+ 2)
            let center = CGPoint(x: size.width / 2, y: size.height * 0.62)
            let tilt = -0.5
            for index in 0..<1500 {
                let arm = Double(index % 2)
                let t = random.next()
                let radius = 12 + 170 * t
                let angle = t * 4.2 + arm * Double.pi
                let scatter = (random.next() - 0.5) * (14 + 44 * t)
                let ax = cos(angle) * (radius + scatter)
                let ay = sin(angle) * (radius + scatter) * 0.55
                let px = center.x + CGFloat(ax * cos(tilt) - ay * sin(tilt))
                let py = center.y + CGFloat(ax * sin(tilt) + ay * cos(tilt))
                let diameter = CGFloat(0.8 + random.next() * 1.6 * (1 - t * 0.5))
                let color: Color = t < 0.25 ? pc(palette, 2) : (index % 2 == 0 ? pc(palette, 3) : pc(palette, 4))
                let alpha = 0.25 + 0.6 * (1 - t) * random.next()
                context.fill(Path(ellipseIn: CGRect(x: px, y: py, width: diameter, height: diameter)), with: .color(color.opacity(alpha)))
            }
        }
    }
}
