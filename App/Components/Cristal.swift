import SwiftUI

// Matières de la refonte « Cristal » (cristal.css : .gl, .pn, .dk). Utilisées par `.card()`, `cristalScreen()` et l'Accueil.

/// Fond d'un écran : la couleur `bg` de la graine et ses deux nappes (dégradés radiaux, sans flou, dessinés une fois).
struct CristalBackdrop: View {
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let dark = scheme == .dark
        GeometryReader { geo in
            // Écran de référence 393 × 852.
            let sx = geo.size.width / 393, sy = geo.size.height / 852
            ZStack {
                Color(hex: palette.hex("bg", dark: dark))
                ForEach(Array(palette.washes.enumerated()), id: \.offset) { index, wash in
                    let color = Color(hex: palette.hex(index == 0 ? "na" : "nb", dark: dark))
                    Rectangle()
                        .fill(RadialGradient(stops: [.init(color: color, location: 0),
                                                     .init(color: color.opacity(0.8), location: 0.5),
                                                     .init(color: color.opacity(0), location: 1)],
                                             center: .center, startRadius: 0, endRadius: wash.rx))
                        .frame(width: wash.rx * 2, height: wash.rx * 2)
                        .scaleEffect(x: sx, y: sy * wash.ry / wash.rx)
                        .position(x: wash.x * sx, y: wash.y * sy)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CristalPanelModifier: ViewModifier {
    let radius: CGFloat?
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.cristalPanelDrawsShadow) private var drawsShadow

    func body(content: Content) -> some View {
        let palette = CristalPalette.of(style.id)
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius ?? palette.radius, style: .continuous)
        let solid = Color(hex: palette.hex("panelSolid", dark: dark))
        content
            .background {
                shape.fill(reduceTransparency ? solid : solid.opacity(dark ? 0.84 : 0.80))
                    .shadow(color: drawsShadow ? CristalPanelShadow.color(palette: palette, dark: dark) : .clear, radius: 12, y: 6)
            }
            .overlay { shape.strokeBorder(Color.white.opacity(dark ? 0.07 : 0.85), lineWidth: 1) }
    }
}

/// The light shadow of a panel, alone: for panels drawn inside something that clips them (the views of a card of Mon
/// Quotidien scroll in a pager, which cut their shadow square at the corners, 2026-11-22). The pager draws it once,
/// around the whole card, and only outside the card's shape (nothing is added under the panel itself).
private struct CristalPanelShadow: ViewModifier {
    let radius: CGFloat?
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    static func color(palette: CristalPalette, dark: Bool) -> Color {
        dark ? Color.black.opacity(0.28) : Color(hex: palette.hex("primary", dark: false)).opacity(0.07)
    }

    func body(content: Content) -> some View {
        let palette = CristalPalette.of(style.id)
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius ?? palette.radius, style: .continuous)
        content.background {
            shape.fill(Color.black)
                .shadow(color: Self.color(palette: palette, dark: dark), radius: 12, y: 6)
                // Only the shadow: the shape itself is cut out, so the panel above keeps exactly its own look.
                .mask {
                    Rectangle()
                        .padding(-40)
                        .overlay { shape.blendMode(.destinationOut) }
                        .compositingGroup()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct CristalPanelDrawsShadowKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False inside a view that clips its panels (a pager): the panels then draw no shadow of their own.
    var cristalPanelDrawsShadow: Bool {
        get { self[CristalPanelDrawsShadowKey.self] }
        set { self[CristalPanelDrawsShadowKey.self] = newValue }
    }
}

private struct CristalGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let palette = CristalPalette.of(style.id)
        let dark = scheme == .dark
        let shadow = dark ? Color.black.opacity(0.36) : Color(hex: palette.hex("primary", dark: false)).opacity(0.12)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(hex: palette.hex("panelSolid", dark: dark))).shadow(color: shadow, radius: 14, y: 10)
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Color.white.opacity(dark ? 0.09 : 0.55))
                    }
                    .shadow(color: shadow, radius: 14, y: 10)
                }
            }
            .overlay {
                shape.stroke(reduceTransparency ? Color(hex: palette.hex("rule", dark: dark)) : Color.white.opacity(dark ? 0.14 : 0.70), lineWidth: 1)
            }
    }
}

extension View {
    /// Panneau du contenu (carte) : presque opaque, liseré clair, ombre légère, ni matière ni flou.
    func cristalPanel(radius: CGFloat? = nil) -> some View {
        modifier(CristalPanelModifier(radius: radius))
    }

    /// Only the shadow of a panel, around this view (see `CristalPanelShadow`).
    func cristalPanelShadow(radius: CGFloat? = nil) -> some View {
        modifier(CristalPanelShadow(radius: radius))
    }

    /// Verre pour ce qui flotte (barre d'onglets, en-tête) : matière fine et voile clair.
    func cristalGlass<S: Shape>(in shape: S) -> some View {
        modifier(CristalGlassModifier(shape: shape))
    }
}
