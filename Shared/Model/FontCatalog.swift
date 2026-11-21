import SwiftUI
#if canImport(UIKit)
import CoreText
import UIKit
#endif

/// The kinds of fonts of the Studio's « Texte » tab.
enum FontCategory: String, CaseIterable, Identifiable {
    case sans, serif, script, fun, typewriter, condensed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sans: tr("Sans empattement")
        case .serif: tr("Serif")
        case .script: tr("Écriture et lettres attachées")
        case .fun: tr("Fantaisie")
        case .typewriter: tr("Machine à écrire et mono")
        case .condensed: tr("Condensées")
        }
    }
}

/// One font a widget can use. Only fonts that iOS itself brings are listed: they work in the widgets with nothing to
/// bundle (no license to carry, no weight added to the app), in every language the font covers.
struct FontEntry: Identifiable, Hashable {
    /// The PostScript name of the face, which is also what is stored in `StyleOptions.fontName`.
    let id: String
    /// The name shown (the font's own name).
    let name: String
    let category: FontCategory
    /// The bold face used for numbers and titles (nil: the face is its own, kept as it is).
    let boldID: String?

    init(_ name: String, _ id: String, _ category: FontCategory, bold: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.boldID = bold
    }
}

enum FontCatalog {
    /// Registers the free fonts of `Shared/Fonts` (copied in the app and in the widgets) for this process, once: the
    /// app and the widget extension each do it the first time a font is asked for, so a widget draws the font the
    /// Studio showed. No Info.plist entry is needed, and a missing file only leaves its font out of `available`.
    private static let registration: Void = {
        #if canImport(UIKit)
        guard let root = Bundle.main.resourceURL,
              let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        let urls = files.compactMap { $0 as? URL }.filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontsForURLs(urls as CFArray, .process, nil)
        #endif
    }()

    /// Whether a face is installed on this device (iOS's own, or one of the bundled fonts).
    static func isInstalled(_ postScriptName: String) -> Bool {
        #if canImport(UIKit)
        _ = registration
        return UIFont(name: postScriptName, size: 12) != nil
        #else
        return true
        #endif
    }

    /// Every font Ardane knows: the ones iOS brings, then the free fonts bundled with the app (`FontCatalogBundled`).
    /// A face that is not there (an iOS version without it, a file not copied) is simply left out of `available`.
    static let candidates: [FontEntry] = sans + condensed + serif + script + fun + typewriter + bundled

    /// The fonts this iPhone has, in the order they are shown.
    static let available: [FontEntry] = candidates.filter { isInstalled($0.id) }

    static func entry(for id: String?) -> FontEntry? {
        guard let id else { return nil }
        return candidates.first { $0.id == id && isInstalled($0.id) }
    }

    static func fonts(in category: FontCategory?) -> [FontEntry] {
        guard let category else { return available }
        return available.filter { $0.category == category }
    }

    /// A face at a size that follows the widget (never the Dynamic Type of the app). The bold one when asked and
    /// when the font has one.
    static func font(_ entry: FontEntry, size: CGFloat, bold: Bool) -> Font {
        if bold, let boldID = entry.boldID, isInstalled(boldID) {
            return .custom(boldID, fixedSize: size)
        }
        return .custom(entry.id, fixedSize: size)
    }

    /// Whether a weight asks for a bold face.
    static func isBold(_ weight: Font.Weight) -> Bool {
        weight == .semibold || weight == .bold || weight == .heavy || weight == .black
    }

    // MARK: Sans serif

    private static let sans: [FontEntry] = [
        FontEntry("Arial", "ArialMT", .sans, bold: "Arial-BoldMT"),
        FontEntry("Arial Bold", "Arial-BoldMT", .sans),
        FontEntry("Arial Italic", "Arial-ItalicMT", .sans, bold: "Arial-BoldItalicMT"),
        FontEntry("Arial Rounded Bold", "ArialRoundedMTBold", .sans),
        FontEntry("Arial Hebrew", "ArialHebrew", .sans, bold: "ArialHebrew-Bold"),
        FontEntry("Helvetica", "Helvetica", .sans, bold: "Helvetica-Bold"),
        FontEntry("Helvetica Light", "Helvetica-Light", .sans, bold: "Helvetica-Bold"),
        FontEntry("Helvetica Oblique", "Helvetica-Oblique", .sans, bold: "Helvetica-BoldOblique"),
        FontEntry("Helvetica Neue", "HelveticaNeue", .sans, bold: "HelveticaNeue-Bold"),
        FontEntry("Helvetica Neue Light", "HelveticaNeue-Light", .sans, bold: "HelveticaNeue-Medium"),
        FontEntry("Helvetica Neue Thin", "HelveticaNeue-Thin", .sans, bold: "HelveticaNeue-Medium"),
        FontEntry("Helvetica Neue UltraLight", "HelveticaNeue-UltraLight", .sans, bold: "HelveticaNeue-Bold"),
        FontEntry("Helvetica Neue Medium", "HelveticaNeue-Medium", .sans, bold: "HelveticaNeue-Bold"),
        FontEntry("Helvetica Neue Bold", "HelveticaNeue-Bold", .sans),
        FontEntry("Helvetica Neue Italic", "HelveticaNeue-Italic", .sans, bold: "HelveticaNeue-BoldItalic"),
        FontEntry("Avenir Book", "Avenir-Book", .sans, bold: "Avenir-Heavy"),
        FontEntry("Avenir Light", "Avenir-Light", .sans, bold: "Avenir-Heavy"),
        FontEntry("Avenir Medium", "Avenir-Medium", .sans, bold: "Avenir-Black"),
        FontEntry("Avenir Heavy", "Avenir-Heavy", .sans),
        FontEntry("Avenir Black", "Avenir-Black", .sans),
        FontEntry("Avenir Oblique", "Avenir-BookOblique", .sans, bold: "Avenir-HeavyOblique"),
        FontEntry("Avenir Next", "AvenirNext-Regular", .sans, bold: "AvenirNext-Bold"),
        FontEntry("Avenir Next Medium", "AvenirNext-Medium", .sans, bold: "AvenirNext-Bold"),
        FontEntry("Avenir Next Demi Bold", "AvenirNext-DemiBold", .sans, bold: "AvenirNext-Heavy"),
        FontEntry("Avenir Next Bold", "AvenirNext-Bold", .sans),
        FontEntry("Avenir Next Heavy", "AvenirNext-Heavy", .sans),
        FontEntry("Avenir Next Ultra Light", "AvenirNext-UltraLight", .sans, bold: "AvenirNext-Bold"),
        FontEntry("Avenir Next Italic", "AvenirNext-Italic", .sans, bold: "AvenirNext-BoldItalic"),
        FontEntry("Futura", "Futura-Medium", .sans, bold: "Futura-Bold"),
        FontEntry("Futura Bold", "Futura-Bold", .sans),
        FontEntry("Futura Italic", "Futura-MediumItalic", .sans),
        FontEntry("Gill Sans", "GillSans", .sans, bold: "GillSans-Bold"),
        FontEntry("Gill Sans Light", "GillSans-Light", .sans, bold: "GillSans-SemiBold"),
        FontEntry("Gill Sans Semi Bold", "GillSans-SemiBold", .sans, bold: "GillSans-UltraBold"),
        FontEntry("Gill Sans Ultra Bold", "GillSans-UltraBold", .sans),
        FontEntry("Gill Sans Italic", "GillSans-Italic", .sans, bold: "GillSans-BoldItalic"),
        FontEntry("Optima", "Optima-Regular", .sans, bold: "Optima-Bold"),
        FontEntry("Optima Italic", "Optima-Italic", .sans, bold: "Optima-BoldItalic"),
        FontEntry("Optima Extra Black", "Optima-ExtraBlack", .sans),
        FontEntry("Verdana", "Verdana", .sans, bold: "Verdana-Bold"),
        FontEntry("Verdana Italic", "Verdana-Italic", .sans, bold: "Verdana-BoldItalic"),
        FontEntry("Trebuchet MS", "TrebuchetMS", .sans, bold: "TrebuchetMS-Bold"),
        FontEntry("Trebuchet MS Italic", "TrebuchetMS-Italic", .sans, bold: "Trebuchet-BoldItalic"),
        FontEntry("Galvji", "Galvji", .sans, bold: "Galvji-Bold"),
        FontEntry("Euphemia", "EuphemiaUCAS", .sans, bold: "EuphemiaUCAS-Bold"),
        FontEntry("Euphemia Italic", "EuphemiaUCAS-Italic", .sans),
        FontEntry("Marion", "Marion-Regular", .sans, bold: "Marion-Bold"),
        FontEntry("Thonburi", "Thonburi", .sans, bold: "Thonburi-Bold"),
        FontEntry("Thonburi Light", "Thonburi-Light", .sans, bold: "Thonburi-Bold"),
        FontEntry("Al Nile", "AlNile", .sans, bold: "AlNile-Bold"),
        FontEntry("Apple SD Gothic Neo", "AppleSDGothicNeo-Regular", .sans, bold: "AppleSDGothicNeo-Bold"),
        FontEntry("Apple SD Gothic Neo Thin", "AppleSDGothicNeo-Thin", .sans, bold: "AppleSDGothicNeo-SemiBold"),
        FontEntry("Apple SD Gothic Neo Light", "AppleSDGothicNeo-Light", .sans, bold: "AppleSDGothicNeo-SemiBold"),
        FontEntry("Apple SD Gothic Neo Medium", "AppleSDGothicNeo-Medium", .sans, bold: "AppleSDGothicNeo-Bold"),
        FontEntry("Apple SD Gothic Neo Extra Bold", "AppleSDGothicNeo-ExtraBold", .sans),
        FontEntry("Hiragino Sans", "HiraginoSans-W3", .sans, bold: "HiraginoSans-W6"),
        FontEntry("Hiragino Sans Bold", "HiraginoSans-W7", .sans),
        FontEntry("Hiragino Maru Gothic", "HiraMaruProN-W4", .sans),
    ]

    // MARK: Condensed

    private static let condensed: [FontEntry] = [
        FontEntry("Avenir Next Condensed", "AvenirNextCondensed-Regular", .condensed, bold: "AvenirNextCondensed-Bold"),
        FontEntry("Avenir Next Condensed Medium", "AvenirNextCondensed-Medium", .condensed, bold: "AvenirNextCondensed-Bold"),
        FontEntry("Avenir Next Condensed Demi Bold", "AvenirNextCondensed-DemiBold", .condensed, bold: "AvenirNextCondensed-Heavy"),
        FontEntry("Avenir Next Condensed Bold", "AvenirNextCondensed-Bold", .condensed),
        FontEntry("Avenir Next Condensed Heavy", "AvenirNextCondensed-Heavy", .condensed),
        FontEntry("Avenir Next Condensed Ultra Light", "AvenirNextCondensed-UltraLight", .condensed, bold: "AvenirNextCondensed-Bold"),
        FontEntry("Futura Condensed", "Futura-CondensedMedium", .condensed, bold: "Futura-CondensedExtraBold"),
        FontEntry("Futura Condensed Extra Bold", "Futura-CondensedExtraBold", .condensed),
        FontEntry("Helvetica Neue Condensed Bold", "HelveticaNeue-CondensedBold", .condensed),
        FontEntry("Helvetica Neue Condensed Black", "HelveticaNeue-CondensedBlack", .condensed),
        FontEntry("DIN Alternate Bold", "DINAlternate-Bold", .condensed),
        FontEntry("DIN Condensed Bold", "DINCondensed-Bold", .condensed),
        FontEntry("American Typewriter Condensed", "AmericanTypewriter-Condensed", .condensed, bold: "AmericanTypewriter-CondensedBold"),
        FontEntry("American Typewriter Condensed Bold", "AmericanTypewriter-CondensedBold", .condensed),
        FontEntry("Papyrus Condensed", "Papyrus-Condensed", .condensed),
    ]

    // MARK: Serif

    private static let serif: [FontEntry] = [
        FontEntry("Times New Roman", "TimesNewRomanPSMT", .serif, bold: "TimesNewRomanPS-BoldMT"),
        FontEntry("Times New Roman Italic", "TimesNewRomanPS-ItalicMT", .serif, bold: "TimesNewRomanPS-BoldItalicMT"),
        FontEntry("Georgia", "Georgia", .serif, bold: "Georgia-Bold"),
        FontEntry("Georgia Italic", "Georgia-Italic", .serif, bold: "Georgia-BoldItalic"),
        FontEntry("Palatino", "Palatino-Roman", .serif, bold: "Palatino-Bold"),
        FontEntry("Palatino Italic", "Palatino-Italic", .serif, bold: "Palatino-BoldItalic"),
        FontEntry("Baskerville", "Baskerville", .serif, bold: "Baskerville-Bold"),
        FontEntry("Baskerville Semi Bold", "Baskerville-SemiBold", .serif, bold: "Baskerville-Bold"),
        FontEntry("Baskerville Italic", "Baskerville-Italic", .serif, bold: "Baskerville-BoldItalic"),
        FontEntry("Cochin", "Cochin", .serif, bold: "Cochin-Bold"),
        FontEntry("Cochin Italic", "Cochin-Italic", .serif, bold: "Cochin-BoldItalic"),
        FontEntry("Didot", "Didot", .serif, bold: "Didot-Bold"),
        FontEntry("Didot Italic", "Didot-Italic", .serif),
        FontEntry("Hoefler Text", "HoeflerText-Regular", .serif, bold: "HoeflerText-Black"),
        FontEntry("Hoefler Text Black", "HoeflerText-Black", .serif),
        FontEntry("Hoefler Text Italic", "HoeflerText-Italic", .serif, bold: "HoeflerText-BlackItalic"),
        FontEntry("Charter", "Charter-Roman", .serif, bold: "Charter-Bold"),
        FontEntry("Charter Black", "Charter-Black", .serif),
        FontEntry("Charter Italic", "Charter-Italic", .serif, bold: "Charter-BoldItalic"),
        FontEntry("Iowan Old Style", "IowanOldStyle-Roman", .serif, bold: "IowanOldStyle-Bold"),
        FontEntry("Iowan Old Style Italic", "IowanOldStyle-Italic", .serif, bold: "IowanOldStyle-BoldItalic"),
        FontEntry("Iowan Old Style Black", "IowanOldStyle-Black", .serif),
        FontEntry("Bodoni 72", "BodoniSvtyTwoITCTT-Book", .serif, bold: "BodoniSvtyTwoITCTT-Bold"),
        FontEntry("Bodoni 72 Bold", "BodoniSvtyTwoITCTT-Bold", .serif),
        FontEntry("Bodoni 72 Italic", "BodoniSvtyTwoITCTT-BookIta", .serif),
        FontEntry("Bodoni 72 Oldstyle", "BodoniSvtyTwoOSITCTT-Book", .serif, bold: "BodoniSvtyTwoOSITCTT-Bold"),
        FontEntry("Bodoni 72 Small Caps", "BodoniSvtyTwoSCITCTT-Book", .serif),
        FontEntry("Rockwell", "Rockwell-Regular", .serif, bold: "Rockwell-Bold"),
        FontEntry("Rockwell Italic", "Rockwell-Italic", .serif, bold: "Rockwell-BoldItalic"),
        FontEntry("Superclarendon", "Superclarendon-Regular", .serif, bold: "Superclarendon-Bold"),
        FontEntry("Superclarendon Light", "Superclarendon-Light", .serif, bold: "Superclarendon-Bold"),
        FontEntry("Superclarendon Black", "Superclarendon-Black", .serif),
        FontEntry("Copperplate", "Copperplate", .serif, bold: "Copperplate-Bold"),
        FontEntry("Copperplate Light", "Copperplate-Light", .serif, bold: "Copperplate-Bold"),
        FontEntry("Academy Engraved", "AcademyEngravedLetPlain", .serif),
        FontEntry("Hiragino Mincho", "HiraMinProN-W3", .serif, bold: "HiraMinProN-W6"),
    ]

    // MARK: Script and handwriting

    private static let script: [FontEntry] = [
        FontEntry("Snell Roundhand", "SnellRoundhand", .script, bold: "SnellRoundhand-Bold"),
        FontEntry("Snell Roundhand Bold", "SnellRoundhand-Bold", .script),
        FontEntry("Snell Roundhand Black", "SnellRoundhand-Black", .script),
        FontEntry("Zapfino", "Zapfino", .script),
        FontEntry("Savoye", "SavoyeLetPlain", .script),
        FontEntry("Bradley Hand", "BradleyHandITCTT-Bold", .script),
        FontEntry("Noteworthy Light", "Noteworthy-Light", .script, bold: "Noteworthy-Bold"),
        FontEntry("Noteworthy Bold", "Noteworthy-Bold", .script),
        FontEntry("Marker Felt Thin", "MarkerFelt-Thin", .script, bold: "MarkerFelt-Wide"),
        FontEntry("Marker Felt Wide", "MarkerFelt-Wide", .script),
        FontEntry("Chalkboard Light", "ChalkboardSE-Light", .script, bold: "ChalkboardSE-Bold"),
        FontEntry("Chalkboard", "ChalkboardSE-Regular", .script, bold: "ChalkboardSE-Bold"),
        FontEntry("Chalkboard Bold", "ChalkboardSE-Bold", .script),
        FontEntry("Sign Painter", "SignPainter-HouseScript", .script, bold: "SignPainter-HouseScriptSemibold"),
        FontEntry("Sign Painter Semibold", "SignPainter-HouseScriptSemibold", .script),
    ]

    // MARK: Fun

    private static let fun: [FontEntry] = [
        FontEntry("Chalkduster", "Chalkduster", .fun),
        FontEntry("Papyrus", "Papyrus", .fun),
        FontEntry("Party", "PartyLetPlain", .fun),
    ]

    // MARK: Typewriter and monospaced

    private static let typewriter: [FontEntry] = [
        FontEntry("American Typewriter", "AmericanTypewriter", .typewriter, bold: "AmericanTypewriter-Bold"),
        FontEntry("American Typewriter Light", "AmericanTypewriter-Light", .typewriter, bold: "AmericanTypewriter-Semibold"),
        FontEntry("American Typewriter Semibold", "AmericanTypewriter-Semibold", .typewriter, bold: "AmericanTypewriter-Bold"),
        FontEntry("American Typewriter Bold", "AmericanTypewriter-Bold", .typewriter),
        FontEntry("Courier", "Courier", .typewriter, bold: "Courier-Bold"),
        FontEntry("Courier Oblique", "Courier-Oblique", .typewriter, bold: "Courier-BoldOblique"),
        FontEntry("Courier New", "CourierNewPSMT", .typewriter, bold: "CourierNewPS-BoldMT"),
        FontEntry("Courier New Italic", "CourierNewPS-ItalicMT", .typewriter, bold: "CourierNewPS-BoldItalicMT"),
        FontEntry("Menlo", "Menlo-Regular", .typewriter, bold: "Menlo-Bold"),
        FontEntry("Menlo Italic", "Menlo-Italic", .typewriter, bold: "Menlo-BoldItalic"),
    ]
}
