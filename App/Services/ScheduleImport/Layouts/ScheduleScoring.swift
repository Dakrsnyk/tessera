import Foundation

/// How well a reading explains a page.
struct ScheduleScore {
    /// Sum of the quality of the classes, times how much of the text of the page they explain. The higher, the better;
    /// it grows with the number of valid classes, so two readings of the same page compare fairly.
    var value: Double
    /// `value` per class (0...1): how much to trust the reading as a whole.
    var quality: Double
    /// One flag per class (same order): odd hours, odd length, a noisy name, or an overlap with another class of the day.
    var doubtful: [Bool]
}

/// Scores the classes a layout found. Pure, so every rule is tested by the readings of the tests.
enum ScheduleScoring {
    /// A class starts between 05:00 and 23:00 and ends by midnight.
    static let earliestStart = 5 * 60
    static let latestStart = 23 * 60
    /// A class lasts between 20 minutes and 5 hours.
    static let shortest = 20
    static let longest = 5 * 60
    /// Two classes of the same day overlapping by more than this are in doubt (both).
    static let tolerableOverlap = 10
    /// A shift of a work schedule may last a whole day.
    static let longestShift = 12 * 60

    static func evaluate(_ slots: [ImportedSlot], lines: [RecognizedLine]) -> ScheduleScore {
        guard !slots.isEmpty else { return ScheduleScore(value: 0, quality: 0, doubtful: []) }
        var doubtful = [Bool](repeating: false, count: slots.count)
        var qualities = [Double](repeating: 1, count: slots.count)
        for (index, slot) in slots.enumerated() {
            if slot.startMinute < earliestStart || slot.startMinute > latestStart || slot.endMinute > 24 * 60 {
                qualities[index] -= 0.5
                doubtful[index] = true
            }
            let length = slot.endMinute - slot.startMinute
            if length < shortest || length > (slot.kind == .work ? longestShift : longest) {
                qualities[index] -= 0.4
                doubtful[index] = true
            }
            // A shift or an appointment may have no name (its kind names it); a class always has one.
            if (slot.kind == .course || !slot.title.isEmpty) && isNoisy(slot.title) {
                qualities[index] -= 0.5
                doubtful[index] = true
            }
        }
        for first in 0..<slots.count {
            for second in (first + 1)..<slots.count where slots[first].weekday == slots[second].weekday
                && sameAgenda(slots[first], slots[second]) {
                let overlap = min(slots[first].endMinute, slots[second].endMinute)
                    - max(slots[first].startMinute, slots[second].startMinute)
                if overlap > tolerableOverlap {
                    qualities[first] -= 0.35
                    qualities[second] -= 0.35
                    doubtful[first] = true
                    doubtful[second] = true
                }
            }
        }
        let total = qualities.reduce(0) { $0 + max(0, $1) }
        var explained = coverage(of: slots, in: lines)
        // Shifts and appointments are told by their hours and dates, not always by a name: a page of them alone is not
        // judged on the names it explains only.
        if slots.allSatisfy({ $0.kind != .course }) { explained = max(explained, 0.5) }
        let value = total * (0.4 + 0.6 * explained)
        return ScheduleScore(value: value, quality: value / Double(slots.count), doubtful: doubtful)
    }

    /// Whether two entries of the same weekday can clash: two classes always; otherwise only on the same date (or both
    /// weekly) and for the same person (two employees of a roster work the same hours).
    static func sameAgenda(_ a: ImportedSlot, _ b: ImportedSlot) -> Bool {
        if a.kind == .course && b.kind == .course && a.date == nil && b.date == nil { return true }
        return a.date == b.date && (a.detail ?? "") == (b.detail ?? "")
    }

    /// A name that is mostly digits or symbols, very long, or that still holds a time.
    static func isNoisy(_ title: String) -> Bool {
        let characters = title.filter { !$0.isWhitespace }
        guard !characters.isEmpty else { return true }
        let letters = characters.filter { $0.isLetter }.count
        if letters * 2 < characters.count { return true }
        if title.count > 50 { return true }
        return ScheduleParser.findTime(in: title) != nil
    }

    static func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x2E80 }
    }

    /// The lines that look like the name or the room of a class: three letters or more (two for Chinese, Japanese,
    /// Korean), not an hour, not a day name, not a heading of the page.
    static func informativeLines(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        var result: [RecognizedLine] = []
        for (index, line) in lines.enumerated() {
            let letters = line.text.filter { $0.isLetter }.count
            guard letters >= 3 || (letters >= 2 && hasCJK(line.text)) else { continue }
            if ScheduleParser.timeOnly(line.text) != nil { continue }
            if !ScheduleParser.dayCandidates(line: line, index: index).isEmpty { continue }
            if ScheduleParser.isNoise(line.text) { continue }
            // A break or a free period is on the page but is no class: it is not text left unexplained.
            if ScheduleParser.isBreak(line.text) || ScheduleParser.isFreePeriod(line.text) { continue }
            result.append(line)
        }
        return result
    }

    /// The share (0...1) of the informative lines that share a word with a class (its name or its room).
    static func coverage(of slots: [ImportedSlot], in lines: [RecognizedLine]) -> Double {
        let informative = informativeLines(lines)
        guard !informative.isEmpty else { return 1 }
        var vocabulary = Set<String>()
        for slot in slots {
            // The person of a shift or an appointment (the name of the row of a roster) is part of what it explains.
            let person = slot.kind == .course ? "" : (slot.detail ?? "")
            let words = ScheduleParser.words(of: slot.title) + ScheduleParser.words(of: slot.room ?? "") + ScheduleParser.words(of: person)
            for word in words where word.count >= 3 || hasCJK(word) {
                vocabulary.insert(word)
            }
        }
        guard !vocabulary.isEmpty else { return 0 }
        var covered = 0
        for line in informative {
            let words = ScheduleParser.words(of: line.text).filter { $0.count >= 3 || hasCJK($0) }
            if words.contains(where: { vocabulary.contains($0) }) { covered += 1 }
        }
        return Double(covered) / Double(informative.count)
    }
}
