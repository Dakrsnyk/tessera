import SwiftUI

/// The accent color of the app itself (buttons, selection, tint): ten Apple-inspired colors, each with
/// a light and a dark value. Backgrounds do not depend on it; widgets keep their own themes.
enum AppAccentID: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, indigo, purple, pink, gray
    var id: String { rawValue }

    var title: String {
        switch self {
        case .red: tr("Rouge")
        case .orange: tr("Orange")
        case .yellow: tr("Jaune")
        case .green: tr("Vert")
        case .teal: tr("Sarcelle")
        case .blue: tr("Bleu")
        case .indigo: tr("Indigo")
        case .purple: tr("Violet")
        case .pink: tr("Rose", context: "color")
        case .gray: tr("Gris")
        }
    }

    var lightHex: String {
        switch self {
        case .red: "FF3B30"
        case .orange: "FF9500"
        case .yellow: "FFCC00"
        case .green: "34C759"
        case .teal: "30B0C7"
        case .blue: "007AFF"
        case .indigo: "5856D6"
        case .purple: "AF52DE"
        case .pink: "FF2D55"
        case .gray: "8E8E93"
        }
    }

    var darkHex: String {
        switch self {
        case .red: "FF453A"
        case .orange: "FF9F0A"
        case .yellow: "FFD60A"
        case .green: "30D158"
        case .teal: "40C8E0"
        case .blue: "0A84FF"
        case .indigo: "5E5CE6"
        case .purple: "BF5AF2"
        case .pink: "FF375F"
        case .gray: "98989D"
        }
    }

    /// Follows light and dark mode by itself.
    var color: Color { Color(light: lightHex, dark: darkHex) }

    /// Text and symbols on an accent-colored fill: white (as Apple does), dark on yellow which is too light.
    var inkHex: String { self == .yellow ? "1A1408" : "FFFFFF" }
    var ink: Color { Color(hex: inkHex) }

    /// The accent that stands in for an old app style, for people who chose one before accents existed.
    static func migrated(from style: AppStyleID) -> AppAccentID {
        switch style {
        case .tessera: .teal
        case .ocean: .blue
        case .coral: .red
        case .lavender: .purple
        case .sand: .orange
        case .graphite: .gray
        case .forest: .green
        case .rose: .pink
        case .midnight: .indigo
        case .neon: .teal
        }
    }
}
