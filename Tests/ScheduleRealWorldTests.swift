import XCTest
@testable import Tessera

/// Non-regression tests built on what the REAL Vision returned on the CI simulator for the synthetic timetables of
/// `ScheduleRenderer` (the lines are copied as they were printed in Tests/Support/ScheduleRealLines.swift). Each test feeds
/// those exact lines, with the colour probe of the SAME image (the renderer is deterministic), to the parser and compares the
/// classes with what was drawn. They cover the weaknesses measured on the first real run: an Omnivox page blurred or tilted,
/// and boxed blocks clean, tilted, in dark mode or saved as a JPEG; and they keep the pages that were already read perfectly
/// (list, table, week view) at 100%.
///
/// The thresholds are a little under the result expected from the replay of the logic on these lines (written without a Mac):
/// they catch a collapse, and the CI report tells the exact count (journal of ScheduleRealOCRTests).
final class ScheduleRealWorldTests: XCTestCase {

    // MARK: Helpers

    /// A drawn page as the reader would hand it to the parser: its colour probe and its aspect.
    private func drawnPage(_ layout: String, _ variant: ScheduleVariant) throws
        -> (rendered: RenderedSchedule, image: UIImage, probe: LuminanceProbe, aspect: Double) {
        let rendered = try XCTUnwrap(ScheduleRenderer.make(layout))
        let image = ScheduleRenderer.apply(variant, to: rendered.image)
        let cgImage = try XCTUnwrap(ScheduleReader.upright(image))
        let probe = try XCTUnwrap(LuminanceProbe(cgImage))
        return (rendered, image, probe, Double(cgImage.height) / Double(cgImage.width))
    }

    /// The classes the parser finds in the lines Vision returned, and what was drawn.
    private func read(_ rows: [RealLine], layout: String, variant: ScheduleVariant)
        throws -> (slots: [ImportedSlot], expected: [ExpectedSlot]) {
        let page = try drawnPage(layout, variant)
        let slots = ScheduleParser.slots(from: RealLines.lines(rows), probe: page.probe, aspect: page.aspect)
        return (ScheduleParser.deduplicated(slots), page.rendered.expected)
    }

    /// How many drawn classes are found: same weekday, start and end within 10 minutes (each found class counts once).
    private func correct(_ slots: [ImportedSlot], _ expected: [ExpectedSlot]) -> Int {
        var used = Set<Int>()
        var count = 0
        for item in expected {
            for (index, slot) in slots.enumerated() where !used.contains(index) && slot.weekday == item.weekday
                && abs(slot.startMinute - item.startMinute) <= 10 && abs(slot.endMinute - item.endMinute) <= 10 {
                used.insert(index)
                count += 1
                break
            }
        }
        return count
    }

    private func hm(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    private func describe(_ slots: [ImportedSlot]) -> String {
        slots.map { "\($0.weekday)|\(hm($0.startMinute))-\(hm($0.endMinute))|\($0.title)|\($0.room ?? "-")" }.joined(separator: " ; ")
    }

    private func slot(_ slots: [ImportedSlot], day: Int, start: Int) -> ImportedSlot? {
        slots.first { $0.weekday == day && abs($0.startMinute - start) <= 10 }
    }

    // MARK: The pages are the ones Vision read

    func testTheDrawnPagesHaveTheSizeOfTheImagesVisionRead() throws {
        // "OCR-NOMBRE ...: image 1200x1284 px" (Omnivox) and "1500x1022 px" (boxed blocks) in the CI journal.
        let omnivox = try XCTUnwrap(ScheduleRenderer.make("omnivox"))
        XCTAssertEqual(omnivox.image.size.width, 1200)
        XCTAssertEqual(omnivox.image.size.height, 1284)
        let boxed = try XCTUnwrap(ScheduleRenderer.make("encadres"))
        XCTAssertEqual(boxed.image.size.width, 1500)
        XCTAssertEqual(boxed.image.size.height, 1022)
    }

    // MARK: Omnivox, blurred: the labels of the margin come without their colon

    func testBlurredMarginLabelsAreStillRead() {
        XCTAssertEqual(ScheduleParser.clockMinute("09 00"), 540, "a space instead of the colon")
        XCTAssertEqual(ScheduleParser.clockMinute("09 55"), 595)
        XCTAssertEqual(ScheduleParser.clockMinute("10.05"), 605)
        XCTAssertEqual(ScheduleParser.clockMinute("1300"), 780, "no separator at all")
        XCTAssertEqual(ScheduleParser.clockMinute("1640"), 1000)
        XCTAssertEqual(ScheduleParser.clockMinute("11,50"), 710)
        XCTAssertEqual(ScheduleParser.clockMinute("08:10"), 490)
        XCTAssertNil(ScheduleParser.clockMinute("2026"), "a year is not 20:26")
        XCTAssertEqual(ScheduleParser.clockMinute("0830"), 510)
        XCTAssertNil(ScheduleParser.clockMinute("0430"), "before 05:00")
        XCTAssertNil(ScheduleParser.clockMinute("1337"), "not on the five minutes")
        XCTAssertNil(ScheduleParser.clockMinute("12/10/2026"))
        XCTAssertNil(ScheduleParser.clockMinute("25:00"))
        XCTAssertNil(ScheduleParser.clockMinute("8h"))
    }

    func testBlurredOmnivoxMarginMakesTheEightRows() throws {
        let lines = RealLines.lines(RealLines.omnivoxBlurred)
        let margin = lines.filter { $0.box.midX < 0.08 && $0.box.midY > 0.27 }
        XCTAssertEqual(margin.count, 16, "the 16 labels Vision read, whatever their separator")
        let timeline = try XCTUnwrap(ScheduleParser.Timeline(margin: margin))
        XCTAssertEqual(timeline.rows.map { $0.start }, [490, 545, 605, 660, 780, 835, 895, 950])
        XCTAssertEqual(timeline.rows.map { $0.end }, [540, 595, 655, 710, 830, 885, 945, 1000])
    }

    func testBlurredOmnivoxIsReadByTheOmnivoxLayout() throws {
        let result = try read(RealLines.omnivoxBlurred, layout: "omnivox", variant: .blurred)
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 9, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count, "nothing invented: \(describe(result.slots))")
        // The three rows of Wednesday (08:10-10:55), whose title Vision blurred but whose code it read.
        let philosophy = try XCTUnwrap(slot(result.slots, day: 3, start: 490), describe(result.slots))
        XCTAssertEqual(philosophy.endMinute, 655, accuracy: 10)
        XCTAssertTrue(philosophy.title.lowercased().contains("philosophie"), philosophy.title)
    }

    func testBlurredOmnivoxBlockWhoseTitleAndCodeWereLostTakesTheTitleOfItsRoom() throws {
        // On Monday, Vision read "Local F5107", the teacher and the mode, but neither the title nor the code. The same room holds
        // the Friday block (title and code read): the title is that one, marked in doubt.
        let result = try read(RealLines.omnivoxBlurred, layout: "omnivox", variant: .blurred)
        let monday = try XCTUnwrap(slot(result.slots, day: 1, start: 490), describe(result.slots))
        XCTAssertEqual(monday.endMinute, 595, accuracy: 10)
        XCTAssertTrue(monday.title.lowercased().contains("physique"), monday.title)
        XCTAssertTrue(monday.uncertain.contains(.title), "a title taken from another block is to check")
        XCTAssertTrue(monday.needsCheck)
    }

    func testTheListOfCoursesGivesTheTitleOfABlurredCodeAndSpacesAroundADash() {
        // "604-ANC-03" for "604-ANG-03" (one letter wrong) and "604- ANG-03g: 41033" (a space after a dash).
        let catalog = ["604-ANG-03": "Anglais langue seconde", "202-CHI-03": "Chimie des solutions", "201-CAL-03": "Calcul différentiel"]
        XCTAssertEqual(ScheduleParser.fullTitle("Anglais langue sacondo", code: "604-ANC-03", catalog: catalog), "Anglais langue seconde")
        XCTAssertEqual(ScheduleParser.fullTitle("Chimie des solutions", code: "202-CMI-03", catalog: catalog), "Chimie des solutions")
        XCTAssertEqual(ScheduleParser.fullTitle("Calcul dittorentiol", code: nil, catalog: catalog), "Calcul différentiel")
        XCTAssertEqual(ScheduleParser.courseCode(in: "Anglais 604- ANG-03g: 41033")?.code, "604-ANG-03")
        XCTAssertEqual(ScheduleParser.withoutGroupNumber("gr .41070 Physique mécanique"), "Physique mécanique")
        XCTAssertEqual(ScheduleParser.withoutGroupNumber("gr 41033 Anglais langue seconde"), "Anglais langue seconde")
        // A code that resembles no other, or a title that is not near any: nothing is invented.
        XCTAssertEqual(ScheduleParser.fullTitle("Danse", code: "999-XYZ-99", catalog: catalog), "Danse")
        XCTAssertTrue(ScheduleParser.isRoomLine("Loca A2203"), "a room word read with a letter lost")
        XCTAssertFalse(ScheduleParser.isRoomLine("Rome 1914"))
        XCTAssertFalse(ScheduleParser.isRoomLine("Local"))
    }

    // MARK: Omnivox, tilted by 2 degrees: the probe follows the straightened columns

    func testTiltedOmnivoxBlocksOfThreeRowsKeepTheirHours() throws {
        let result = try read(RealLines.omnivoxTilted, layout: "omnivox", variant: .tilted)
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 9, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count, "nothing invented: \(describe(result.slots))")
        // The three blocks of three rows, which the text alone cut down to one row (09:05-09:55 and so on).
        XCTAssertNotNil(result.slots.first { $0.weekday == 3 && $0.startMinute == 490 && $0.endMinute == 655 }, describe(result.slots))
        XCTAssertNotNil(result.slots.first { $0.weekday == 1 && $0.startMinute == 780 && $0.endMinute == 945 }, describe(result.slots))
        XCTAssertNotNil(result.slots.first { $0.weekday == 4 && $0.startMinute == 835 && $0.endMinute == 1000 }, describe(result.slots))
    }

    // MARK: The probe turned back with the lines

    /// A photo (grey levels) of a page whose thick horizontal lines are at `lines` (0...1 of its height once straightened),
    /// turned by `slope` about the point (`pivotX`, `pivotY`): the place of a pixel on the straightened page is the one
    /// `PageSkew` gives to the lines (`y' = y - s (x - pivotX)`).
    private func tiltedPhoto(width: Int, height: Int, lines: [Double], slope: Double, pivotX: Double, dark: Bool = false) -> [UInt8] {
        var pixels = [UInt8](repeating: dark ? 0 : 255, count: width * height)
        for row in 0..<height {
            for column in 0..<width {
                let x = (Double(column) + 0.5) / Double(width)
                let y = (Double(row) + 0.5) / Double(height)
                let straightY = y - slope * (x - pivotX)
                if lines.contains(where: { abs(straightY - $0) < 0.0025 }) { pixels[row * width + column] = dark ? 255 : 0 }
            }
        }
        return pixels
    }

    func testStraightenedProbeFindsLevelOutlinesOnATiltedPhoto() throws {
        let width = 600
        let height = 800
        let slope = 0.04
        let pivotX = 0.5
        let pivotY = 0.4
        let aspect = Double(height) / Double(width)
        let pixels = tiltedPhoto(width: width, height: height, lines: [0.30, 0.45, 0.70], slope: slope, pivotX: pivotX)
        let photo = try XCTUnwrap(LuminanceProbe(width: width, height: height, pixels: pixels))
        let straight = try XCTUnwrap(photo.straightened(slope: slope, pivotX: pivotX, pivotY: pivotY, aspect: aspect))
        for x in [0.05, 0.2, 0.6, 0.85] {
            let runs = try XCTUnwrap(straight.framedRuns(atX: x, fromY: 0.2, toY: 0.8), "at x=\(x)")
            XCTAssertEqual(runs.count, 2, "at x=\(x): \(runs)")
            if runs.count == 2 {
                XCTAssertEqual(runs[0].lowerBound, 0.30, accuracy: 0.004)
                XCTAssertEqual(runs[0].upperBound, 0.45, accuracy: 0.004)
                XCTAssertEqual(runs[1].lowerBound, 0.45, accuracy: 0.004)
                XCTAssertEqual(runs[1].upperBound, 0.70, accuracy: 0.004)
            }
        }
    }

    func testPhotoPointIsTheInverseOfTheTurnDoneToTheLines() {
        // A line at (x, y) of the photo goes to (x', y') with y' = y - s (x - fx) and x' = x + s a^2 (y' - fy).
        let slope = 0.05
        let pivotX = 0.54
        let pivotY = 0.2
        let aspect = 0.68
        for (x, y) in [(0.1, 0.1), (0.9, 0.7), (0.5, 0.5)] {
            let straightY = y - slope * (x - pivotX)
            let straightX = x + slope * aspect * aspect * (straightY - pivotY)
            let back = PageSkew.photoPoint(x: straightX, y: straightY, slope: slope, pivotX: pivotX, pivotY: pivotY, aspect: aspect)
            XCTAssertEqual(back.x, x, accuracy: 1e-9)
            XCTAssertEqual(back.y, y, accuracy: 1e-9)
        }
    }

    func testAProbeThatCannotTurnItsImageGivesNothingAndTheLinesAreReadAsBefore() {
        struct Plain: BlockProbe {
            func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { nil }
        }
        XCTAssertNil(Plain().straightened(slope: 0.03, pivotX: 0.5, pivotY: 0.2, aspect: 1.3))
        XCTAssertNil(LuminanceProbe(width: 20, height: 20, pixels: [UInt8](repeating: 255, count: 400))?
            .straightened(slope: .nan, pivotX: 0.5, pivotY: 0.2, aspect: 1.3))
    }

    // MARK: Boxed blocks in dark mode: the outlines are light lines

    private func assertRuns(_ runs: [ClosedRange<Double>]?, _ expected: [(Int, Int)], height: Int,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let runs = runs else { return XCTFail("no stretch", file: file, line: line) }
        XCTAssertEqual(runs.count, expected.count, "\(runs)", file: file, line: line)
        for (run, want) in zip(runs, expected) {
            XCTAssertEqual(run.lowerBound * Double(height), Double(want.0), accuracy: 3, file: file, line: line)
            XCTAssertEqual(run.upperBound * Double(height), Double(want.1), accuracy: 3, file: file, line: line)
        }
    }

    func testOutlinesAreFoundOnADarkPageToo() {
        let width = 400
        let height = 800
        for dark in [false, true] {
            let page: UInt8 = dark ? 0 : 255
            let ink: UInt8 = dark ? 255 : 0
            let grey: UInt8 = dark ? 40 : 215
            var pixels = [UInt8](repeating: page, count: width * height)
            for row in stride(from: 20, to: 780, by: 20) { for column in 0..<width { pixels[row * width + column] = grey } }
            for edge in [100, 200, 400] { for row in edge..<(edge + 3) { for column in 0..<width { pixels[row * width + column] = ink } } }
            // The text of a block: dashes of ink, never most of a row.
            for row in stride(from: 120, to: 180, by: 12) {
                for column in stride(from: 40, to: 360, by: 4) { for dx in 0..<2 { pixels[row * width + column + dx] = ink } }
            }
            guard let probe = LuminanceProbe(width: width, height: height, pixels: pixels) else { return XCTFail("no probe") }
            assertRuns(probe.framedRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(101, 201), (201, 401)], height: height)
        }
    }

    // MARK: Boxed blocks, read from the real lines

    func testBoxedBlocksCleanPageHasTheHoursOfItsOutlinesAndNothingInvented() throws {
        let result = try read(RealLines.boxedClean, layout: "encadres", variant: .clean)
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 8, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count, "nothing invented: \(describe(result.slots))")
        // The block of three hours that ended half an hour late (17:30) because the labels stand on the lines, not between them.
        XCTAssertNotNil(result.slots.first { $0.weekday == 2 && $0.startMinute == 840 && $0.endMinute == 1020 }, describe(result.slots))
        // The first block, whose title and code were cut by Vision ("imie générale (" and "2-C01-HU g.000").
        let chemistry = try XCTUnwrap(slot(result.slots, day: 1, start: 510), describe(result.slots))
        XCTAssertEqual(chemistry.endMinute, 630)
        XCTAssertEqual(chemistry.title, "Chimie générale")
        XCTAssertEqual(chemistry.room, "2.547")
    }

    func testBoxedBlockWhoseTitleAndCodeWereMergedIntoOneGarbledLineTakesTheTitleOfItsRoom() throws {
        // Friday 13:30-15:30: Vision read "610-001-40 00001" (one tall observation, the title is gone), "A.201" and "Lemoine, R".
        let result = try read(RealLines.boxedClean, layout: "encadres", variant: .clean)
        let drawing = try XCTUnwrap(slot(result.slots, day: 5, start: 810), describe(result.slots))
        XCTAssertEqual(drawing.endMinute, 930)
        XCTAssertTrue(drawing.title.hasPrefix("Atelier de dessin"), drawing.title)
        XCTAssertTrue(drawing.uncertain.contains(.title))
        XCTAssertEqual(drawing.room, "A.201")
    }

    func testBoxedBlocksBlurredPageStaysPerfect() throws {
        let result = try read(RealLines.boxedBlurred, layout: "encadres", variant: .blurred)
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 9, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count)
    }

    func testBoxedBlocksJPEGKeepsItsHoursWhenTheCodesLoseLetters() throws {
        let result = try read(RealLines.boxedJPEG, layout: "encadres", variant: .jpeg)
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 8, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count, describe(result.slots))
        // "statistiques (L" and "01-S02-HU g.0000": the cut title is completed and the piece of code is not part of it.
        let statistics = try XCTUnwrap(slot(result.slots, day: 1, start: 780), describe(result.slots))
        XCTAssertEqual(statistics.endMinute, 900)
        XCTAssertFalse(statistics.title.contains("S02"), statistics.title)
        XCTAssertTrue(statistics.title.lowercased().hasPrefix("statistiques"), statistics.title)
    }

    func testBoxedBlocksTiltedByTwoDegreesAreReadOnTheStraightenedImage() throws {
        let result = try read(RealLines.boxedTilted, layout: "encadres", variant: .tilted)
        // Four blocks lost their title and their code in the real reading, and nothing tells which course they are: six of ten.
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 5, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count, describe(result.slots))
        XCTAssertNotNil(result.slots.first { $0.weekday == 2 && $0.startMinute == 840 && $0.endMinute == 1020 }, describe(result.slots))
    }

    func testBoxedBlocksInDarkModeAreReadWithTheirOutlines() throws {
        let result = try read(RealLines.boxedDark, layout: "encadres", variant: .dark)
        XCTAssertGreaterThanOrEqual(correct(result.slots, result.expected), 8, describe(result.slots))
        XCTAssertLessThanOrEqual(result.slots.count, result.expected.count, describe(result.slots))
        XCTAssertNotNil(result.slots.first { $0.weekday == 2 && $0.startMinute == 840 && $0.endMinute == 1020 }, describe(result.slots))
        // "elier de dessin 1" and "0-D01-HU g.000": the first letters of the title and of the code were lost.
        let drawing = try XCTUnwrap(slot(result.slots, day: 5, start: 810), describe(result.slots))
        XCTAssertEqual(drawing.title, "Atelier de dessin")
    }

    // MARK: Text of a boxed block

    private func lines(_ texts: [String]) -> [RecognizedLine] {
        texts.map { RecognizedLine(text: $0, box: CGRect(x: 0, y: 0, width: 0.1, height: 0.01)) }
    }

    func testBoxedBlockCodeCutAtTheStartIsNotPartOfTheTitle() throws {
        let cut = try XCTUnwrap(BoxedBlocksLayout.content(of: lines(["imie générale (", "2-C01-HU g.000", "2.547", "Vidal, K"])))
        XCTAssertEqual(cut.title, "imie générale (")
        XCTAssertEqual(cut.room, "2.547")
        XCTAssertEqual(cut.teacher, "Vidal, K")
        XCTAssertEqual(cut.evidence, .code)
        let glued = try XCTUnwrap(BoxedBlocksLayout.content(of: lines(["Histoire de l'art (T) 530-1103-HU g.00001", "3.208"])))
        XCTAssertEqual(glued.title, "Histoire de l'art (T)")
        // A title with two dashes is not a code (no digit in it).
        XCTAssertEqual(BoxedBlocksLayout.titlePiece("Rock-and-roll"), "Rock-and-roll")
        XCTAssertNil(BoxedBlocksLayout.titlePiece("202-C01-HU"))
        XCTAssertNil(BoxedBlocksLayout.titlePiece("208502-HU 900001"), "digits and symbols are not a name")
    }

    func testBoxedBlockWithOnlyARoomAndATeacherIsABlockWithoutATitle() throws {
        let merged = try XCTUnwrap(BoxedBlocksLayout.content(of: lines(["610-001-40 00001", "A.201", "Lemoine, R"])))
        XCTAssertEqual(merged.title, "", "the title was merged into the garbled line and lost")
        XCTAssertEqual(merged.room, "A.201")
        XCTAssertEqual(merged.evidence, .code)
        let lost = try XCTUnwrap(BoxedBlocksLayout.content(of: lines(["20izl900002", "1.112", "Moreau, T"])))
        XCTAssertEqual(lost.title, "")
        XCTAssertEqual(lost.evidence, .partial)
        // A teacher or a room alone is a block only inside an outline; a note over the grid never is.
        XCTAssertNil(BoxedBlocksLayout.content(of: lines(["Moreau, T"])))
        XCTAssertEqual(BoxedBlocksLayout.content(of: lines(["Moreau, T"]), loose: true)?.evidence, .fragment)
        XCTAssertNil(BoxedBlocksLayout.content(of: lines(["Jamais de", "cours les"]), loose: true))
    }

    private func block(_ title: String, room: String?, teacher: String? = nil, column: Int = 0) -> BoxedBlocksLayout.Block {
        BoxedBlocksLayout.Block(column: column, content: BoxedBlocksLayout.Content(title: title, room: room, teacher: teacher),
                                start: 540, end: 600, estimated: false)
    }

    func testCutTitlesAreCompletedFromTheWholeTitlesOfThePage() {
        var blocks = [
            block("Chimie générale (L)", room: "2.601", teacher: "Vidal, K"),
            block("imie générale (", room: "2.547", teacher: "Vidal, K"),
            block("Atelier de dessin (L)", room: "A.201", teacher: "Lemoine, R"),
            block("elier de dessin 1", room: "A.201"),
            block("statistiques (L", room: "1.112"),
            block("Statistiques (T)", room: "1.112", teacher: "Moreau, T"),
            block("Initiation à la linguistique (T", room: "3.115")
        ]
        BoxedBlocksLayout.completeTitles(&blocks)
        XCTAssertEqual(blocks[1].content.title, "Chimie générale")
        XCTAssertEqual(blocks[3].content.title, "Atelier de dessin")
        XCTAssertEqual(blocks[4].content.title, "Statistiques (L)", "the type that was read stays")
        XCTAssertEqual(blocks[6].content.title, "Initiation à la linguistique (T)", "nothing to complete it with: only the type is closed")
        XCTAssertEqual(blocks.map { $0.titleGuessed }, [false, true, false, true, true, false, false])
    }

    func testABlockWithoutATitleTakesTheTitleOfItsRoomOrOfItsTeacherWhenTheyAgree() {
        var blocks = [
            block("Statistiques (T)", room: "1.112", teacher: "Moreau, T"),
            block("Droit (L)", room: "1.112", teacher: "Garnier, P"),
            block("", room: "3.208"),
            block("", room: "1.112", teacher: "Moreau, T"),
            block("", room: nil, teacher: "Moreau, T"),
            block("", room: nil, teacher: "Dupont, J"),
            block("Histoire de l'art (T)", room: "3.208", teacher: "Garnier, P")
        ]
        BoxedBlocksLayout.completeTitles(&blocks)
        XCTAssertEqual(blocks[2].content.title, "Histoire de l'art", "the room 3.208 holds one course")
        XCTAssertEqual(blocks[3].content.title, "Statistiques", "the room holds two courses, the teacher tells which")
        XCTAssertEqual(blocks[4].content.title, "Statistiques", "the teacher alone")
        XCTAssertEqual(blocks[5].content.title, "", "an unknown teacher: nothing is invented")
        XCTAssertTrue(blocks[2].titleGuessed)
        XCTAssertFalse(blocks[5].titleGuessed)
    }

    func testAFragmentInTheOutlineOfABlockThatHasItsCodeIsPartOfIt() {
        func part(_ evidence: BoxedBlocksLayout.Content.Evidence, start: Int) -> BoxedBlocksLayout.Block {
            var found = block("T", room: "1.112")
            found.content.evidence = evidence
            found.start = start
            found.end = start + 60
            return found
        }
        let kept = BoxedBlocksLayout.withoutDuplicateFragments([part(.code, start: 480), part(.fragment, start: 480), part(.fragment, start: 600),
                                                                part(.partial, start: 600), part(.fragment, start: 720)])
        XCTAssertEqual(kept.map { $0.start }, [480, 600, 720], "one block per outline, the one with the code first")
        XCTAssertEqual(kept.map { $0.content.evidence }, [.code, .fragment, .fragment])
    }

    // MARK: Where the labels stand

    func testLabelsOnTheLinesAndLabelsCentredInTheRowsAreTold() throws {
        let step = 0.03
        let first = 0.10
        func outlines(offset: Double) -> [[ClosedRange<Double>]] {
            func at(_ k: Double) -> Double { first + offset + step * k }
            return [[at(0)...at(3), at(3)...at(5)], [at(2)...at(6), at(6)...at(8)]]
        }
        // The labels stand on the lines: nothing to move.
        let onLines = try XCTUnwrap(BoxedBlocksLayout.labelShift(outlines: outlines(offset: 0), firstLabel: CGFloat(first), step: CGFloat(step)))
        XCTAssertEqual(Double(onLines), 0, accuracy: 0.0005)
        // The college report: the label is centred in its row, the line half a step above it.
        let centred = try XCTUnwrap(BoxedBlocksLayout.labelShift(outlines: outlines(offset: -step / 2), firstLabel: CGFloat(first), step: CGFloat(step)))
        XCTAssertEqual(Double(centred), step / 2, accuracy: 0.0005)
        // The Outaouais capture: the lines 0.355 of a step above the label's row.
        let measured = try XCTUnwrap(BoxedBlocksLayout.labelShift(outlines: outlines(offset: -0.355 * step), firstLabel: CGFloat(first), step: CGFloat(step)))
        XCTAssertEqual(Double(measured), 0.355 * step, accuracy: 0.0005)
        // Too few lines, or lines that do not agree: no measure (the half step is then assumed).
        XCTAssertNil(BoxedBlocksLayout.labelShift(outlines: [[0.2...0.3]], firstLabel: CGFloat(first), step: CGFloat(step)))
        func place(_ fraction: Double) -> Double { first + step * fraction }
        let scattered: [[ClosedRange<Double>]] = [[place(0)...place(0.25), place(0.25)...place(0.5), place(0.5)...place(0.75), place(0.75)...place(1)]]
        XCTAssertNil(BoxedBlocksLayout.labelShift(outlines: scattered, firstLabel: CGFloat(first), step: CGFloat(step)))
    }

    // MARK: The pages that were already perfect stay perfect

    func testTheListTheTableAndTheWeekViewAreStillReadPerfectly() throws {
        let list = try read(RealLines.listClean, layout: "liste", variant: .clean)
        XCTAssertEqual(correct(list.slots, list.expected), list.expected.count, describe(list.slots))
        XCTAssertEqual(list.slots.count, list.expected.count)
        let table = try read(RealLines.tableClean, layout: "tableau", variant: .clean)
        XCTAssertEqual(correct(table.slots, table.expected), table.expected.count, describe(table.slots))
        XCTAssertEqual(table.slots.count, table.expected.count)
        let week = try read(RealLines.weekClean, layout: "semaine", variant: .clean)
        XCTAssertEqual(correct(week.slots, week.expected), week.expected.count, describe(week.slots))
        XCTAssertEqual(week.slots.count, week.expected.count)
    }
}
