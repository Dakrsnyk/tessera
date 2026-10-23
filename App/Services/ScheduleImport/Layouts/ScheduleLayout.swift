import Foundation
import CoreGraphics

/// How a layout takes part in the choice of the reading of a page.
enum LayoutRole {
    /// Recognises its page without doubt (an Omnivox page): when it does, nothing else is tried.
    case claim
    /// A reading of a page headed by a row of day names (specific ones: periods in the margin, hours in the margin).
    case grid
    /// The generic reading of a page headed by day names, used only when no specific grid reading finds a class.
    case gridFallback
    /// Readings of a page with no row of day names (lists, tables, a grid with the days as rows), or of any page
    /// where the grid readings found nothing.
    case sequence
}

/// One way of reading a page of text. Each layout is independent (one file in `Layouts/`) and sees the same lines:
/// it returns the classes it finds, or nothing when the page is not built that way. `ScheduleLayouts` runs them,
/// scores what they found (`ScheduleScoring`) and keeps the best reading.
protocol ScheduleLayout {
    var name: String { get }
    var role: LayoutRole { get }
    /// The classes this layout sees on the page (lines cleaned, positions 0...1 from the top left).
    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft]
    /// Only for `.claim` layouts: whether the page is certainly of this layout, even when it holds no class.
    func claimsPage(lines: [RecognizedLine], probe: BlockProbe?, drafts: [ScheduleParser.Draft]) -> Bool
}

extension ScheduleLayout {
    func claimsPage(lines: [RecognizedLine], probe: BlockProbe?, drafts: [ScheduleParser.Draft]) -> Bool { false }
}

/// A reading of a page: the classes found, with the score that decides between layouts.
struct ScheduleCandidate {
    var layout: String
    var slots: [ImportedSlot]
    var score: ScheduleScore
    /// The score times a small weight that prefers the page as it is over the same page straightened.
    var value: Double
}

/// Tries every layout and keeps the best reading of a page.
///
/// Order of play on one page:
/// 1. a layout that claims the page (Omnivox, boxed blocks) decides alone;
/// 2. a page with a row of day names is read by the grid layouts (the generic one only when the specific ones find
///    nothing), then by the sequence layouts if still nothing;
/// 3. a page without such a row is read by the sequence layouts;
/// 4. when the photo is tilted, the same is done on the straightened lines, and the better reading wins;
/// 5. a page with two grids (week A and week B) gives the first as it is and the others unticked.
/// The best reading is the highest score; a later layout replaces an earlier one only when it is clearly better.
enum ScheduleLayouts {
    /// Height over width of a phone photo, used when the page size is not known.
    static let defaultAspect = 4.0 / 3.0

    /// In order of priority: on a tie the first one stays.
    static let all: [ScheduleLayout] = [
        OmnivoxLayout(), BoxedBlocksLayout(), PeriodGridLayout(), WeekViewLayout(), ColumnsLayout(), ListLayout(), TransposedLayout()
    ]

    /// A later reading must beat the best one by this share to replace it.
    static let switchMargin = 1.05

    /// A page whose quality is below this has all its classes marked "to check".
    static let doubtfulQuality = 0.5

    static func read(_ lines: [RecognizedLine], probe: BlockProbe?, aspect: Double) -> [ImportedSlot] {
        guard let bands = PageSections.split(lines) else {
            return readBand(lines, probe: probe, aspect: aspect)
        }
        var result: [ImportedSlot] = []
        var low = 0
        var high = 0
        var haveFirst = false
        for band in bands {
            var got = readBand(band.lines, probe: probe, aspect: aspect)
            guard !got.isEmpty else { continue }
            let first = got.map { $0.startMinute }.min() ?? 0
            let last = got.map { $0.endMinute }.max() ?? 0
            if !haveFirst {
                haveFirst = true
                low = first
                high = last
                result.append(contentsOf: got)
                continue
            }
            // A second grid is another week when it says so ("Semaine B") or covers the same hours as the first one;
            // a grid that goes on in the afternoon is the same timetable. Another week is offered unticked.
            let overlap = min(high, last) - max(low, first)
            if band.heading != nil || overlap > 60 {
                for index in got.indices {
                    got[index].isSelected = false
                    got[index].needsCheck = true
                    if let heading = band.heading { got[index].title += " (" + heading + ")" }
                }
            }
            low = min(low, first)
            high = max(high, last)
            result.append(contentsOf: got)
        }
        return ScheduleParser.deduplicated(result)
    }

    /// One band of the page (the whole page, or one grid of several).
    static func readBand(_ lines: [RecognizedLine], probe: BlockProbe?, aspect: Double) -> [ImportedSlot] {
        for layout in all where layout.role == .claim {
            let drafts = layout.drafts(lines: lines, probe: probe)
            if layout.claimsPage(lines: lines, probe: probe, drafts: drafts) {
                let slots = ScheduleParser.finalize(drafts)
                let score = ScheduleScoring.evaluate(slots, lines: lines)
                return flagged(slots, score, wholePage: false)
            }
        }
        var variants: [(lines: [RecognizedLine], probe: BlockProbe?, weight: Double)] = [(lines, probe, 1.0)]
        if let straight = PageSkew.straightened(lines, aspect: aspect) {
            // The probe looks at the photo as it is: it does not fit the straightened lines.
            variants.append((straight, nil, 0.97))
        }
        var candidates: [ScheduleCandidate] = []
        for variant in variants {
            var found: [ScheduleCandidate] = []
            if ScheduleParser.detectGrid(in: variant.lines) != nil {
                found = readings(for: .grid, in: variant.lines, probe: variant.probe, weight: variant.weight)
                if found.isEmpty {
                    found = readings(for: .gridFallback, in: variant.lines, probe: variant.probe, weight: variant.weight)
                }
            }
            if found.isEmpty {
                found = readings(for: .sequence, in: variant.lines, probe: variant.probe, weight: variant.weight)
            }
            candidates.append(contentsOf: found)
        }
        guard var best = candidates.first else { return [] }
        for candidate in candidates.dropFirst() where candidate.value > best.value * switchMargin + 0.01 {
            best = candidate
        }
        return flagged(best.slots, best.score, wholePage: true)
    }

    /// The readings of the layouts of one role that find at least one class, in priority order.
    private static func readings(for role: LayoutRole, in lines: [RecognizedLine], probe: BlockProbe?,
                                   weight: Double) -> [ScheduleCandidate] {
        var found: [ScheduleCandidate] = []
        for layout in all where layout.role == role {
            let slots = ScheduleParser.finalize(layout.drafts(lines: lines, probe: probe))
            guard !slots.isEmpty else { continue }
            let score = ScheduleScoring.evaluate(slots, lines: lines)
            found.append(ScheduleCandidate(layout: layout.name, slots: slots, score: score, value: score.value * weight))
        }
        return found
    }

    /// The slots with their "to check" mark: doubtful on their own, or all of them when the whole reading is poor.
    private static func flagged(_ slots: [ImportedSlot], _ score: ScheduleScore, wholePage: Bool) -> [ImportedSlot] {
        var result = slots
        let poor = wholePage && score.quality < doubtfulQuality
        for index in result.indices {
            result[index].needsCheck = poor || (index < score.doubtful.count && score.doubtful[index])
        }
        return result
    }
}
