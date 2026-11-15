import SwiftUI
import WidgetKit

/// « Sur mon écran »: the widget at its real size on a made-up Home Screen (generic icons, a dock), or on a
/// night Lock Screen for the accessory sizes, with « Enregistrer le widget » under it. The Studio presents it
/// full screen; its back button closes it, « Enregistrer » closes it and then calls `onSave`.
struct HomeScreenPreview: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let payload: WidgetPayload
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    init(design: WidgetDesign, family: WidgetFamily, payload: WidgetPayload, onSave: @escaping () -> Void) {
        self.design = design
        self.family = family
        self.payload = payload
        self.onSave = onSave
    }

    /// A generic app of iOS, only there to give the widget its surroundings.
    private struct FakeApp: Identifiable {
        let name: String
        let symbol: String
        var id: String { symbol }
    }

    private static let apps: [FakeApp] = [
        FakeApp(name: tr("Photos"), symbol: "photo.on.rectangle.angled"),
        FakeApp(name: tr("Appareil photo"), symbol: "camera.fill"),
        FakeApp(name: tr("Plans"), symbol: "map.fill"),
        FakeApp(name: tr("Météo"), symbol: "cloud.sun.fill"),
        FakeApp(name: tr("Horloge"), symbol: "clock.fill"),
        FakeApp(name: tr("Notes"), symbol: "note.text"),
        FakeApp(name: tr("Calendrier"), symbol: "calendar"),
        FakeApp(name: tr("Réglages"), symbol: "gearshape.fill")
    ]

    private static let dock: [FakeApp] = [
        FakeApp(name: tr("Téléphone"), symbol: "phone.fill"),
        FakeApp(name: tr("Messages"), symbol: "message.fill"),
        FakeApp(name: tr("Safari"), symbol: "safari.fill"),
        FakeApp(name: tr("Musique"), symbol: "music.note")
    ]

    private var size: CGSize { WidgetMetrics.size(family) }
    /// The width of the four columns of icons: a medium widget's width.
    private let gridWidth: CGFloat = 364
    private let rowHeight: CGFloat = 96

    var body: some View {
        Group {
            if family.isAccessory {
                lockScreen
            } else {
                homeScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { backdrop.ignoresSafeArea() }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-preview")
    }

    // MARK: Background

    private var backdrop: some View {
        let palette = CristalPalette.of(style.id)
        let dark = scheme == .dark
        return ZStack {
            if family.isAccessory {
                // A night wallpaper, whatever the app's appearance.
                LinearGradient(colors: [Color(hex: "0B1026"), Color(hex: "2B1B4F"), Color(hex: "14304F")], startPoint: .top, endPoint: .bottom)
            } else {
                Color(hex: palette.hex("bg", dark: dark))
                LinearGradient(
                    colors: [Color(hex: palette.hex("na", dark: dark)), Color(hex: palette.hex("nb", dark: dark)).opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .opacity(0.9)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Bars

    /// The glass capsule: back, « Sur mon écran » and the size.
    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.7), in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(tr("Retour")))
            .accessibilityIdentifier("home-preview-back")
            Text(tr("Sur mon écran"))
                .font(.headline)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: "· " + family.shortTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.trailing, 14)
        }
        .padding(5)
        .cristalGlass(in: Capsule())
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Button {
                save()
            } label: {
                Text(tr("Enregistrer le widget"))
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("home-preview-save")
            if !family.isAccessory {
                dockBar
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Closes the preview, then saves: the Studio's own sheets (the paywall, say) can't open over a full-screen cover.
    private func save() {
        Haptics.tap()
        let action = onSave
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            action()
        }
    }

    private var dockBar: some View {
        HStack(spacing: 0) {
            ForEach(Self.dock) { app in
                iconSquare(app)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(scheme == .dark ? 0.12 : 0.4), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: Home Screen

    private var homeScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                switch family {
                case .systemSmall:
                    // Two columns of icons beside the widget, a row under it.
                    HStack(alignment: .top, spacing: 0) {
                        widgetBlock
                        VStack(spacing: 0) {
                            iconRow(Array(Self.apps[0..<2]), cellWidth: (gridWidth - size.width) / 2)
                            iconRow(Array(Self.apps[2..<4]), cellWidth: (gridWidth - size.width) / 2)
                        }
                        .accessibilityHidden(true)
                    }
                    .frame(width: gridWidth)
                    iconRow(Array(Self.apps[4..<8]), cellWidth: gridWidth / 4)
                        .accessibilityHidden(true)
                case .systemMedium:
                    widgetBlock
                    iconRow(Array(Self.apps[0..<4]), cellWidth: gridWidth / 4)
                        .accessibilityHidden(true)
                    iconRow(Array(Self.apps[4..<8]), cellWidth: gridWidth / 4)
                        .accessibilityHidden(true)
                default:
                    widgetBlock
                    iconRow(Array(Self.apps[0..<4]), cellWidth: gridWidth / 4)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
    }

    /// The widget at its real point size, « Ardane » under it.
    private var widgetBlock: some View {
        VStack(spacing: 4) {
            WidgetPreview(design: design, family: family, payload: payload, width: size.width)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            Text(verbatim: "Ardane")
                .font(.caption2)
                .foregroundStyle(Color.primary)
                .frame(height: 18)
                .accessibilityHidden(true)
        }
        .frame(width: size.width)
    }

    private func iconRow(_ apps: [FakeApp], cellWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(apps) { app in
                VStack(spacing: 5) {
                    iconSquare(app)
                    Text(app.name)
                        .font(.caption2)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: cellWidth, height: rowHeight, alignment: .top)
            }
        }
    }

    private func iconSquare(_ app: FakeApp) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: app.symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    // MARK: Lock Screen

    /// A night Lock Screen: the date, the time and the accessory widget where iOS puts it.
    private var lockScreen: some View {
        VStack(spacing: 8) {
            Group {
                if family == .accessoryInline {
                    lockWidget
                }
                Text(verbatim: Date.now.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).locale(Fmt.locale)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(Date.now, style: .time)
                    .font(.system(size: 84, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(Color.white)
            }
            .environment(\.locale, Fmt.locale)
            .accessibilityHidden(true)
            if family != .accessoryInline {
                lockWidget
                    .padding(.top, 8)
            }
            Spacer(minLength: 24)
            HStack {
                lockRoundButton("flashlight.off.fill")
                Spacer()
                lockRoundButton("camera.fill")
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 12)
            .accessibilityHidden(true)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity)
    }

    private var lockWidget: some View {
        WidgetPreview(design: design, family: family, payload: payload, width: size.width)
    }

    private func lockRoundButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.18), in: Circle())
    }
}
