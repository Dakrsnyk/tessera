import SwiftUI

struct AccentSwatch: Identifiable, Hashable {
    let name: String
    let hex: String
    var id: String { hex }
}

enum Palette {
    static let defaultAccent = "2F8F7A"

    /// Accent colors available to everyone. Any other color needs Premium.
    static let freeAccents: [AccentSwatch] = [
        AccentSwatch(name: "Jade", hex: "2F8F7A"),
        AccentSwatch(name: "Cobalt", hex: "3366FF"),
        AccentSwatch(name: "Corail", hex: "FF6B57"),
        AccentSwatch(name: "Ambre", hex: "F2A33A"),
        AccentSwatch(name: "Lilas", hex: "8C6CFF"),
        AccentSwatch(name: "Rose", hex: "F2588F"),
        AccentSwatch(name: "Olive", hex: "7FA33A"),
        AccentSwatch(name: "Ardoise", hex: "6B7280"),
    ]

    /// Flat background colors offered in the editor (Premium).
    static let backgrounds: [AccentSwatch] = [
        AccentSwatch(name: "Nuit", hex: "111318"),
        AccentSwatch(name: "Encre", hex: "1B2340"),
        AccentSwatch(name: "Forêt", hex: "163A30"),
        AccentSwatch(name: "Bordeaux", hex: "4A1628"),
        AccentSwatch(name: "Sable", hex: "E9DFCC"),
        AccentSwatch(name: "Brume", hex: "DDE3EA"),
        AccentSwatch(name: "Menthe", hex: "CFEBDD"),
        AccentSwatch(name: "Pêche", hex: "F9D5C5"),
        AccentSwatch(name: "Blanc", hex: "FFFFFF"),
        AccentSwatch(name: "Noir", hex: "000000"),
    ]

    static func name(for hex: String) -> String {
        (freeAccents + backgrounds).first { $0.hex == hex }?.name ?? "Personnalisée"
    }
}
