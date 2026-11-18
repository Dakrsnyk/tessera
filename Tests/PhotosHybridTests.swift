import XCTest
@testable import Ardane

/// « Photos et citations » direction 5 (refonte du 2026-11-17): « Mes textes » (one text per line or per paragraph,
/// a list kept to a sane size), « Un par jour » (day N of M, a shuffle made once, the change at midnight), and
/// the older saved widgets that read as before. No translated text is compared: the tests run in the simulator's language.
final class PhotosHybridTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Cutting the texts

    func testALineIsOneText() {
        let result = TextImport.parse("Un\n\n  Deux  \r\nTrois\n", by: .line)
        XCTAssertEqual(result.texts, ["Un", "Deux", "Trois"])
        XCTAssertEqual(result.cut, 0)
        XCTAssertEqual(result.left, 0)
    }

    func testAParagraphIsOneTextEvenOnSeveralLines() {
        let result = TextImport.parse("Un début\nqui continue\n\n\nDeuxième\n\n   \nTroisième\nsur deux lignes", by: .paragraph)
        XCTAssertEqual(result.texts, ["Un début qui continue", "Deuxième", "Troisième sur deux lignes"])
    }

    func testNothingFoundInEmptyOrBlankText() {
        XCTAssertTrue(TextImport.parse("", by: .line).texts.isEmpty)
        XCTAssertTrue(TextImport.parse(" \n \n\t", by: .paragraph).texts.isEmpty)
    }

    func testAListIsKeptToTwoThousandTextsAndEachTextToTheLengthOfAQuote() {
        let many = (1...(TextImport.maxTexts + 5)).map { "Texte \($0)" }.joined(separator: "\n")
        let result = TextImport.parse(many, by: .line)
        XCTAssertEqual(result.texts.count, TextImport.maxTexts)
        XCTAssertEqual(result.left, 5)
        let long = String(repeating: "a", count: TextImport.maxLength + 40)
        let cut = TextImport.parse(long, by: .line)
        XCTAssertEqual(cut.texts.first?.count, TextImport.maxLength)
        XCTAssertEqual(cut.cut, 1)
    }

    // MARK: Day N of M

    func testDayTwelveOfThreeSixtyFive() {
        let rotation = DailyRotation(startDay: date(11, 1, 0), seed: 1)
        let position = rotation.position(count: 365, on: date(11, 12))
        XCTAssertEqual(position?.day, 12)
        XCTAssertEqual(position?.total, 365)
        XCTAssertEqual(position?.index, 11, "In order: the twelfth text is the one at index 11")
        XCTAssertEqual(rotation.position(count: 365, on: date(11, 1, 0, 5))?.day, 1, "The first day, just after midnight")
    }

    func testBeforeTheStartTheFirstOneIsShown() {
        let rotation = DailyRotation(startDay: date(11, 20), seed: 1)
        XCTAssertFalse(rotation.hasStarted(on: date(11, 12)))
        XCTAssertEqual(rotation.position(count: 10, on: date(11, 12))?.day, 1)
        XCTAssertEqual(rotation.position(count: 10, on: date(11, 12))?.index, 0)
        XCTAssertTrue(rotation.hasStarted(on: date(11, 20, 0, 1)))
    }

    func testAfterTheLastOneTheListStartsAgain() {
        let rotation = DailyRotation(startDay: date(11, 1), seed: 1)
        XCTAssertEqual(rotation.position(count: 3, on: date(11, 3))?.day, 3)
        XCTAssertEqual(rotation.position(count: 3, on: date(11, 4))?.day, 1)
        XCTAssertEqual(rotation.position(count: 3, on: date(11, 5))?.index, 1)
    }

    func testNothingToShowForAnEmptyList() {
        XCTAssertNil(DailyRotation(startDay: date(11, 1), seed: 1).position(count: 0, on: date(11, 2)))
    }

    // MARK: The shuffle

    func testTheShuffleIsMadeOnceAndIsTheSameEveryTime() {
        let first = DailyRotation.shuffledOrder(count: 30, seed: 42)
        let second = DailyRotation.shuffledOrder(count: 30, seed: 42)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.sorted(), Array(0..<30), "Every item once, none lost")
        XCTAssertNotEqual(first, Array(0..<30))
        XCTAssertNotEqual(first, DailyRotation.shuffledOrder(count: 30, seed: 43))
    }

    func testAShuffledListShowsEveryItemOncePerCycleAndRepeatsTheSameCycle() {
        let rotation = DailyRotation(order: .shuffled, startDay: date(11, 1), seed: 7)
        let cycle = (0..<12).map { rotation.position(count: 12, on: date(11, 1 + $0))!.index }
        XCTAssertEqual(cycle.sorted(), Array(0..<12))
        let again = (12..<24).map { rotation.position(count: 12, on: DateMath.calendar.date(byAdding: .day, value: $0, to: date(11, 1))!)!.index }
        XCTAssertEqual(cycle, again.map { $0 })
        // Asked twice for the same day: the same answer.
        XCTAssertEqual(rotation.position(count: 12, on: date(11, 5)), rotation.position(count: 12, on: date(11, 5, 23)))
    }

    // MARK: What the widget shows

    func testAQuoteShowsTheTextOfTheDayAndNoAuthor() {
        var quote = QuoteContent(text: "premier", author: "Moi")
        quote.texts = ["premier", "deuxième", "troisième"]
        let rotation = DailyRotation(startDay: date(11, 10), seed: 1)
        XCTAssertEqual(quote.shown(daily: rotation, on: date(11, 11)).text, "deuxième")
        XCTAssertEqual(quote.shown(daily: rotation, on: date(11, 11)).author, "")
        XCTAssertEqual(quote.shown(daily: nil, on: date(11, 11)), quote, "Without « Un par jour », the quote as before")
        var written = QuoteContent(text: "écrite", author: "Moi")
        written.texts = nil
        XCTAssertEqual(written.shown(daily: rotation, on: date(11, 11)), written)
    }

    func testAPhotoSeriesShowsOnePhotoADayOnlyWhenAsked() {
        let photos = (0..<7).map { PhotoSlot(file: "p\($0).jpg") }
        let rotation = DailyRotation(startDay: date(11, 8), seed: 1)
        let shown = PhotoLayout.visible(photos, daily: rotation, at: date(11, 12))
        XCTAssertEqual(shown.count, 1)
        XCTAssertEqual(shown.first?.file, "p4.jpg", "The fifth day: the fifth photo")
        XCTAssertEqual(PhotoLayout.visible(photos, daily: nil, at: date(11, 12)), PhotoLayout.visible(photos, at: date(11, 12)))
    }

    func testTheNextChangeIsTheNextLocalMidnight() throws {
        let now = date(11, 12, 13, 20)
        let midnight = DailyRotation.nextChange(after: now)
        XCTAssertEqual(midnight, date(11, 13, 0, 0))
        let parts = DateMath.calendar.dateComponents([.hour, .minute, .second], from: midnight)
        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(parts.minute, 0)
        let photos = (0..<7).map { PhotoSlot(file: "p\($0).jpg") }
        let rotation = DailyRotation(startDay: date(11, 8), seed: 1)
        XCTAssertEqual(PhotoLayout.nextChange(photos, daily: rotation, after: now), midnight)
        // Without « Un par jour »: the hourly turn of more than four photos, or nothing, as before.
        XCTAssertEqual(PhotoLayout.nextChange(photos, daily: nil, after: now), PhotoLayout.nextChange(photos, after: now))
        XCTAssertNil(PhotoLayout.nextChange(Array(photos.prefix(3)), daily: nil, after: now))
        // At midnight the widget shows the next one.
        var design = WidgetDesign(kind: .photos, format: .small)
        design.options.photos = photos
        design.options.daily = rotation
        XCTAssertEqual(design.dailyPosition(on: now)?.day, 5)
        XCTAssertEqual(design.dailyPosition(on: midnight)?.day, 6)
    }

    func testNothingDailyWithoutAnythingToGoThrough() {
        var quote = WidgetDesign(kind: .quote, format: .small)
        quote.options.quote = QuoteContent(text: "écrite")
        quote.options.daily = DailyRotation(startDay: date(11, 1))
        XCTAssertNil(quote.dailyPosition(on: date(11, 12)))
        var photos = WidgetDesign(kind: .photos, format: .small)
        photos.options.photos = [PhotoSlot(file: "a.jpg")]
        photos.options.daily = DailyRotation(startDay: date(11, 1))
        XCTAssertNil(photos.dailyPosition(on: date(11, 12)))
        var off = WidgetDesign(kind: .photos, format: .small)
        off.options.photos = (0..<7).map { PhotoSlot(file: "p\($0).jpg") }
        XCTAssertNil(off.dailyPosition(on: date(11, 12)))
    }

    // MARK: Saved data

    func testAnOlderConfigurationReadsAsBefore() throws {
        let oldOptions = #"{"photos":[],"quote":{"text":"Courage","author":"Moi","font":"rounded"}}"#
        let options = try JSONDecoder().decode(DesignOptions.self, from: Data(oldOptions.utf8))
        XCTAssertNil(options.daily)
        XCTAssertNil(options.quote?.texts)
        XCTAssertEqual(options.quote?.text, "Courage")
        XCTAssertEqual(options.quote?.font, .rounded)
        let empty = try JSONDecoder().decode(DesignOptions.self, from: Data("{}".utf8))
        XCTAssertNil(empty.daily)
        // A damaged « Un par jour » is left off rather than losing the widget.
        let damaged = try JSONDecoder().decode(DesignOptions.self, from: Data(#"{"daily":"oops","quote":{"text":"A","texts":5}}"#.utf8))
        XCTAssertNil(damaged.daily)
        XCTAssertEqual(damaged.quote?.text, "A")
        XCTAssertNil(damaged.quote?.texts)
    }

    func testTheTextsAndTheDayAreKeptWhenSavedAndRead() throws {
        var design = WidgetDesign(kind: .quote, format: .medium)
        var quote = QuoteContent(text: "Un")
        quote.texts = ["Un", "Deux", "Trois"]
        design.options.quote = quote
        design.options.daily = DailyRotation(order: .shuffled, startDay: date(11, 1), seed: 99)
        let read = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
        XCTAssertEqual(read.options.quote?.texts, ["Un", "Deux", "Trois"])
        XCTAssertEqual(read.options.daily?.order, .shuffled)
        XCTAssertEqual(read.options.daily?.seed, 99)
        XCTAssertEqual(read.options.daily?.startDay, DateMath.startOfDay(date(11, 1)))
        XCTAssertEqual(read.dailyPosition(on: date(11, 12)), design.dailyPosition(on: date(11, 12)))
    }

    func testADailyRotationMissingFieldsReadsWithDefaults() throws {
        let read = try JSONDecoder().decode(DailyRotation.self, from: Data("{}".utf8))
        XCTAssertEqual(read.order, .inOrder)
        XCTAssertEqual(read.seed, 1)
    }

    func testAListLongerThanTheLimitIsCutWhenRead() throws {
        var quote = QuoteContent(text: "a")
        quote.texts = Array(repeating: "a", count: TextImport.maxTexts + 50)
        let read = try JSONDecoder().decode(QuoteContent.self, from: JSONEncoder().encode(quote))
        XCTAssertEqual(read.texts?.count, TextImport.maxTexts)
    }
}
