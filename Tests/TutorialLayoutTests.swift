import XCTest
@testable import Ardane

/// The tutorial's framing rules: the part lit up is whole or not lit at all, inside the visible zone, away from the
/// card, and the card stays in the safe area, on a small and a big iPhone, for small, tall, edge and oversized parts.
final class TutorialLayoutTests: XCTestCase {
    private struct Screen {
        let name: String
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
    }

    private let screens = [
        Screen(name: "iPhone SE", size: CGSize(width: 375, height: 667), top: 20, bottom: 0),
        Screen(name: "iPhone 11 Pro", size: CGSize(width: 375, height: 812), top: 44, bottom: 34),
        Screen(name: "iPhone 16 Pro Max", size: CGSize(width: 440, height: 956), top: 62, bottom: 34),
    ]
    private let card = CGSize(width: 360, height: 250)

    private func cand(_ frame: CGRect, _ radius: CGFloat) -> TutorialLayout.Candidate? {
        TutorialLayout.Candidate(frame: frame, radius: radius)
    }

    private func parts(for screen: Screen) -> [(String, CGRect)] {
        let w = screen.size.width
        let h = screen.size.height
        return [
            ("petite", CGRect(x: 20, y: screen.top + 200, width: 120, height: 80)),
            ("avatar", CGRect(x: w - 61, y: screen.top + 9, width: 36, height: 36)),
            ("haute", CGRect(x: 20, y: screen.top + 60, width: w - 40, height: 300)),
            ("près du haut", CGRect(x: 20, y: screen.top - 2, width: w - 40, height: 120)),
            ("près du bas", CGRect(x: 20, y: h - screen.bottom - 130, width: w - 40, height: 90)),
            ("collée aux côtés", CGRect(x: 0, y: screen.top + 200, width: w, height: 100)),
            ("plus haute que l'écran", CGRect(x: 20, y: -50, width: w - 40, height: h + 300)),
            ("hors de l'écran", CGRect(x: 20, y: h + 100, width: w - 40, height: 100)),
        ]
    }

    func testTheOutlineIsWholeInsideTheZoneAndAwayFromTheCard() {
        for screen in screens {
            let zone = TutorialLayout.visibleZone(screen: screen.size, safeTop: screen.top, safeBottom: screen.bottom)
            for (name, frame) in parts(for: screen) {
                let plan = TutorialLayout.plan(candidates: [cand(frame, 22)], screen: screen.size,
                                               safeTop: screen.top, safeBottom: screen.bottom, card: card)
                let label = "\(screen.name), \(name)"
                if let hole = plan.hole {
                    XCTAssertTrue(hole.contains(frame), "\(label) : le trou contient la partie entière")
                    XCTAssertTrue(zone.contains(hole), "\(label) : le trou est dans la zone visible")
                    XCTAssertGreaterThanOrEqual(hole.minX, 6, label)
                    XCTAssertLessThanOrEqual(hole.maxX, screen.size.width - 6, label)
                    XCTAssertGreaterThanOrEqual(hole.minY, 6, label)
                    XCTAssertLessThanOrEqual(hole.maxY, screen.size.height - 6, label)
                    XCTAssertFalse(hole.intersects(plan.card), "\(label) : le trou ne touche pas la bulle")
                    XCTAssertLessThanOrEqual(plan.holeRadius, min(hole.width, hole.height) / 2, label)
                    XCTAssertGreaterThanOrEqual(plan.holeRadius, 6, label)
                    XCTAssertEqual(plan.candidateIndex, 0, label)
                } else {
                    XCTAssertNil(plan.candidateIndex, label)
                    XCTAssertEqual(plan.card.maxY, screen.size.height - screen.bottom - 16, accuracy: 0.5,
                                   "\(label) : sans trou, la bulle va en bas, jamais au centre par-dessus la partie")
                }
                let safe = CGRect(x: 0, y: screen.top, width: screen.size.width, height: screen.size.height - screen.top - screen.bottom)
                XCTAssertTrue(safe.contains(plan.card), "\(label) : la bulle reste dans la zone sûre")
            }
        }
    }

    func testPartsThatMustFitDoFit() {
        for screen in screens {
            let w = screen.size.width
            let small = CGRect(x: 20, y: screen.top + 200, width: 120, height: 80)
            let plan = TutorialLayout.plan(candidates: [cand(small, 22)], screen: screen.size,
                                           safeTop: screen.top, safeBottom: screen.bottom, card: card)
            XCTAssertNotNil(plan.hole, "\(screen.name) : une petite partie est éclairée")
            let avatar = CGRect(x: w - 61, y: screen.top + 9, width: 36, height: 36)
            let top = TutorialLayout.plan(candidates: [cand(avatar, 18)], screen: screen.size,
                                          safeTop: screen.top, safeBottom: screen.bottom, card: card)
            XCTAssertNotNil(top.hole, "\(screen.name) : l'avatar en haut est éclairé")
            XCTAssertFalse(top.cardAtTop, "\(screen.name) : la bulle va dessous")
        }
    }

    func testATallPartIsReplacedByTheNextSmallerOneOrNothing() {
        for screen in screens {
            let tall = CGRect(x: 20, y: -50, width: 335, height: screen.size.height + 300)
            let header = CGRect(x: 20, y: screen.top + 20, width: 335, height: 90)
            let both = TutorialLayout.plan(candidates: [cand(tall, 22), cand(header, 22)],
                                           screen: screen.size, safeTop: screen.top, safeBottom: screen.bottom, card: card)
            XCTAssertEqual(both.candidateIndex, 1, "\(screen.name) : la partie trop haute laisse la place à la plus petite")
            let alone = TutorialLayout.plan(candidates: [cand(tall, 22)], screen: screen.size,
                                            safeTop: screen.top, safeBottom: screen.bottom, card: card)
            XCTAssertNil(alone.hole, "\(screen.name) : jamais de contour coupé")
            let unknown = TutorialLayout.plan(candidates: [nil, nil], screen: screen.size,
                                              safeTop: screen.top, safeBottom: screen.bottom, card: card)
            XCTAssertNil(unknown.hole, "\(screen.name) : une cible non posée ne dessine rien")
        }
    }

    func testTheCardAboveWhenTheBottomIsTaken() {
        let screen = screens[1]
        let low = CGRect(x: 20, y: 470, width: 335, height: 90)
        let plan = TutorialLayout.plan(candidates: [cand(low, 22)], screen: screen.size,
                                       safeTop: screen.top, safeBottom: screen.bottom, card: card)
        XCTAssertNotNil(plan.hole)
        XCTAssertTrue(plan.cardAtTop, "Le trou est trop bas pour la bulle dessous : elle passe dessus")
        XCTAssertLessThan(plan.card.maxY, plan.hole?.minY ?? 0)
    }

    func testTheCardIsNeverTallerThanTheSafeArea() {
        let screen = screens[0]
        let huge = CGSize(width: 360, height: 900)
        let plan = TutorialLayout.plan(candidates: [], screen: screen.size, safeTop: screen.top, safeBottom: screen.bottom, card: huge)
        XCTAssertGreaterThanOrEqual(plan.card.minY, screen.top)
        XCTAssertLessThanOrEqual(plan.card.maxY, screen.size.height - screen.bottom)
    }

    func testScrollingBringsAPartThatFitsWholeAndCentersItAboveTheCard() throws {
        for screen in screens {
            // A card half-way down a long page: it must come up into the room above the bubble.
            let far = CGRect(x: 20, y: screen.size.height + 150, width: 335, height: 120)
            let move = try XCTUnwrap(TutorialLayout.scrollDelta(candidates: [cand(far, 22)], screen: screen.size,
                                                                 safeTop: screen.top, safeBottom: screen.bottom, card: card),
                                     "\(screen.name) : la partie peut être amenée")
            XCTAssertEqual(move.index, 0)
            let moved = far.offsetBy(dx: 0, dy: -move.delta)
            let plan = TutorialLayout.plan(candidates: [cand(moved, 22)], screen: screen.size,
                                           safeTop: screen.top, safeBottom: screen.bottom, card: card)
            XCTAssertNotNil(plan.hole, "\(screen.name) : une fois défilée, la partie est éclairée entière")
            XCTAssertFalse(plan.cardAtTop, "\(screen.name) : la bulle est dessous, la partie centrée au-dessus")
        }
    }

    func testScrollingSkipsWhatCannotFit() throws {
        let screen = screens[0]
        let tall = CGRect(x: 20, y: 100, width: 335, height: 900)
        let small = CGRect(x: 20, y: 900, width: 335, height: 100)
        let move = try XCTUnwrap(TutorialLayout.scrollDelta(candidates: [cand(tall, 22), nil, cand(small, 22)],
                                                             screen: screen.size, safeTop: screen.top, safeBottom: screen.bottom, card: card))
        XCTAssertEqual(move.index, 2)
        let wide = CGRect(x: -10, y: 300, width: 420, height: 100)
        XCTAssertNil(TutorialLayout.scrollDelta(candidates: [cand(wide, 22)], screen: screen.size,
                                                safeTop: screen.top, safeBottom: screen.bottom, card: card),
                     "Une partie plus large que l'écran ne sera jamais éclairée")
    }

    func testWhenNothingFitsTheCardGoesToTheBottomAndThePageShowsTheTopOfThePart() throws {
        // Planning card 410 tall, Store hero 360, card 280: on every screen, no outline ever cut and never a centered card.
        let bubble = CGSize(width: 360, height: 280)
        for screen in screens {
            for (name, height) in [("Planning", CGFloat(410)), ("Store", CGFloat(360)), ("trop haute", CGFloat(2000))] {
                let part = CGRect(x: 20, y: screen.size.height - 150, width: screen.size.width - 40, height: height)
                let plan = TutorialLayout.plan(candidates: [cand(part, 24)], screen: screen.size,
                                               safeTop: screen.top, safeBottom: screen.bottom, card: bubble)
                let label = "\(screen.name), \(name)"
                if let hole = plan.hole {
                    XCTAssertTrue(TutorialLayout.visibleZone(screen: screen.size, safeTop: screen.top, safeBottom: screen.bottom).contains(hole), label)
                    XCTAssertFalse(hole.intersects(plan.card), label)
                } else {
                    XCTAssertEqual(plan.card.maxY, screen.size.height - screen.bottom - 16, accuracy: 0.5, "\(label) : bulle en bas")
                    XCTAssertFalse(plan.cardAtTop, label)
                }
                // The page then moves so that the top of the part (or the whole part when it fits) is in the free room.
                let move = try XCTUnwrap(TutorialLayout.scrollDelta(candidates: [cand(part, 24)], screen: screen.size,
                                                                     safeTop: screen.top, safeBottom: screen.bottom, card: bubble), label)
                let moved = part.offsetBy(dx: 0, dy: -move.delta)
                let zone = TutorialLayout.visibleZone(screen: screen.size, safeTop: screen.top, safeBottom: screen.bottom)
                let freeBottom = plan.card.minY
                if !move.fits {
                    XCTAssertEqual(moved.minY, zone.minY + 8, accuracy: 0.5, "\(label) : le haut de la partie est en haut de la zone libre")
                    XCTAssertLessThan(moved.minY, freeBottom, label)
                }
            }
        }
    }

    func testTheTopOfThePlanningCardTakesOverWhenTheWholeCardIsTooTall() {
        let bubble = CGSize(width: 360, height: 280)
        // Small iPhone: 410 doesn't fit above the bubble, the top of the card (170) does.
        let screen = screens[0]
        let whole = CGRect(x: 20, y: 100, width: 335, height: 410)
        let top = CGRect(x: 20, y: 100, width: 335, height: 170)
        let plan = TutorialLayout.plan(candidates: [cand(whole, 24), cand(top, 24)], screen: screen.size,
                                       safeTop: screen.top, safeBottom: screen.bottom, card: bubble)
        XCTAssertEqual(plan.candidateIndex, 1)
        XCTAssertNotNil(plan.hole)
    }

    func testSeveralPartsAreLitTogetherOnlyWhenAllAreThere() {
        let frames = TutorialFrames()
        frames.update(.dailyHeader, CGRect(x: 20, y: 80, width: 335, height: 60), radius: 8)
        XCTAssertNil(frames.candidate(for: [.dailyHeader, .dailyNutrition]), "Une des parties manque")
        frames.update(.dailyNutrition, CGRect(x: 20, y: 150, width: 160, height: 140), radius: 24)
        let both = frames.candidate(for: [.dailyHeader, .dailyNutrition])
        XCTAssertEqual(both?.frame, CGRect(x: 20, y: 80, width: 335, height: 210))
        XCTAssertEqual(both?.radius, 24, "Le contour suit le plus grand rayon")
    }
}
