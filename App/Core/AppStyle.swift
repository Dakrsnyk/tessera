import SwiftUI

/// The colors of one app style, in light and dark. Widgets keep their own themes.
struct AppStyle: Identifiable {
    let id: AppStyleID
    let tagline: String
    let accentLight: String
    let accentDark: String
    /// Screen background (behind cards and lists).
    let screenLight: String
    let screenDark: String
    /// Cards: white in light mode, a dark tint of the style in dark mode.
    let cardDark: String
    /// Text on an accent-colored fill, when the accent is too light for white.
    var inkOnDarkAccent = "FFFFFF"
    var fontDesign: Font.Design = .default

    var name: String { id.title }
    var accent: Color { Color(light: accentLight, dark: accentDark) }
    var screen: Color { Color(light: screenLight, dark: screenDark) }
    var card: Color { Color(light: "FFFFFF", dark: cardDark) }
    var onAccent: Color { Color(light: "FFFFFF", dark: inkOnDarkAccent) }

    static let all: [AppStyle] = [
        AppStyle(id: .tessera, tagline: "Jade et crème, l'original", accentLight: "2F8F7A", accentDark: "3FA58D",
                 screenLight: "F3F1EC", screenDark: "0A0F0D", cardDark: "17201D"),
        AppStyle(id: .ocean, tagline: "Bleu franc, net et calme", accentLight: "2563EB", accentDark: "4F80FF",
                 screenLight: "EEF2F9", screenDark: "070B16", cardDark: "141B2B"),
        AppStyle(id: .coral, tagline: "Chaleureux et vivant", accentLight: "E4533D", accentDark: "F26A55",
                 screenLight: "FBF0EC", screenDark: "110A08", cardDark: "231815", fontDesign: .rounded),
        AppStyle(id: .lavender, tagline: "Doux et rêveur", accentLight: "6D4AE8", accentDark: "8B6DFF",
                 screenLight: "F2F0FA", screenDark: "0B0914", cardDark: "1A1727", fontDesign: .rounded),
        AppStyle(id: .sand, tagline: "Doré, comme un soir d'été", accentLight: "A26A18", accentDark: "E3AC4F",
                 screenLight: "F6F0E5", screenDark: "0F0C07", cardDark: "221D14", inkOnDarkAccent: "1A1408"),
        AppStyle(id: .graphite, tagline: "Noir et blanc, sans détour", accentLight: "1C1C1E", accentDark: "D1D1D6",
                 screenLight: "F2F2F4", screenDark: "000000", cardDark: "1C1C1E", inkOnDarkAccent: "000000"),
        AppStyle(id: .forest, tagline: "Vert profond et naturel", accentLight: "2B7A4B", accentDark: "3F9A63",
                 screenLight: "EEF3EE", screenDark: "070D09", cardDark: "16201A"),
        AppStyle(id: .rose, tagline: "Tendre et affirmé", accentLight: "D13F72", accentDark: "E8588B",
                 screenLight: "FBEFF3", screenDark: "12080C", cardDark: "24161C", fontDesign: .rounded),
        AppStyle(id: .midnight, tagline: "Indigo, pour les couche-tard", accentLight: "4B46C8", accentDark: "7571F2",
                 screenLight: "EFEFF8", screenDark: "06061A", cardDark: "15152E"),
        AppStyle(id: .neon, tagline: "Cyan électrique sur fond nuit", accentLight: "0086A8", accentDark: "22D3EE",
                 screenLight: "EDF6F8", screenDark: "04080F", cardDark: "111C24", inkOnDarkAccent: "03161C"),
    ]

    static func style(_ id: AppStyleID) -> AppStyle {
        all.first { $0.id == id } ?? all[0]
    }

    /// The style every screen draws with. Updated by the model before any view reads the new settings,
    /// and each tab is rebuilt when it changes (see `MainTabView`).
    static var current: AppStyle = style(SharedStore.shared.settings.appStyle)
}

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Color {
    static var screenFill: Color { AppStyle.current.screen }
    static var cardFill: Color { AppStyle.current.card }
    /// Text and symbols drawn on an accent-colored fill.
    static var onAccent: Color { AppStyle.current.onAccent }
}

extension View {
    /// Applies the chosen style: accent, font and light or dark mode.
    func appStyle(_ settings: AppSettings) -> some View {
        let style = AppStyle.style(settings.appStyle)
        return self
            .tint(style.accent)
            .accentColor(style.accent)
            .fontDesign(style.fontDesign)
            .preferredColorScheme(settings.appearance.colorScheme)
    }

    /// Lists and forms on the style's background instead of the system gray.
    func styledList() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.screenFill)
    }
}
