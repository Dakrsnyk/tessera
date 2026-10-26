import XCTest
@testable import Ardane

/// The alphabetical index of the Fitness progression (2026-10-16): each exercise under its first letter
/// without accent or case, a kana under its row, anything else under « # », sorted for the language.
final class SectionIndexTests: XCTestCase {
    private let french = Locale(identifier: "fr_CA")
    private let japanese = Locale(identifier: "ja_JP")

    func testFirstLetterIgnoresAccentsCaseAndSpaces() {
        XCTAssertEqual(SectionIndex.letter(for: "Élévations latérales"), "E")
        XCTAssertEqual(SectionIndex.letter(for: "écarté couché"), "E")
        XCTAssertEqual(SectionIndex.letter(for: "  squat (barre)"), "S")
        XCTAssertEqual(SectionIndex.letter(for: "Ängste"), "A")
        XCTAssertEqual(SectionIndex.letter(for: "Œil"), "O")
        XCTAssertEqual(SectionIndex.letter(for: "Ｐｕｌｌ"), "P")
    }

    func testOtherInitialsGoUnderNumberSign() {
        XCTAssertEqual(SectionIndex.letter(for: "21s curl"), "#")
        XCTAssertEqual(SectionIndex.letter(for: "« Curl »"), "#")
        XCTAssertEqual(SectionIndex.letter(for: "懸垂"), "#")
        XCTAssertEqual(SectionIndex.letter(for: "   "), "#")
    }

    func testKanaGoUnderTheirRow() {
        XCTAssertEqual(SectionIndex.letter(for: "スクワット"), "さ")
        XCTAssertEqual(SectionIndex.letter(for: "ベンチプレス"), "は")
        XCTAssertEqual(SectionIndex.letter(for: "ウォーキングランジ"), "あ")
        XCTAssertEqual(SectionIndex.letter(for: "ランジ"), "ら")
        XCTAssertEqual(SectionIndex.letter(for: "がんばる"), "か")
    }

    func testIndexRunsFromAToZThenNumberSign() {
        let letters = SectionIndex.letters(for: [], locale: french)
        XCTAssertEqual(letters.count, 27)
        XCTAssertEqual(letters.first, "A")
        XCTAssertEqual(letters.dropLast().last, "Z")
        XCTAssertEqual(letters.last, "#")
    }

    func testKanaRowsComeFirstInJapaneseOrWhenUsed() {
        XCTAssertEqual(SectionIndex.letters(for: [], locale: japanese).first, "あ")
        XCTAssertEqual(SectionIndex.letters(for: [], locale: japanese).count, 37)
        XCTAssertEqual(SectionIndex.letters(for: ["さ"], locale: french).first, "あ")
    }

    func testSectionsFollowTheIndexAndSortEachLetter() {
        let names = ["Squat (barre)", "élévations latérales", "Développé couché (barre)", "Écarté couché", "dips", "21s", "Fentes"]
        let sections = SectionIndex.sections(names, locale: french) { $0 }
        XCTAssertEqual(sections.map(\.letter), ["D", "E", "F", "S", "#"])
        XCTAssertEqual(sections[0].items, ["Développé couché (barre)", "dips"])
        XCTAssertEqual(sections[1].items, ["Écarté couché", "élévations latérales"])
        XCTAssertEqual(sections.flatMap(\.items).count, names.count, "every exercise keeps its place")
    }

    func testJapaneseNamesAreFiledByRow() {
        let sections = SectionIndex.sections(["スクワット", "ベンチプレス", "サイドレイズ"], locale: japanese) { $0 }
        XCTAssertEqual(sections.map(\.letter), ["さ", "は"])
        XCTAssertEqual(sections[0].items, ["サイドレイズ", "スクワット"])
    }
}
