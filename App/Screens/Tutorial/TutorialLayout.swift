import CoreGraphics

/// Where the tutorial puts its light and its bubble. Pure functions (no view, no state) so every rule can be tested:
/// the part lit up is shown WHOLE or not at all (never a cut outline), well inside the screen, away from the bubble,
/// and the bubble always stays in the safe area.
enum TutorialLayout {
    /// A part of the app that could be lit up, in screen coordinates, with the corner radius of the part itself.
    struct Candidate: Equatable {
        var frame: CGRect
        var radius: CGFloat
    }

    /// What the overlay draws: the hole (nil: nothing lit, the bubble sits in the middle), its corner radius,
    /// the bubble's frame, and which candidate was lit.
    struct Plan: Equatable {
        var hole: CGRect?
        var holeRadius: CGFloat
        var card: CGRect
        var cardAtTop: Bool
        var candidateIndex: Int?
    }

    /// Corner radius of the cards of the app when a part doesn't say its own.
    static let defaultRadius: CGFloat = 22
    /// The clear outline stays at least this far from the edges of the screen.
    static let edge: CGFloat = 6
    /// Air between the lit part and the bubble.
    static let gap: CGFloat = 12
    /// Margin between the bubble and the safe area.
    static let cardMargin: CGFloat = 16
    /// The tab bar: what lies under it can't be lit.
    static let tabBar: CGFloat = 56
    /// Air around the lit part, tried from the largest to none.
    static let paddings: [CGFloat] = [8, 4, 0]
    /// Smallest part worth lighting.
    static let smallest: CGFloat = 24

    // MARK: Zones

    /// Where a lit part may be: under the status bar, above the tab bar, inside the sides.
    static func visibleZone(screen: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> CGRect {
        let top = max(edge, safeTop - 4)
        let bottom = screen.height - safeBottom - tabBar
        return CGRect(x: edge, y: top, width: max(0, screen.width - 2 * edge), height: max(0, bottom - top))
    }

    /// The bubble's frame: at the bottom, at the top, or centered in the safe area. Never taller than the safe area.
    static func cardFrame(_ card: CGSize, screen: CGSize, safeTop: CGFloat, safeBottom: CGFloat, atTop: Bool?) -> CGRect {
        let room = max(0, screen.height - safeTop - safeBottom - 24)
        let height = min(card.height, room)
        let width = min(card.width, max(0, screen.width - 2 * edge))
        let x = (screen.width - width) / 2
        switch atTop {
        case .some(true):
            return CGRect(x: x, y: safeTop + 12, width: width, height: height)
        case .some(false):
            return CGRect(x: x, y: screen.height - safeBottom - cardMargin - height, width: width, height: height)
        case .none:
            return CGRect(x: x, y: safeTop + 12 + (room - height) / 2, width: width, height: height)
        }
    }

    // MARK: Plan

    /// The first candidate that fits whole, with the bubble below it or else above it; otherwise nothing lit and the
    /// bubble at the bottom (centered only when the step has no part at all). Candidates are listed by preference (the whole section, then a smaller part of it).
    static func plan(candidates: [Candidate?], screen: CGSize, safeTop: CGFloat, safeBottom: CGFloat, card: CGSize) -> Plan {
        let zone = visibleZone(screen: screen, safeTop: safeTop, safeBottom: safeBottom)
        for (index, candidate) in candidates.enumerated() {
            guard let candidate else { continue }
            for atTop in [false, true] {
                let cardRect = cardFrame(card, screen: screen, safeTop: safeTop, safeBottom: safeBottom, atTop: atTop)
                if let fitted = hole(for: candidate, in: zone, avoiding: cardRect) {
                    return Plan(hole: fitted.rect, holeRadius: fitted.radius, card: cardRect, cardAtTop: atTop, candidateIndex: index)
                }
            }
        }
        // The step has parts to show but none fits whole: no outline, and the card goes to the bottom so it never
        // covers what the step presents (the page is scrolled to show the top of the part above the card).
        if !candidates.isEmpty {
            let bottom = cardFrame(card, screen: screen, safeTop: safeTop, safeBottom: safeBottom, atTop: false)
            return Plan(hole: nil, holeRadius: defaultRadius, card: bottom, cardAtTop: false, candidateIndex: nil)
        }
        let centered = cardFrame(card, screen: screen, safeTop: safeTop, safeBottom: safeBottom, atTop: nil)
        return Plan(hole: nil, holeRadius: defaultRadius, card: centered, cardAtTop: false, candidateIndex: nil)
    }

    /// The part with a little air around it, whole inside the zone and away from the bubble; nil when it can't be.
    static func hole(for candidate: Candidate, in zone: CGRect, avoiding card: CGRect) -> (rect: CGRect, radius: CGFloat)? {
        let frame = candidate.frame
        guard frame.minX.isFinite, frame.minY.isFinite, frame.width.isFinite, frame.height.isFinite,
              frame.width >= smallest, frame.height >= smallest else { return nil }
        for pad in paddings {
            let rect = frame.insetBy(dx: -pad, dy: -pad)
            guard zone.contains(rect) else { continue }
            if rect.insetBy(dx: -gap, dy: -gap).intersects(card) { continue }
            let radius = max(6, min(candidate.radius + pad, min(rect.width, rect.height) / 2))
            return (rect, radius)
        }
        return nil
    }

    // MARK: Scrolling

    /// How far the content must move up (positive) or down (negative) so the first candidate that can fit sits in the
    /// middle of the room above the bubble. Nil when none can fit however it is scrolled (too tall, too wide).
    static func scrollDelta(candidates: [Candidate?], screen: CGSize, safeTop: CGFloat, safeBottom: CGFloat,
                            card: CGSize) -> (index: Int, delta: CGFloat, fits: Bool)? {
        let zone = visibleZone(screen: screen, safeTop: safeTop, safeBottom: safeBottom)
        let cardRect = cardFrame(card, screen: screen, safeTop: safeTop, safeBottom: safeBottom, atTop: false)
        let bandTop = zone.minY
        // One point less than the exact gap, so a part that just fits never touches the bubble's margin.
        let bandBottom = min(zone.maxY, cardRect.minY - gap - 1)
        for (index, candidate) in candidates.enumerated() {
            guard let candidate else { continue }
            let frame = candidate.frame
            guard frame.width >= smallest, frame.height >= smallest else { continue }
            // Sideways nothing can change: the part must already be inside.
            guard zone.minX <= frame.minX - paddings[paddings.count - 1], frame.maxX <= zone.maxX else { continue }
            guard frame.height <= bandBottom - bandTop - 1 else { continue }
            let wantedMid = (bandTop + bandBottom) / 2
            return (index, frame.midY - wantedMid, true)
        }
        // None fits whole: show the top of the first part that is at least inside sideways, at the top of the free room.
        for (index, candidate) in candidates.enumerated() {
            guard let candidate, candidate.frame.width >= smallest, candidate.frame.height >= smallest,
                  zone.minX <= candidate.frame.minX, candidate.frame.maxX <= zone.maxX else { continue }
            return (index, candidate.frame.minY - (bandTop + 8), false)
        }
        return nil
    }
}
