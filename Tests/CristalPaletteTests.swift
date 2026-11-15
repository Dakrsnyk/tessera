import XCTest
@testable import Ardane

/// Les jetons Cristal calculés en Swift suivent la formule des maquettes (table de référence générée par cristal_reference.js).
@MainActor
final class CristalPaletteTests: XCTestCase {
    private func channels(_ hex: String) -> [Int] {
        let n = Int(UInt64(hex, radix: 16) ?? 0)
        return [(n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF]
    }

    func testTokensMatchTheReferenceTable() {
        for id in AppStyleID.allCases {
            let palette = CristalPalette.of(id)
            XCTAssertEqual(palette.seedID, CristalPaletteReference.seeds[id.rawValue], "\(id) : graine")
            for (mode, dark) in [("light", false), ("dark", true)] {
                let expected = CristalPaletteReference.tokens["\(id.rawValue).\(mode)"] ?? [:]
                XCTAssertFalse(expected.isEmpty, "\(id).\(mode) absent de la référence")
                for (token, want) in expected {
                    let got = palette.hex(token, dark: dark)
                    let close = zip(channels(want), channels(got)).allSatisfy { abs($0 - $1) <= 1 }
                    XCTAssertTrue(close, "\(id) \(mode) \(token) : attendu \(want), obtenu \(got)")
                }
                XCTAssertEqual((dark ? palette.dark : palette.light).count, expected.count, "\(id) \(mode) : nombre de jetons")
            }
        }
    }

    func testContrastsOfAllTwelveColors() {
        func cr(_ a: String, _ b: String) -> Double { CristalPalette.contrast(a, b) }
        for id in AppStyleID.allCases {
            let p = CristalPalette.of(id)
            let l = { (t: String) in p.hex(t, dark: false) }, d = { (t: String) in p.hex(t, dark: true) }
            XCTAssertGreaterThanOrEqual(cr("FFFFFF", l("primary")), 4.5, "\(id) clair : blanc sur primary")
            XCTAssertGreaterThanOrEqual(cr(l("ink"), l("panelSolid")), 7, "\(id) clair : ink sur panneau")
            XCTAssertGreaterThanOrEqual(cr(l("ink2"), l("bg")), 4.5, "\(id) clair : ink2 sur fond")
            XCTAssertGreaterThanOrEqual(cr(l("primary"), l("tint2")), 4.5, "\(id) clair : primary sur tint2")
            XCTAssertGreaterThanOrEqual(cr(d("onPrimary"), d("primary")), 4.5, "\(id) sombre : onPrimary sur primary")
            XCTAssertGreaterThanOrEqual(cr(d("ink2"), d("panelSolid")), 4.5, "\(id) sombre : ink2 sur carte")
            XCTAssertGreaterThanOrEqual(cr(d("primary"), d("tint2")), 4.5, "\(id) sombre : primary sur tint2")
            for k in CristalPalette.categoryKeys {
                XCTAssertGreaterThanOrEqual(cr(l("cat." + k), l("panelSolid")), 3.0, "\(id) clair : cat.\(k)")
                XCTAssertGreaterThanOrEqual(cr(l("strong." + k), "FFFFFF"), 4.5, "\(id) clair : strong.\(k)")
                XCTAssertGreaterThanOrEqual(cr(d("cat." + k), d("panelSolid")), 4.5, "\(id) sombre : cat.\(k)")
            }
        }
    }

    func testDarkBackgroundCardAndActionComeFromAppStyle() {
        for id in AppStyleID.allCases {
            let style = AppStyle.style(id), p = CristalPalette.of(id)
            XCTAssertEqual(p.hex("bg", dark: true), style.screenDark, "\(id)")
            XCTAssertEqual(p.hex("panelSolid", dark: true), style.cardDark, "\(id)")
            XCTAssertEqual(p.hex("primary", dark: true), style.accentDark, "\(id)")
        }
    }

    func testEachPaletteCarriesItsSeedShape() {
        for id in AppStyleID.allCases {
            let p = CristalPalette.of(id)
            XCTAssertEqual(p.washes.count, 2, "\(id) : deux nappes")
            XCTAssertEqual(p.radius, ["lavande", "rose", "peche"].contains(p.seedID) ? 28 : (p.seedID == "graphite" ? 22 : 26), "\(id) : rayon")
        }
        // Une saisie qui n'est pas un HEX (signe, longueur) se replie sur la couleur d'action au lieu d'être lue de travers.
        let p = CristalPalette.of(.sapphire)
        XCTAssertEqual(p.categoryHex("+ABCDE").light, p.categoryHex("zz").light)
    }

    func testAppCategoryColors() {
        for id in AppStyleID.allCases {
            let p = CristalPalette.of(id)
            // Un HEX connu de l'app donne la catégorie Cristal correspondante.
            let known = p.categoryHex("#f08a24")
            XCTAssertEqual(known.light, p.hex("cat.nut", dark: false), "\(id)")
            XCTAssertEqual(known.dark, p.hex("cat.nut", dark: true), "\(id)")
            // Inconnu ou invalide : toujours lisible.
            for text in ["8C6CFF", "zz"] {
                let c = p.categoryHex(text), s = p.strongHex(text)
                XCTAssertGreaterThanOrEqual(CristalPalette.contrast(c.light, "FFFFFF"), 3.0, "\(id) \(text) clair")
                XCTAssertGreaterThanOrEqual(CristalPalette.contrast(s.light, "FFFFFF"), 4.5, "\(id) \(text) fort clair")
                XCTAssertGreaterThanOrEqual(CristalPalette.contrast(c.dark, p.hex("panelSolid", dark: true)), 4.5, "\(id) \(text) sombre")
            }
        }
    }
}
