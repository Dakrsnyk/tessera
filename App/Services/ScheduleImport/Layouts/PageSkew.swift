import Foundation
import CoreGraphics

/// A photo of a sheet is rarely square to the camera. The tilt is measured on the row of day names (their heights
/// follow a line) and the lines of text are turned back by it, so the columns line up again. The grid layouts then
/// read the straightened lines too, and the better reading wins.
///
/// In normalised coordinates, a page turned by an angle θ (pixels, W wide and H high, aspect = H / W) has its rows
/// going down by `s` per unit of x, with `s = tan θ / aspect`, and its columns drifting by `-s * aspect²` per unit of y.
enum PageSkew {
    /// A row of day names with a slope smaller than this is level enough (about a third of a degree).
    static let negligibleSlope = 0.006
    /// A tilt beyond this (about 11 degrees for a phone photo) is not a tilt of the photo but a different layout.
    static let largestSlope = 0.2

    /// The lines turned back, or nil when the row of day names is level, absent, or not a straight line.
    static func straightened(_ lines: [RecognizedLine], aspect: Double) -> [RecognizedLine]? {
        straighten(lines, aspect: aspect)?.lines
    }

    /// The lines turned back with the measure of the tilt (slope of the row of day names and the point the page is turned
    /// about), so that the image can be turned back the same way (`BlockProbe.straightened`).
    static func straighten(_ lines: [RecognizedLine], aspect: Double)
        -> (lines: [RecognizedLine], fit: (slope: Double, x: Double, y: Double))? {
        guard aspect.isFinite, aspect > 0.2, aspect < 5, let fit = slope(of: lines) else { return nil }
        var result: [RecognizedLine] = []
        for line in lines {
            let x = Double(line.box.midX)
            let y = Double(line.box.midY)
            let straightY = y - fit.slope * (x - fit.x)
            let straightX = x + fit.slope * aspect * aspect * (straightY - fit.y)
            let box = CGRect(x: straightX - Double(line.box.width) / 2, y: straightY - Double(line.box.height) / 2,
                             width: Double(line.box.width), height: Double(line.box.height))
            result.append(RecognizedLine(text: line.text, box: box))
        }
        return (lines: result, fit: fit)
    }

    /// Where a point of the straightened page lies on the photo, the inverse of the turn done to the lines: the column of a
    /// straightened page is the line `x = x' - s * aspect² * (y' - fit.y)` of the photo, and its rows are `y = y' + s * (x - fit.x)`.
    static func photoPoint(x straightX: Double, y straightY: Double, slope: Double, pivotX: Double, pivotY: Double,
                           aspect: Double) -> (x: Double, y: Double) {
        let x = straightX - slope * aspect * aspect * (straightY - pivotY)
        let y = straightY + slope * (x - pivotX)
        return (x, y)
    }

    /// The line through the day names: the slope (y per x) and the mean place of the names it goes through. At least
    /// three different days must lie on it (within a hundredth of the page height).
    static func slope(of lines: [RecognizedLine]) -> (slope: Double, x: Double, y: Double)? {
        var names: [(day: Int, x: Double, y: Double)] = []
        for (index, line) in lines.enumerated() {
            for candidate in ScheduleParser.dayCandidates(line: line, index: index) {
                names.append((day: candidate.day, x: Double(candidate.x), y: Double(candidate.y)))
            }
        }
        guard names.count >= 3, names.count <= 60 else { return nil }
        var best: [Int: (x: Double, y: Double)] = [:]
        for first in names {
            for second in names where second.x - first.x >= 0.15 && second.day != first.day {
                let slope = (second.y - first.y) / (second.x - first.x)
                guard abs(slope) <= largestSlope else { continue }
                var onLine: [Int: (x: Double, y: Double)] = [:]
                for name in names where abs(name.y - (first.y + slope * (name.x - first.x))) <= 0.012 && onLine[name.day] == nil {
                    onLine[name.day] = (x: name.x, y: name.y)
                }
                if onLine.count >= 3, onLine.count > best.count { best = onLine }
            }
        }
        guard best.count >= 3 else { return nil }
        let points = Array(best.values)
        let meanX = points.map { $0.x }.reduce(0, +) / Double(points.count)
        let meanY = points.map { $0.y }.reduce(0, +) / Double(points.count)
        let spread = points.map { ($0.x - meanX) * ($0.x - meanX) }.reduce(0, +)
        guard spread > 1e-9 else { return nil }
        let covariance = points.map { ($0.x - meanX) * ($0.y - meanY) }.reduce(0, +)
        let fitted = covariance / spread
        guard abs(fitted) >= negligibleSlope, abs(fitted) <= largestSlope else { return nil }
        return (slope: fitted, x: meanX, y: meanY)
    }
}
