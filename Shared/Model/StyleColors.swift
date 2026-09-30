import Foundation

/// A complete set of colors applied at once: background, surfaces, text, numbers, icons, charts,
/// border, gains and losses, and the colors of lines and parts of a whole. Choosing one changes
/// every color of the widget; its style (shapes, text, layout) stays.
struct ColorPalette: Identifiable, Hashable {
    let id: String
    let name: String
    /// One color: a flat background. Two: a gradient from the first to the second.
    let background: [String]
    let panel: String
    let text: String
    let secondary: String
    let accent: String
    let number: String
    let chart: String
    let icon: String
    let border: String
    let positive: String
    let negative: String
    /// Given in turn to lines (macros, categories…) and parts of a whole.
    let series: [String]

    /// The colors shown on the palette's chip: its background, then its main colors.
    var swatches: [String] { [background[0], accent, chart, icon] }

    func applied(to design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.accentHex = accent
        if background.count > 1 {
            copy.background = .gradient
            copy.style.gradient = GradientSpec(startHex: background[0], endHex: background[1], direction: .diagonal)
        } else {
            copy.background = .color(background[0])
            copy.style.gradient = nil
        }
        copy.style.textHex = text
        copy.style.secondaryHex = secondary
        copy.style.numberHex = number
        copy.style.iconHex = icon
        copy.style.chartHex = chart
        copy.style.borderHex = border
        copy.style.shadowHex = nil
        copy.style.positiveHex = positive
        copy.style.negativeHex = negative
        copy.style.panelHex = panel
        copy.style.seriesHexes = series
        copy.style.rowColors = [:]
        copy.style.recolor = false
        return copy
    }

    func matches(_ design: WidgetDesign) -> Bool {
        design.accentHex == accent && design.style.textHex == text && design.style.chartHex == chart
            && design.style.panelHex == panel && design.style.seriesHexes == series
    }

    private static func make(_ id: String, _ name: String, background: [String], panel: String, text: String, secondary: String,
                             accent: String, number: String? = nil, chart: String? = nil, icon: String? = nil, border: String? = nil,
                             positive: String, negative: String, series: [String]) -> ColorPalette {
        ColorPalette(
            id: id, name: name, background: background, panel: panel, text: text, secondary: secondary,
            accent: accent, number: number ?? text, chart: chart ?? accent, icon: icon ?? accent, border: border ?? accent,
            positive: positive, negative: negative, series: series
        )
    }

    static let all: [ColorPalette] = [
        make("jade", "Jade", background: ["EEF7F3"], panel: "D9EEE5", text: "0F3029", secondary: "58786F",
             accent: "2F8F7A", icon: "3FA88F", positive: "1E8A4F", negative: "C9453F",
             series: ["2F8F7A", "5BB89F", "E0A458", "7A8FD6", "D46A6A", "9A7FC4"]),
        make("ocean", "Océan", background: ["0B3C5D", "06192B"], panel: "134A70", text: "EAF6FF", secondary: "93B8D2",
             accent: "22B8CF", number: "FFFFFF", icon: "5CC8FF", positive: "5BE0A0", negative: "FF8A8A",
             series: ["22B8CF", "5C9DFF", "7CE0C3", "FFD166", "FF8FA3", "B69CFF"]),
        make("coral", "Corail", background: ["FFF1EC"], panel: "FFDFD4", text: "3B1A12", secondary: "9A6A5E",
             accent: "FF6B57", chart: "FF6B57", icon: "FF8A5C", positive: "2E9E64", negative: "C8322F",
             series: ["FF6B57", "FF9A62", "FFC857", "6CC5B0", "8C6CFF", "4FA3E0"]),
        make("lavender", "Lavande", background: ["F4F0FF"], panel: "E4DAFF", text: "241A4A", secondary: "7A6EA3",
             accent: "8C6CFF", icon: "A58CFF", positive: "2E9E77", negative: "D6475E",
             series: ["8C6CFF", "B69CFF", "F2588F", "5AC8FA", "FFB547", "6FCF97"]),
        make("forest", "Forêt", background: ["15281C"], panel: "213B2A", text: "E8F1E4", secondary: "9DB59F",
             accent: "8FC45A", number: "F4FAEF", icon: "B5D98C", positive: "8FD694", negative: "F08A6C",
             series: ["8FC45A", "3F9D6A", "D9B44A", "C97B4A", "6FA8C9", "B8D98C"]),
        make("sand", "Sable", background: ["F5EDE1"], panel: "E9DAC3", text: "3A2A1A", secondary: "8C7358",
             accent: "B07A45", chart: "C98B4F", icon: "B07A45", positive: "4E8A4A", negative: "B5473A",
             series: ["B07A45", "D9A066", "7A8C5A", "A65E4A", "5E7A8C", "C9B27A"]),
        make("neon", "Néon", background: ["0B0416"], panel: "1C0C31", text: "FFE9F7", secondary: "B48AB0",
             accent: "FF2DAA", number: "00F0FF", chart: "00F0FF", icon: "FF2DAA", border: "FF2DAA",
             positive: "B6FF3B", negative: "FF5C7A",
             series: ["FF2DAA", "00F0FF", "B6FF3B", "FFE14D", "8C6CFF", "FF8A3D"]),
        make("candy", "Bonbon", background: ["FFF0F6"], panel: "FFDDEA", text: "4A1830", secondary: "9A6A80",
             accent: "F2588F", chart: "FFB547", icon: "5AC8FA", positive: "2E9E77", negative: "D6364B",
             series: ["F2588F", "FFB547", "5AC8FA", "8BD17C", "B69CFF", "FF8A5C"]),
        make("gold", "Or", background: ["1A1712", "070605"], panel: "2A241A", text: "F5E7C1", secondary: "A8946A",
             accent: "D4AF37", chart: "E6C35C", border: "D4AF37", positive: "C9D97A", negative: "E0876A",
             series: ["D4AF37", "E6C35C", "B08D57", "8C7A5B", "F5E7C1", "C9A227"]),
        make("mono", "Graphite", background: ["F2F3F5"], panel: "E1E4E8", text: "1F2328", secondary: "6B7280",
             accent: "4B5563", positive: "2F7D4F", negative: "B23A3A",
             series: ["4B5563", "9CA3AF", "1F2328", "6B7280", "C5CAD1", "374151"]),
        make("sunset", "Couchant", background: ["E8604C", "6A2C8E"], panel: "FFFFFF2E", text: "FFFFFF", secondary: "FFE6DA",
             accent: "FFD29D", number: "FFFFFF", chart: "FFE3B8", icon: "FFFFFF", border: "FFD29D", positive: "FFFFFF", negative: "FFE0E0",
             series: ["FFE3B8", "FFFFFF", "FFB4A2", "F9D56E", "E3B5FF", "FF8FA3"]),
        make("mint", "Menthe", background: ["ECFAF4"], panel: "D2F2E4", text: "0F3327", secondary: "5B8577",
             accent: "2DBE8D", icon: "36C99A", positive: "1E8A4F", negative: "D6475E",
             series: ["2DBE8D", "7CE0C3", "4FA3E0", "FFB547", "F2788F", "9A7FC4"]),
        make("midnight", "Minuit", background: ["0F172A"], panel: "1E293B", text: "E2E8F0", secondary: "94A3B8",
             accent: "60A5FA", number: "F8FAFC", icon: "93C5FD", positive: "34D399", negative: "F87171",
             series: ["60A5FA", "34D399", "FBBF24", "F472B6", "A78BFA", "22D3EE"]),
        make("cherry", "Cerise", background: ["2A0A12"], panel: "3D1420", text: "FFE8EC", secondary: "C99AA5",
             accent: "FF4D6D", number: "FFFFFF", icon: "FF8FA3", positive: "7ED9A4", negative: "FFB3C1",
             series: ["FF4D6D", "FF8FA3", "FFB547", "C9184A", "F9D56E", "B69CFF"]),
    ]

    static func palette(_ id: String) -> ColorPalette? { all.first { $0.id == id } }
}

extension WidgetDesign {
    /// The whole style in one main color: background, surfaces, text, charts, icons, border and lines
    /// all take its hue, each keeping the brightness the style gave it, so the widget stays readable.
    /// The colors set one by one (or by a palette) give way to it; they can be set again afterwards.
    func recolored(to hex: String) -> WidgetDesign {
        var copy = self
        copy.accentHex = hex
        var style = copy.style
        style.textHex = nil
        style.secondaryHex = nil
        style.numberHex = nil
        style.iconHex = nil
        style.chartHex = nil
        style.borderHex = nil
        style.shadowHex = nil
        style.panelHex = nil
        style.positiveHex = nil
        style.negativeHex = nil
        style.seriesHexes = []
        style.rowColors = [:]
        if let spec = style.gradient {
            style.gradient = GradientSpec(
                startHex: ColorMath.recolor(spec.startHex, to: hex, surface: true),
                endHex: ColorMath.recolor(spec.endHex, to: hex, surface: true),
                direction: spec.direction, intensity: spec.intensity
            )
        }
        style.recolor = true
        copy.style = style
        if case let .color(background) = copy.background {
            copy.background = .color(ColorMath.recolor(background, to: hex, surface: true))
        }
        return copy
    }

    /// Back to the style's own colors: no main color, palette or color picked one by one.
    /// A photo or glass background stays; a flat color or gradient gives way to the style's.
    func withStyleColors() -> WidgetDesign {
        var copy = self
        var style = copy.style
        style.textHex = nil
        style.secondaryHex = nil
        style.numberHex = nil
        style.iconHex = nil
        style.chartHex = nil
        style.borderHex = nil
        style.shadowHex = nil
        style.panelHex = nil
        style.positiveHex = nil
        style.negativeHex = nil
        style.seriesHexes = []
        style.rowColors = [:]
        style.recolor = false
        switch copy.background {
        case .color, .gradient:
            copy.background = .theme
            style.gradient = nil
        default:
            break
        }
        copy.style = style
        return copy
    }

    /// The look alone (style, colors, background, text), to give to other widgets made together.
    /// Each widget keeps its content: its name, options and the parts it hides.
    func withLook(of other: WidgetDesign) -> WidgetDesign {
        var copy = self
        copy.themeID = other.themeID
        copy.accentHex = other.accentHex
        // A photo belongs to one widget (deleting that widget deletes it): the others keep their background.
        if case .photo = other.background {} else { copy.background = other.background }
        copy.font = other.font
        copy.alignment = other.alignment
        var look = other.style.look
        look.hidden = style.hidden
        look.rowColors = style.rowColors
        copy.style = look
        return copy
    }
}
