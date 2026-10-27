import SwiftUI

/// One accent color: a round, softly lit swatch with its name, a ring and a check when selected.
struct AppAccentSwatch: View {
    let accent: AppAccentID
    let isSelected: Bool
    var size: CGFloat = 44
    @Environment(\.colorScheme) private var colorScheme

    private var fill: Color { Color(hex: colorScheme == .dark ? accent.darkHex : accent.lightHex) }

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(fill)
                .overlay {
                    // A soft highlight at the top, for depth without a gimmick.
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)],
                                                 startPoint: .top, endPoint: .center))
                }
                .overlay { Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 1) }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.36, weight: .bold))
                            .foregroundStyle(accent.ink)
                    }
                }
                .frame(width: size, height: size)
                .padding(4)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(fill, lineWidth: 2.5)
                    }
                }
            Text(accent.title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isSelected ? tr("\(accent.title), sélectionné") : accent.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The ten accent colors, five per row. Picking one applies it right away.
struct AppAccentGrid: View {
    @Environment(AppModel.self) private var model
    var swatchSize: CGFloat = 44

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 14) {
            ForEach(AppAccentID.allCases) { accent in
                Button {
                    Haptics.tap()
                    model.setAccent(accent)
                } label: {
                    AppAccentSwatch(accent: accent, isSelected: model.settings.accent == accent, size: swatchSize)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("accent-\(accent.rawValue)")
            }
        }
    }
}

/// Auto, light or dark.
struct AppearancePicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Picker(tr("Mode"), selection: Binding(get: { model.settings.appearance }, set: { mode in
            withAnimation(.easeInOut(duration: 0.35)) { model.setAppearance(mode) }
        })) {
            ForEach(AppearanceMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// A miniature of the app in one style, light or dark, drawn with that style's backgrounds and the chosen accent.
struct MiniAppScreen: View {
    let style: AppStyle
    let dark: Bool

    private var screen: Color { Color(hex: dark ? style.screenDark : style.screenLight) }
    private var card: Color { Color(hex: dark ? style.cardDark : "FFFFFF") }
    private var accent: Color { Color(hex: dark ? style.chosenAccent.darkHex : style.chosenAccent.lightHex) }
    private var onAccent: Color { style.chosenAccent.ink }
    private var ink: Color { Color(hex: dark ? "F2F2F4" : "1C1C1E") }
    private var muted: Color { Color(hex: dark ? "8E8E93" : "8A8A8E") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Aujourd'hui"))
                .font(.system(size: 15, weight: .bold, design: style.fontDesign))
                .foregroundStyle(ink)
                .padding(.top, 4)
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(muted.opacity(0.25), lineWidth: 4)
                    Circle().trim(from: 0, to: 0.64)
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Tâches"))
                        .font(.system(size: 10, weight: .semibold, design: style.fontDesign))
                        .foregroundStyle(ink)
                    Text(tr("3 sur 5"))
                        .font(.system(size: 9, design: style.fontDesign))
                        .foregroundStyle(muted)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(spacing: 7) {
                row(symbol: "drop.fill", width: 46)
                row(symbol: "flame.fill", width: 34)
            }
            .padding(8)
            .background(card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(tr("Ajouter"))
                .font(.system(size: 10, weight: .semibold, design: style.fontDesign))
                .foregroundStyle(onAccent)
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(accent, in: Capsule())
            Spacer(minLength: 0)
            HStack {
                ForEach(Array(["square.grid.2x2.fill", "square.stack.3d.up", "bag", "gearshape"].enumerated()), id: \.offset) { pair in
                    Image(systemName: pair.element)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(pair.offset == 0 ? accent : muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(screen)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .environment(\.colorScheme, dark ? .dark : .light)
        .accessibilityHidden(true)
    }

    private func row(symbol: String, width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
                .background(accent.opacity(0.16), in: Circle())
            Capsule().fill(ink.opacity(0.75)).frame(width: width, height: 5)
            Spacer(minLength: 0)
            Capsule().fill(muted.opacity(0.5)).frame(width: 14, height: 5)
        }
    }
}

/// The same miniature in light and dark, side by side.
struct StylePreviewPair: View {
    let style: AppStyle
    var height: CGFloat = 200

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                MiniAppScreen(style: style, dark: false)
                Label(tr("Clair"), systemImage: "sun.max.fill").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                MiniAppScreen(style: style, dark: true)
                Label(tr("Sombre"), systemImage: "moon.fill").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
        }
        .frame(height: height)
    }
}
