import XCTest
@testable import Ardane

/// Études is its own mini-app, apart from Planning: its space, its « Mes paramètres », and where a widget or a
/// reminder leads (the general schedule opens Planning, the studies open Études).
final class StudiesMiniAppTests: XCTestCase {
    func testStudentSpaceOpensStudies() {
        XCTAssertEqual(MiniApp(space: .student), .studies)
        XCTAssertEqual(MiniApp(space: .productivity), .planning)
        XCTAssertEqual(MiniApp.studies.space, .student)
        XCTAssertEqual(MiniApp.studies.symbol, "graduationcap.fill")
        XCTAssertEqual(MiniApp.studies.colorHex, "D6409F")
        XCTAssertEqual(MiniApp(rawValue: "studies"), .studies)
    }

    func testNoSettingsSubjectIsListedTwice() {
        XCTAssertEqual(MiniApp.studies.infoTopics, [.studies])
        XCTAssertFalse(MiniApp.planning.infoTopics.contains(.studies))
        let topics = MiniApp.allCases.flatMap(\.infoTopics)
        XCTAssertEqual(topics.count, Set(topics).count, "A topic of « Mes paramètres » appears once")
        let items = MiniApp.allCases.flatMap(\.settingsItems)
        XCTAssertEqual(items.count, Set(items).count)
        let toFill = MiniApp.allCases.flatMap(\.toFillItems)
        XCTAssertEqual(toFill.count, Set(toFill).count, "A card of « À remplir » appears in one mini-app only")
        XCTAssertTrue(MiniApp.studies.hasInfo)
    }

    func testWidgetsOpenTheRightMiniApp() {
        func link(_ kind: WidgetKind) -> URL {
            WidgetLinks.url(for: WidgetDesign.starter(for: kind), payload: WidgetPayload(), isPremium: true, isSaved: true)
        }
        let planning = DeepLink.space(Space.productivity.rawValue).url
        let studies = DeepLink.space(Space.student.rawValue).url
        XCTAssertEqual(link(.timetable), planning)
        XCTAssertEqual(link(.nextClass), planning)
        for kind in [WidgetKind.nextExam, .assignments, .gradeAverage, .semesterProgress, .flashcard, .studyHours] {
            XCTAssertEqual(link(kind), studies, "\(kind)")
        }
        // The student space leads to Études, the productivity space to Planning.
        XCTAssertEqual(DeepLink(url: studies), .space("student"))
        XCTAssertEqual(DeepLink(url: planning), .space("productivity"))
    }

    func testRemindersOpenTheRightMiniApp() {
        let day = "2026-11-17"
        let kind = NotificationEngine.Kind.self
        func link(_ identifier: String) -> DeepLink? { NotificationRoute.link(for: identifier) }
        let engine = NotificationEngine.prefix
        XCTAssertEqual(link(engine + kind.classSoon.rawValue + ".\(day).\(UUID().uuidString)"), .space("productivity"))
        XCTAssertEqual(link(engine + kind.busyTomorrow.rawValue + ".\(day)"), .space("productivity"))
        XCTAssertEqual(link(engine + kind.eventTomorrow.rawValue + ".\(day).agenda"), .space("productivity"))
        XCTAssertEqual(link(engine + kind.eventTomorrow.rawValue + ".\(day).\(UUID().uuidString)"), .space("student"), "An exam tomorrow opens Études")
        XCTAssertEqual(link(Encouragements.prefix + Encouragements.Kind.longStudy.rawValue + ".\(day)"), .space("student"))
        XCTAssertEqual(link(Encouragements.prefix + Encouragements.Kind.weeklyStudy.rawValue + ".\(day)"), .space("student"))
    }
}
