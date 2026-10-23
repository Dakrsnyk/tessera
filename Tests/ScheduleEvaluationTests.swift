import XCTest
@testable import Tessera

/// Precision, recall and exactness of the timetable importer against the reference pages of `ScheduleCorpus`
/// (Tests/Support/ScheduleFixtures.swift), at three levels of OCR noise. The scores are printed in the log, one line per
/// page and level ("SCORE <name> bruit=<n> P=... R=..."), then the mean ("SCORE-MOYENNE ..."), so that a change of the
/// importer can be judged by numbers and not only by a handful of examples.
///
/// Only `ScheduleParser.slots(from:probe:)` and the fields of `ImportedSlot` are used.

// MARK: Scoring

/// How well one reading matches the answer. All the figures are between 0 and 1.
struct ReadingScoreCard {
    /// Share of the classes read that are real (1 when nothing was read: nothing is invented).
    var precision = 0.0
    /// Share of the real classes that were found.
    var recall = 0.0
    /// For the classes found: share with the right day, start, end, title and room.
    var day = 0.0
    var start = 0.0
    var end = 0.0
    var title = 0.0
    var room = 0.0
    /// Mean number of classes expected and read (for the log).
    var expectedCount = 0.0
    var foundCount = 0.0

    /// Mean of the five fields.
    var exactness: Double { (day + start + end + title + room) / 5 }

    func adding(_ other: ReadingScoreCard) -> ReadingScoreCard {
        ReadingScoreCard(precision: precision + other.precision, recall: recall + other.recall, day: day + other.day,
                         start: start + other.start, end: end + other.end, title: title + other.title, room: room + other.room,
                         expectedCount: expectedCount + other.expectedCount, foundCount: foundCount + other.foundCount)
    }

    func scaled(by factor: Double) -> ReadingScoreCard {
        ReadingScoreCard(precision: precision * factor, recall: recall * factor, day: day * factor, start: start * factor,
                         end: end * factor, title: title * factor, room: room * factor,
                         expectedCount: expectedCount * factor, foundCount: foundCount * factor)
    }

    static func average(_ cards: [ReadingScoreCard]) -> ReadingScoreCard {
        guard !cards.isEmpty else { return ReadingScoreCard() }
        var sum = ReadingScoreCard()
        for card in cards { sum = sum.adding(card) }
        return sum.scaled(by: 1.0 / Double(cards.count))
    }
}

enum ScheduleScorer {
    /// Minutes two intervals have in common.
    static func overlap(_ startA: Int, _ endA: Int, _ startB: Int, _ endB: Int) -> Int {
        max(0, min(endA, endB) - max(startA, startB))
    }

    /// Letters and digits only, lowercase, no accents: two titles that differ by a case or a punctuation are the same.
    static func titleKey(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        return String(folded.filter { $0.isLetter || $0.isNumber })
    }

    static let roomWords: Set<String> = ["salle", "local", "room", "raum", "aula", "amphi", "labo", "lab", "sala", "classe"]

    /// A room without its word ("Salle 12" and "12" are the same), several rooms ("B-204 / C-110", "H3018;H3040") as a sorted
    /// list. nil and "" give "".
    static func roomKey(_ room: String?) -> String {
        guard let room = room else { return "" }
        var parts: [String] = []
        for piece in room.components(separatedBy: CharacterSet(charactersIn: "/;,&")) {
            let folded = piece.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            let words = folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { String($0) }
            let kept = words.filter { !roomWords.contains($0) }
            let key = kept.joined()
            if !key.isEmpty { parts.append(key) }
        }
        return parts.sorted().joined(separator: "|")
    }

    /// Pairs each class expected with a class read. First on the same day with hours that overlap (the best overlap first, a
    /// same title breaking ties); then, among what is left, a class read on another day with the same title and at least
    /// half of the hours in common (the right class on the wrong day).
    static func match(_ expected: [ReferenceSlot], _ found: [ImportedSlot]) -> [(expected: Int, found: Int)] {
        var usedExpected = Set<Int>()
        var usedFound = Set<Int>()
        var pairs: [(expected: Int, found: Int)] = []
        for pass in 0..<2 {
            var candidates: [(e: Int, f: Int, score: Double)] = []
            for (e, want) in expected.enumerated() where !usedExpected.contains(e) {
                for (f, got) in found.enumerated() where !usedFound.contains(f) {
                    let common = overlap(want.start, want.end, got.startMinute, got.endMinute)
                    let union = max(want.end, got.endMinute) - min(want.start, got.startMinute)
                    guard common > 0, union > 0 else { continue }
                    let ratio = Double(common) / Double(union)
                    let sameTitle = titleKey(want.title) == titleKey(got.title)
                    if pass == 0 {
                        guard want.day == got.weekday else { continue }
                        candidates.append((e: e, f: f, score: ratio + (sameTitle ? 0.5 : 0)))
                    } else {
                        guard want.day != got.weekday, ratio >= 0.5, sameTitle else { continue }
                        candidates.append((e: e, f: f, score: ratio))
                    }
                }
            }
            candidates.sort { a, b in
                if a.score != b.score { return a.score > b.score }
                if a.e != b.e { return a.e < b.e }
                return a.f < b.f
            }
            for candidate in candidates where !usedExpected.contains(candidate.e) && !usedFound.contains(candidate.f) {
                usedExpected.insert(candidate.e)
                usedFound.insert(candidate.f)
                pairs.append((expected: candidate.e, found: candidate.f))
            }
        }
        return pairs
    }

    static func card(expected: [ReferenceSlot], found: [ImportedSlot]) -> ReadingScoreCard {
        let pairs = match(expected, found)
        var day = 0
        var start = 0
        var end = 0
        var title = 0
        var room = 0
        for pair in pairs {
            let want = expected[pair.expected]
            let got = found[pair.found]
            if want.day == got.weekday { day += 1 }
            if want.start == got.startMinute { start += 1 }
            if want.end == got.endMinute { end += 1 }
            if titleKey(want.title) == titleKey(got.title) { title += 1 }
            if roomKey(want.room) == roomKey(got.room) { room += 1 }
        }
        let matched = Double(pairs.count)
        func share(_ hits: Int) -> Double { pairs.isEmpty ? 0 : Double(hits) / matched }
        var result = ReadingScoreCard()
        result.precision = found.isEmpty ? 1 : matched / Double(found.count)
        result.recall = expected.isEmpty ? 1 : matched / Double(expected.count)
        result.day = share(day)
        result.start = share(start)
        result.end = share(end)
        result.title = share(title)
        result.room = share(room)
        result.expectedCount = Double(expected.count)
        result.foundCount = Double(found.count)
        return result
    }
}

// MARK: Tests

final class ScheduleEvaluationTests: XCTestCase {

    // MARK: Thresholds
    //
    // PRUDENT FLOORS, written without running the code (no Mac): the Chef will tighten them with the real scores read in the
    // CI log ("SCORE-MOYENNE bruit=<n> ..."). They are meant to catch a collapse of the importer, not to measure it.

    /// Without noise: the mean exactness of the five fields, the mean precision (never invent a class) and the mean recall.
    static let floorExactnessClean = 0.75
    static let floorPrecisionClean = 0.70
    static let floorRecallClean = 0.60
    /// Mild noise.
    static let floorExactnessMild = 0.50
    static let floorPrecisionMild = 0.50
    static let floorRecallMild = 0.40
    /// Heavy noise.
    static let floorExactnessHeavy = 0.25
    static let floorPrecisionHeavy = 0.30
    static let floorRecallHeavy = 0.20

    /// With noise each page is read this many times with other seeds, and the scores are averaged.
    static let noisyRuns = 3

    // MARK: Helpers

    private func fixed(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func measure(_ schedule: ReferenceSchedule, level: Int) -> ReadingScoreCard {
        let runs = level == 0 ? 1 : ScheduleEvaluationTests.noisyRuns
        var total = ReadingScoreCard()
        for run in 0..<runs {
            let seed = OCRNoise.seed(name: schedule.name, level: level, run: run)
            let lines = OCRNoise(level: level, seed: seed).apply(to: schedule.lines)
            let found = ScheduleParser.slots(from: lines, probe: schedule.probe)
            total = total.adding(ScheduleScorer.card(expected: schedule.expected, found: found))
        }
        return total.scaled(by: 1.0 / Double(runs))
    }

    private func fields(_ card: ReadingScoreCard) -> String {
        "P=\(fixed(card.precision)) R=\(fixed(card.recall)) jour=\(fixed(card.day)) debut=\(fixed(card.start)) fin=\(fixed(card.end)) "
            + "titre=\(fixed(card.title)) salle=\(fixed(card.room)) E=\(fixed(card.exactness))"
    }

    /// Prints the table of one noise level and returns the mean.
    private func scoreTable(level: Int) -> ReadingScoreCard {
        var cards: [ReadingScoreCard] = []
        var table: [String] = []
        for schedule in ScheduleCorpus.scored {
            let card = measure(schedule, level: level)
            cards.append(card)
            let row = "SCORE \(schedule.name) bruit=\(level) \(fields(card)) attendus=\(fixed(card.expectedCount)) lus=\(fixed(card.foundCount))"
            print(row)
            table.append(row)
        }
        let mean = ReadingScoreCard.average(cards)
        let runs = level == 0 ? 1 : ScheduleEvaluationTests.noisyRuns
        let meanRow = "SCORE-MOYENNE bruit=\(level) \(fields(mean)) pages=\(cards.count) graines=\(runs)"
        print(meanRow)
        table.append(meanRow)
        // The CI log keeps no print: the table travels as an attachment, exported in the report.
        attach(table.joined(separator: "\n"), name: "SCORES-bruit\(level)")
        return mean
    }

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Without noise, for each page: the classes expected and not found, and the classes found that are not real
    /// ("day|start-end|title|room"), to see what to fix.
    private func failureReport() -> String {
        var out: [String] = []
        for schedule in ScheduleCorpus.scored {
            let found = ScheduleParser.slots(from: schedule.lines, probe: schedule.probe)
            let pairs = ScheduleScorer.match(schedule.expected, found)
            let matchedExpected = Set(pairs.map { $0.expected })
            let matchedFound = Set(pairs.map { $0.found })
            var rows: [String] = []
            for (index, slot) in schedule.expected.enumerated() where !matchedExpected.contains(index) {
                rows.append("  MANQUE \(slot.day)|\(LayoutFixtures.hm(slot.start))-\(LayoutFixtures.hm(slot.end))|\(slot.title)|\(slot.room ?? "-")")
            }
            for (index, slot) in found.enumerated() where !matchedFound.contains(index) {
                rows.append("  INVENTE \(slot.weekday)|\(LayoutFixtures.hm(slot.startMinute))-\(LayoutFixtures.hm(slot.endMinute))|\(slot.title)|\(slot.room ?? "-")")
            }
            out.append("ECHEC \(schedule.name) attendus=\(schedule.expected.count) lus=\(found.count) manques+inventes=\(rows.count)")
            out.append(contentsOf: rows)
        }
        return out.joined(separator: "\n")
    }

    // MARK: Scores against the reference pages

    func testScoresWithoutNoise() {
        let mean = scoreTable(level: 0)
        attach(failureReport(), name: "SCORES-ECHECS")
        XCTAssertGreaterThanOrEqual(mean.exactness, ScheduleEvaluationTests.floorExactnessClean, "exactness")
        XCTAssertGreaterThanOrEqual(mean.precision, ScheduleEvaluationTests.floorPrecisionClean, "precision: classes invented")
        XCTAssertGreaterThanOrEqual(mean.recall, ScheduleEvaluationTests.floorRecallClean, "recall: classes missed")
    }

    func testScoresWithMildNoise() {
        let mean = scoreTable(level: 1)
        XCTAssertGreaterThanOrEqual(mean.exactness, ScheduleEvaluationTests.floorExactnessMild, "exactness")
        XCTAssertGreaterThanOrEqual(mean.precision, ScheduleEvaluationTests.floorPrecisionMild, "precision: classes invented")
        XCTAssertGreaterThanOrEqual(mean.recall, ScheduleEvaluationTests.floorRecallMild, "recall: classes missed")
    }

    func testScoresWithHeavyNoise() {
        let mean = scoreTable(level: 2)
        XCTAssertGreaterThanOrEqual(mean.exactness, ScheduleEvaluationTests.floorExactnessHeavy, "exactness")
        XCTAssertGreaterThanOrEqual(mean.precision, ScheduleEvaluationTests.floorPrecisionHeavy, "precision: classes invented")
        XCTAssertGreaterThanOrEqual(mean.recall, ScheduleEvaluationTests.floorRecallHeavy, "recall: classes missed")
    }

    // MARK: The corpus itself

    func testReferenceCorpusIsWellFormed() {
        let corpus = ScheduleCorpus.all
        XCTAssertGreaterThanOrEqual(corpus.count, 14)
        XCTAssertEqual(Set(corpus.map { $0.name }).count, corpus.count, "Two pages with the same name")
        XCTAssertEqual(Set(ScheduleCorpus.scored.map { $0.name }).count, ScheduleCorpus.scored.count)
        for schedule in corpus {
            XCTAssertFalse(schedule.lines.isEmpty, schedule.name)
            XCTAssertFalse(schedule.expected.isEmpty, schedule.name)
            for line in schedule.lines {
                XCTAssertFalse(line.text.isEmpty, schedule.name)
                XCTAssertTrue(line.box.minX >= 0 && line.box.minY >= 0 && line.box.maxX <= 1.0001 && line.box.maxY <= 1.0001,
                              "\(schedule.name): \(line.text) is off the page")
            }
            for (index, slot) in schedule.expected.enumerated() {
                XCTAssertTrue((1...7).contains(slot.day), "\(schedule.name): day of \(slot.title)")
                XCTAssertTrue(slot.start >= 0 && slot.start < slot.end && slot.end <= 1440, "\(schedule.name): hours of \(slot.title)")
                XCTAssertFalse(slot.title.isEmpty, schedule.name)
                for other in schedule.expected[(index + 1)...] where other.day == slot.day {
                    XCTAssertEqual(ScheduleScorer.overlap(slot.start, slot.end, other.start, other.end), 0,
                                   "\(schedule.name): \(slot.title) and \(other.title) overlap")
                }
            }
        }
    }

    func testBoxedPageAnswerAddsUpTo15BlocksAnd26Hours() {
        let blocks = ScheduleCorpus.boxedExpected
        XCTAssertEqual(blocks.count, 15, "The heading of the page says 15 blocks")
        XCTAssertEqual(blocks.reduce(0) { $0 + $1.end - $1.start }, 26 * 60, "The heading of the page says 26 hours")
        // 7 courses: the title without its type (T) or (L).
        let courses = Set(blocks.map { String($0.title.dropLast(4)) })
        XCTAssertEqual(courses.count, 7, "The heading of the page says 7 courses")
    }

    func testCorpusHoldsAWeekendAndAPageWithABlockOfThreeRows() {
        let names = ScheduleCorpus.all.map { $0.name }
        XCTAssertTrue(names.contains("week-end"))
        XCTAssertTrue(names.contains("omnivox-bloc-3-rangees"))
        let weekend = ScheduleCorpus.all.first { $0.name == "week-end" }
        XCTAssertTrue(weekend?.expected.contains(where: { $0.day >= 6 }) ?? false)
        let threeRows = ScheduleCorpus.all.first { $0.name == "omnivox-bloc-3-rangees" }
        let threeRowBlock = threeRows?.expected.contains(where: {
            $0.start == ScheduleCorpus.minutes("09:05") && $0.end == ScheduleCorpus.minutes("11:50")
        })
        XCTAssertEqual(threeRowBlock, true)
    }

    // MARK: The noise

    func testNoiseLevelZeroChangesNothing() {
        for schedule in ScheduleCorpus.all {
            XCTAssertEqual(OCRNoise(level: 0, seed: 1).apply(to: schedule.lines), schedule.lines, schedule.name)
        }
    }

    func testNoiseIsDeterministicAndDependsOnTheSeed() {
        guard let schedule = ScheduleCorpus.all.first(where: { $0.name == "semaine-calendrier" }) else { return XCTFail("no page") }
        for level in [1, 2] {
            let first = OCRNoise(level: level, seed: 42).apply(to: schedule.lines)
            let again = OCRNoise(level: level, seed: 42).apply(to: schedule.lines)
            XCTAssertEqual(first, again, "level \(level)")
            let other = OCRNoise(level: level, seed: 43).apply(to: schedule.lines)
            XCTAssertNotEqual(first, other, "level \(level)")
        }
        XCTAssertEqual(OCRNoise.seed(name: "a", level: 1, run: 0), OCRNoise.seed(name: "a", level: 1, run: 0))
        XCTAssertNotEqual(OCRNoise.seed(name: "a", level: 1, run: 0), OCRNoise.seed(name: "a", level: 1, run: 1))
        XCTAssertNotEqual(OCRNoise.seed(name: "a", level: 1, run: 0), OCRNoise.seed(name: "b", level: 1, run: 0))
    }

    func testNoiseKeepsTheLinesOnThePageNearWhereTheyWere() {
        guard let schedule = ScheduleCorpus.all.first(where: { $0.name == "liste-jour-par-jour" }) else { return XCTFail("no page") }
        let noisy = OCRNoise(level: 2, seed: 7).apply(to: schedule.lines)
        // Fused, cut and stray lines make the count change, never by much.
        XCTAssertGreaterThan(noisy.count, schedule.lines.count / 2)
        XCTAssertLessThan(noisy.count, schedule.lines.count + 20)
        for line in noisy {
            XCTAssertTrue(line.box.minX > -0.01 && line.box.minY > -0.01 && line.box.maxX < 1.05 && line.box.maxY < 1.05, line.text)
        }
    }

    func testLookalikeCharactersAreSwapped() {
        var rng = SeededGenerator(seed: 5)
        XCTAssertEqual(OCRNoise.confuse("BOS", rate: 1, rng: &rng), "805")
        XCTAssertEqual(OCRNoise.confuse("805", rate: 1, rng: &rng), "BOS")
        XCTAssertEqual(OCRNoise.confuse("Maths", rate: 1, rng: &rng), "Maths", "No look-alike in this word")
        XCTAssertEqual(OCRNoise.confuse("10h15", rate: 0, rng: &rng), "10h15", "Rate 0 changes nothing")
        let swapped = OCRNoise.confuse("l", rate: 1, rng: &rng)
        XCTAssertEqual(swapped, "1")
    }

    func testDayNamesLoseOrChangeALetter() {
        var rng = SeededGenerator(seed: 9)
        for name in ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"] {
            let damaged = OCRNoise.damageDay(name, rate: 1, rng: &rng)
            XCTAssertNotEqual(damaged, name)
            XCTAssertTrue(damaged.hasPrefix(String(name.prefix(1))), "The first letter stays: \(damaged)")
            XCTAssertTrue(abs(damaged.count - name.count) <= 1)
        }
        XCTAssertEqual(OCRNoise.damageDay("Maths 12", rate: 1, rng: &rng), "Maths 12", "Not a day")
        XCTAssertEqual(OCRNoise.damageDay("Lundi", rate: 0, rng: &rng), "Lundi")
    }

    func testFusedAndCutLinesKeepTheirText() {
        var rng = SeededGenerator(seed: 3)
        let a = RecognizedLine(text: "8h-10h", box: CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.016))
        let b = RecognizedLine(text: "Maths", box: CGRect(x: 0.22, y: 0.1, width: 0.1, height: 0.016))
        let fusedLines = OCRNoise.fused([a, b], rate: 1, rng: &rng)
        XCTAssertEqual(fusedLines.count, 1)
        XCTAssertEqual(fusedLines.first?.text, "8h-10h Maths")
        let far = RecognizedLine(text: "Maths", box: CGRect(x: 0.6, y: 0.5, width: 0.1, height: 0.016))
        XCTAssertEqual(OCRNoise.fused([a, far], rate: 1, rng: &rng).count, 2, "Lines far apart are never fused")
        let long = RecognizedLine(text: "8h30 - 10h Maths", box: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.016))
        let pieces = OCRNoise.cut([long], rate: 1, rng: &rng)
        XCTAssertEqual(pieces.count, 2)
        XCTAssertEqual(pieces.map { $0.text }.joined(separator: " "), "8h30 - 10h Maths")
        XCTAssertEqual(pieces[0].box.width + pieces[1].box.width, long.box.width, accuracy: 0.0001)
        XCTAssertEqual(OCRNoise.cut([a], rate: 1, rng: &rng).count, 1, "Two words or less are not cut")
    }

    // MARK: The scorer

    private func imported(_ slots: [ReferenceSlot]) -> [ImportedSlot] {
        slots.map { ImportedSlot(weekday: $0.day, startMinute: $0.start, endMinute: $0.end, title: $0.title, room: $0.room) }
    }

    func testScorerGivesFullMarksToTheExactAnswer() {
        for schedule in ScheduleCorpus.all {
            let card = ScheduleScorer.card(expected: schedule.expected, found: imported(schedule.expected))
            XCTAssertEqual(card.precision, 1, accuracy: 0.0001, schedule.name)
            XCTAssertEqual(card.recall, 1, accuracy: 0.0001, schedule.name)
            XCTAssertEqual(card.exactness, 1, accuracy: 0.0001, schedule.name)
        }
    }

    func testScorerCountsMissedAndInventedClasses() {
        let expected = [ScheduleCorpus.slot(1, "08:00", "09:00", "Maths"), ScheduleCorpus.slot(1, "09:00", "10:00", "Physique")]
        let missed = ScheduleScorer.card(expected: expected, found: imported([expected[0]]))
        XCTAssertEqual(missed.precision, 1, accuracy: 0.0001)
        XCTAssertEqual(missed.recall, 0.5, accuracy: 0.0001)
        let invented = ScheduleScorer.card(expected: expected, found: imported(expected + [ScheduleCorpus.slot(3, "14:00", "15:00", "Pause")]))
        XCTAssertEqual(invented.precision, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(invented.recall, 1, accuracy: 0.0001)
        let nothing = ScheduleScorer.card(expected: expected, found: [])
        XCTAssertEqual(nothing.precision, 1, "Nothing read: nothing invented")
        XCTAssertEqual(nothing.recall, 0)
        XCTAssertEqual(nothing.exactness, 0)
    }

    func testScorerTellsEachFieldApart() {
        let expected = [ScheduleCorpus.slot(1, "08:00", "10:00", "Chimie organique", "B-204")]
        let wrongEnd = ScheduleScorer.card(expected: expected, found: imported([ScheduleCorpus.slot(1, "08:00", "09:30", "Chimie organique", "B-204")]))
        XCTAssertEqual(wrongEnd.start, 1)
        XCTAssertEqual(wrongEnd.end, 0)
        XCTAssertEqual(wrongEnd.recall, 1, "The hours overlap: it is the class, read with a wrong end")
        let wrongTitle = ScheduleScorer.card(expected: expected, found: imported([ScheduleCorpus.slot(1, "08:00", "10:00", "Chim1e organique", "B-204")]))
        XCTAssertEqual(wrongTitle.title, 0)
        XCTAssertEqual(wrongTitle.end, 1)
        let wrongRoom = ScheduleScorer.card(expected: expected, found: imported([ScheduleCorpus.slot(1, "08:00", "10:00", "Chimie organique")]))
        XCTAssertEqual(wrongRoom.room, 0)
        XCTAssertEqual(wrongRoom.title, 1)
        let wrongDay = ScheduleScorer.card(expected: expected, found: imported([ScheduleCorpus.slot(2, "08:00", "10:00", "Chimie organique", "B-204")]))
        XCTAssertEqual(wrongDay.recall, 1, "The right class on the wrong day is still found")
        XCTAssertEqual(wrongDay.day, 0)
        XCTAssertEqual(wrongDay.start, 1)
        let otherDayOtherTitle = ScheduleScorer.card(expected: expected, found: imported([ScheduleCorpus.slot(2, "08:00", "10:00", "Physique")]))
        XCTAssertEqual(otherDayOtherTitle.recall, 0)
        XCTAssertEqual(otherDayOtherTitle.precision, 0)
    }

    func testScorerComparesRoomsAndTitlesLeniently() {
        XCTAssertEqual(ScheduleScorer.roomKey("Salle 12"), ScheduleScorer.roomKey("12"))
        XCTAssertEqual(ScheduleScorer.roomKey("B-204"), ScheduleScorer.roomKey("B204"))
        XCTAssertEqual(ScheduleScorer.roomKey("1.629 / 1.710"), ScheduleScorer.roomKey("1.710;1.629"))
        XCTAssertEqual(ScheduleScorer.roomKey(nil), "")
        XCTAssertNotEqual(ScheduleScorer.roomKey("B-204"), ScheduleScorer.roomKey("B-205"))
        XCTAssertEqual(ScheduleScorer.titleKey("Mathématiques"), ScheduleScorer.titleKey("mathematiques"))
        XCTAssertEqual(ScheduleScorer.titleKey("Chimie générale (L)"), ScheduleScorer.titleKey("Chimie generale L"))
        XCTAssertNotEqual(ScheduleScorer.titleKey("Chimie"), ScheduleScorer.titleKey("Physique"))
    }

    // MARK: Breaks and free slots are never classes (one test per kind)

    private typealias Fx = LayoutFixtures

    private func read(_ texts: [String]) -> [String] {
        Fx.summary(ScheduleParser.slots(from: Fx.list(texts)))
    }

    func testAPauseIsNotAClass() {
        XCTAssertEqual(read(["Lundi", "8h-9h Maths", "9h-9h15 Pause", "9h15-10h15 Histoire"]),
                       ["1|08:00-09:00|Maths|-", "1|09:15-10:15|Histoire|-"])
    }

    func testARecreationIsNotAClass() {
        XCTAssertEqual(read(["Mardi", "8h-10h Physique", "10h-10h20 Récréation", "10h20-12h Chimie"]),
                       ["2|08:00-10:00|Physique|-", "2|10:20-12:00|Chimie|-"])
    }

    func testALunchBreakInFrenchIsNotAClass() {
        XCTAssertEqual(read(["Jeudi", "9h-11h Anglais", "12h-13h Dîner", "13h-15h Histoire"]),
                       ["4|09:00-11:00|Anglais|-", "4|13:00-15:00|Histoire|-"])
    }

    func testALongLunchBreakAndACoffeeBreakAreNotClasses() {
        XCTAssertEqual(read(["Lundi", "8h-9h Maths", "12h-13h Pause déjeuner", "15h-15h15 Pause café", "16h-17h Art"]),
                       ["1|08:00-09:00|Maths|-", "1|16:00-17:00|Art|-"])
    }

    func testLunchAndBreakInEnglishAreNotClasses() {
        XCTAssertEqual(read(["Monday", "9:00 AM - 10:30 AM Biology", "12:00 PM - 1:00 PM Lunch", "1:00 PM - 2:30 PM Chemistry",
                             "Tuesday", "10:00 AM - 10:30 AM Coffee break", "11:00 AM - 12:00 PM Calculus"]),
                       ["1|09:00-10:30|Biology|-", "1|13:00-14:30|Chemistry|-", "2|11:00-12:00|Calculus|-"])
    }

    func testMittagspauseInGermanIsNotAClass() {
        XCTAssertEqual(read(["Montag", "08:00 - 09:30 Mathematik", "12:00 - 13:00 Mittagspause", "13:30 - 15:00 Informatik"]),
                       ["1|08:00-09:30|Mathematik|-", "1|13:30-15:00|Informatik|-"])
    }

    func testLunchBreakInJapaneseIsNotAClass() {
        XCTAssertEqual(read(["月曜日", "9：00～10：30 数学", "12:00-13:00 昼休み", "13:30-15:00 英語"]),
                       ["1|09:00-10:30|数学|-", "1|13:30-15:00|英語|-"])
    }

    /// A free slot written "Libre" is not a class. (Not in the list of break words of the parser when this test was written:
    /// if it fails, the importer reads free slots as classes.)
    func testAFreeSlotInFrenchIsNotAClass() {
        XCTAssertEqual(read(["Lundi", "8h-9h Maths", "9h-10h Libre", "10h-11h Histoire"]),
                       ["1|08:00-09:00|Maths|-", "1|10:00-11:00|Histoire|-"])
    }

    /// Same for "Free period". (If it fails, free periods are read as classes.)
    func testAFreePeriodInEnglishIsNotAClass() {
        XCTAssertEqual(read(["Tuesday", "8:00 AM - 9:00 AM Calculus", "9:00 AM - 10:00 AM Free period", "10:00 AM - 11:00 AM Physics"]),
                       ["2|08:00-09:00|Calculus|-", "2|10:00-11:00|Physics|-"])
    }

    func testAnHourRangeWithoutAnyTitleIsNotAClass() {
        XCTAssertEqual(read(["Lundi", "8h-9h Maths", "9h-10h", "10h-11h Histoire"]),
                       ["1|08:00-09:00|Maths|-", "1|10:00-11:00|Histoire|-"])
    }

    func testBreakRowsAcrossAllTheColumnsOfAGridAreNotClasses() {
        let slots = ScheduleParser.slots(from: ScheduleCorpus.breaksGridLines())
        let titles = slots.map { ScheduleScorer.titleKey($0.title) }
        XCTAssertFalse(titles.contains { $0.contains("recreation") }, "The recreation row is not a class")
        XCTAssertFalse(titles.contains { $0.contains("diner") }, "The lunch row is not a class")
        let card = ScheduleScorer.card(expected: ScheduleCorpus.breaksGridExpected, found: slots)
        XCTAssertEqual(card.precision, 1, accuracy: 0.0001, "Nothing invented: \(Fx.summary(slots))")
    }

    func testEmptyRowsOfAGridInventNothing() {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + Fx.marginLabels(Fx.periodLabels)
        lines += Fx.cell(0, 0, "Maths", "B12") + Fx.cell(2, 4, "Sport")
        XCTAssertEqual(Fx.summary(ScheduleParser.slots(from: lines)), ["1|08:00-09:00|Maths|B12", "3|13:30-14:30|Sport|-"])
    }
}
