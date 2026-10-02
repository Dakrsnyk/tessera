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
        AccentSwatch(name: tr("Jade"), hex: "2F8F7A"),
        AccentSwatch(name: tr("Cobalt"), hex: "3366FF"),
        AccentSwatch(name: tr("Corail"), hex: "FF6B57"),
        AccentSwatch(name: tr("Ambre"), hex: "F2A33A"),
        AccentSwatch(name: tr("Lilas"), hex: "8C6CFF"),
        AccentSwatch(name: tr("Rose"), hex: "F2588F"),
        AccentSwatch(name: tr("Olive"), hex: "7FA33A"),
        AccentSwatch(name: tr("Ardoise"), hex: "6B7280"),
    ]

    /// Flat background colors offered in the editor (Premium).
    static let backgrounds: [AccentSwatch] = [
        AccentSwatch(name: tr("Nuit"), hex: "111318"),
        AccentSwatch(name: tr("Encre"), hex: "1B2340"),
        AccentSwatch(name: tr("Forêt"), hex: "163A30"),
        AccentSwatch(name: tr("Bordeaux"), hex: "4A1628"),
        AccentSwatch(name: tr("Sable"), hex: "E9DFCC"),
        AccentSwatch(name: tr("Brume"), hex: "DDE3EA"),
        AccentSwatch(name: tr("Menthe"), hex: "CFEBDD"),
        AccentSwatch(name: tr("Pêche"), hex: "F9D5C5"),
        AccentSwatch(name: tr("Blanc"), hex: "FFFFFF"),
        AccentSwatch(name: tr("Noir"), hex: "000000"),
    ]

    static func name(for hex: String) -> String {
        (freeAccents + backgrounds).first { $0.hex == hex }?.name ?? tr("Personnalisée")
    }
}
