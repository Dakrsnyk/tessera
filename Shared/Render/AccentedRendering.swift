import SwiftUI
import WidgetKit

/// How a widget stays readable when iOS draws it without its colors. The « Clair » and « Teinté »
/// appearances of the Home Screen (iOS 18 and 26) render it `accented`: every element turns into one
/// tint (white, or the chosen tint for what is `widgetAccentable()`), keeping only its opacity, and the
/// widget's background is replaced by the system's glass. The iPad Lock Screen and StandBy at night render
/// it `vibrant`, where white reads best. A block filled with its color then becomes a solid white shape
/// and the white text on it disappears.
/// So, without colors, what carries text is filled lightly and outlined while the text stays opaque, the
/// parts of a whole differ by their opacity, and photos keep their own colors. In full color nothing changes.
enum AccentedStyle {
    /// Whether iOS draws the widget without its colors.
    static func isMonochrome(_ mode: WidgetRenderingMode) -> Bool {
        mode == .accented || mode == .vibrant
    }

    /// Secondary text: lighter than the main text, the hierarchy its color used to give.
    static let secondaryOpacity = 0.6
    /// Tracks, grid lines and empty cells.
    static let trackOpacity = 0.2
    /// Cards and panels behind the content.
    static let panelOpacity = 0.12
    /// The outline that draws the edge of a lightly filled shape.
    static let outlineOpacity = 0.55
    /// A photo behind text (a quote), desaturated and faint so the text on it stays readable.
    static let backdropPhotoOpacity = 0.35

    /// The opacity of a shape filled with a color: unchanged in color; without colors, light when text or
    /// a symbol sits on it (a block of the schedule, a button, a pill), a little more for the main action.
    static func fillOpacity(isMonochrome: Bool, carriesText: Bool = true, isProminent: Bool = false) -> Double {
        guard isMonochrome, carriesText else { return 1 }
        return isProminent ? 0.35 : 0.22
    }

    /// Whether a filled shape gets an outline: only without colors, when it is lightly filled.
    static func outlines(isMonochrome: Bool, carriesText: Bool = true) -> Bool {
        isMonochrome && carriesText
    }

    /// The opacity of the n-th part of a whole (spending categories, macros): in color each part has its
    /// own color; without colors, they step between full and faint so that neighbors stay apart.
    static func partOpacity(at index: Int, isMonochrome: Bool) -> Double {
        guard isMonochrome else { return 1 }
        let steps = [1, 0.6, 0.35, 0.8, 0.5, 0.25]
        return steps[(index % steps.count + steps.count) % steps.count]
    }

    /// The ring of something still to do (a habit not done today): as before in color; without colors,
    /// fainter and thinner than the outline of what is done, so done stays the stronger state.
    static func pendingRingOpacity(isMonochrome: Bool) -> Double {
        isMonochrome ? trackOpacity : 0.7
    }

    static func pendingRingWidth(isMonochrome: Bool) -> CGFloat {
        isMonochrome ? 1 : 2
    }

    /// The days gone by of « L'année en points »: without colors, today (full) must stand out from them.
    static func elapsedOpacity(isMonochrome: Bool) -> Double {
        isMonochrome ? 0.45 : 0.85
    }
}

extension ResolvedStyle {
    /// The style as iOS draws it in `mode`: as designed in full color; without colors, white in an opacity
    /// hierarchy (all iOS keeps), lightly filled panels, no shadow (it would turn into a white halo) and
    /// layered symbols rather than multicolor ones.
    func rendered(for mode: WidgetRenderingMode) -> ResolvedStyle {
        guard AccentedStyle.isMonochrome(mode) else { return self }
        var style = self
        style.isAccented = true
        style.primary = .white
        style.secondary = Color.white.opacity(AccentedStyle.secondaryOpacity)
        style.accent = .white
        style.onAccent = .white
        style.numberColor = .white
        style.icon = .white
        style.chart = .white
        style.positive = .white
        style.negative = .white
        style.track = Color.white.opacity(AccentedStyle.trackOpacity)
        style.panel = Color.white.opacity(AccentedStyle.panelOpacity)
        style.borderColor = Color.white.opacity(style.options.borderOpacity)
        style.shadowColor = .clear
        style.prefersMulticolorSymbols = false
        style.options.depth = .none
        return style
    }

    /// The chart color, or `hex` (a widget's own default) unless the person picked a chart color or recolored the
    /// widget; without colors it stays white.
    func chartColor(default hex: String?) -> Color {
        guard let hex, !isAccented, options.chartHex == nil, !options.recolor else { return chart }
        return Color(hex: hex)
    }

    /// The color of the n-th part of a whole: its own in color, a step of opacity without colors.
    func partColor(_ hex: String, at index: Int) -> Color {
        isAccented ? Color.white.opacity(AccentedStyle.partOpacity(at: index, isMonochrome: true)) : Color(hex: hex)
    }
}

extension InsettableShape {
    /// Fills a shape that text or a symbol sits on (a block of the schedule, a button, a pill, today's
    /// circle): in its color, as always; without colors, lightly and outlined, so what is on it stays readable.
    @ViewBuilder
    func textBackdrop(_ color: Color, isAccented: Bool, isProminent: Bool = false) -> some View {
        if AccentedStyle.outlines(isMonochrome: isAccented) {
            self.fill(Color.white.opacity(AccentedStyle.fillOpacity(isMonochrome: true, isProminent: isProminent)))
                .overlay {
                    self.strokeBorder(Color.white.opacity(AccentedStyle.outlineOpacity), lineWidth: 1)
                }
        } else {
            self.fill(color)
        }
    }
}
