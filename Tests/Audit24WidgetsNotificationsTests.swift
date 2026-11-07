import UIKit
import UserNotifications
import XCTest
@testable import Ardane

/// Audit 24 (widgets, Studio, notifications): fusion keeps its background photo, countdown reminders of
/// combined widgets, where a tap on a notification leads, and iOS's ceiling of 64 pending notifications.
final class Audit24WidgetsNotificationsTests: XCTestCase {
    // MARK: W-03 fusion and the background photo

    private func savedPhotoName() throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        return try XCTUnwrap(ImageStore.save(image))
    }

    func testMergedWidgetKeepsItsBackgroundWhenTheOriginalsAreDeleted() throws {
        let name = try savedPhotoName()
        defer { ImageStore.delete(named: name) }
        let first = WidgetDesign(kind: .caloriesLeft, background: .photo(name), format: .small)
        let second = WidgetDesign(kind: .proteinLeft, format: .small)
        let merged = try XCTUnwrap(Fusion.merge([first, second]))
        guard case let .photo(copy) = merged.background else { return XCTFail("the merged widget lost its photo") }
        defer { ImageStore.delete(named: copy) }
        XCTAssertNotEqual(copy, name, "the merged widget needs its own file")
        // What `AppModel.delete` does to an original.
        ImageStore.delete(named: name)
        XCTAssertNotNil(ImageStore.image(named: copy))
    }

    func testPreviewMergeLeavesNoCopyBehind() throws {
        let name = try savedPhotoName()
        defer { ImageStore.delete(named: name) }
        let first = WidgetDesign(kind: .caloriesLeft, background: .photo(name), format: .small)
        let second = WidgetDesign(kind: .proteinLeft, format: .small)
        let before = Set(ImageStore.allNames())
        let preview = try XCTUnwrap(Fusion.merge([first, second], copiesBackground: false))
        XCTAssertEqual(preview.background, .photo(name))
        XCTAssertEqual(Set(ImageStore.allNames()), before)
    }

    func testMergedBackgroundWithoutAFileFallsBackToTheTheme() {
        let missing = "\(UUID().uuidString).jpg"
        XCTAssertEqual(Fusion.ownBackground(of: .photo(missing)), .theme)
        XCTAssertEqual(Fusion.ownBackground(of: .gradient), .gradient)
    }

    // MARK: W-04 countdown reminders in a combined widget

    private func countdownOptions(reminder: Bool, daysAhead: Int = 10) -> DesignOptions {
        var options = DesignOptions()
        options.countdownTitle = "Vacances"
        options.countdownDate = Date().addingTimeInterval(Double(daysAhead) * 86_400)
        options.countdownMode = .until
        options.countdownReminder = reminder
        return options
    }

    func testCountdownReminderOfACombinedWidgetIsScheduled() {
        var combo = DesignOptions()
        combo.parts = [
            ComboPart(kind: .clock, options: DesignOptions(), name: "Horloge", size: .small),
            ComboPart(kind: .countdown, options: countdownOptions(reminder: true), name: "Vacances", size: .small),
        ]
        let design = WidgetDesign(kind: .clock, options: combo, format: .medium)
        let requests = NotificationScheduler.countdownRequests(for: design)
        XCTAssertEqual(requests.map(\.identifier), [NotificationScheduler.countdownID(design.id, part: 1)])
        XCTAssertEqual(requests.first?.content.title, "Vacances")
        XCTAssertTrue(requests.first?.trigger is UNCalendarNotificationTrigger)
    }

    func testCountdownReminderIsKeptByAMergedWidgetAndNotOtherwise() {
        var combo = DesignOptions()
        combo.parts = [ComboPart(kind: .countdown, options: countdownOptions(reminder: false), name: "Vacances", size: .small),
                       ComboPart(kind: .clock, options: DesignOptions(), name: "Horloge", size: .small)]
        XCTAssertTrue(NotificationScheduler.countdownRequests(for: WidgetDesign(kind: .countdown, options: combo, format: .medium)).isEmpty)
        combo.parts[0].options.countdownReminder = true
        let design = WidgetDesign(kind: .countdown, options: combo, format: .medium)
        XCTAssertEqual(NotificationScheduler.countdownRequests(for: design).map(\.identifier),
                       [NotificationScheduler.countdownID(design.id, part: 0)])
    }

    func testSingleCountdownKeepsItsOwnIdentifierAndPastDaysGiveNothing() {
        let design = WidgetDesign(kind: .countdown, options: countdownOptions(reminder: true), format: .small)
        XCTAssertEqual(NotificationScheduler.countdownRequests(for: design).map(\.identifier), [NotificationScheduler.countdownID(design.id)])
        let past = WidgetDesign(kind: .countdown, options: countdownOptions(reminder: true, daysAhead: -3), format: .small)
        XCTAssertTrue(NotificationScheduler.countdownRequests(for: past).isEmpty)
    }

    // MARK: W-10 a tap on a notification

    func testNotificationsRouteToTheirScreen() {
        let id = UUID()
        XCTAssertEqual(NotificationRoute.link(for: NotificationScheduler.countdownID(id)), .design(id))
        XCTAssertEqual(NotificationRoute.link(for: NotificationScheduler.countdownID(id, part: 1)), .design(id))
        XCTAssertEqual(NotificationRoute.link(for: "tessera.habit.\(UUID().uuidString)"), .space("habits"))
        XCTAssertEqual(NotificationRoute.link(for: Encouragements.prefix + Encouragements.Kind.meal.rawValue + ".2026-11-07"), .space("nutrition"))
        XCTAssertEqual(NotificationRoute.link(for: Encouragements.prefix + Encouragements.Kind.workout.rawValue + ".2026-11-07"), .space("fitness"))
        XCTAssertEqual(NotificationRoute.link(for: NotificationEngine.prefix + NotificationEngine.Kind.lunch.rawValue + ".2026-11-07"), .space("nutrition"))
        XCTAssertEqual(NotificationRoute.link(for: NotificationEngine.prefix + NotificationEngine.Kind.classSoon.rawValue + ".2026-11-07.\(UUID().uuidString)"), .space("student"))
        XCTAssertEqual(NotificationRoute.link(for: SmartReminders.prefix + "bill.\(UUID().uuidString).2026-11-08"), .space("budget"))
        XCTAssertNil(NotificationRoute.link(for: "tessera.focus.end"))
        XCTAssertNil(NotificationRoute.link(for: "tessera.countdown.pas-un-identifiant"))
    }

    func testEveryEngineKindHasARoute() {
        let kinds: [NotificationEngine.Kind] = [.lunch, .calories, .protein, .nutritionWeek, .hydration, .habitsLeft, .habitStreak,
                                                .habitRecord, .habitsWeek, .sessionsLeft, .steps, .nextSession, .fitnessWeek,
                                                .classSoon, .eventTomorrow, .busyTomorrow, .tasksLeft, .weightProgress,
                                                .goalsWeek, .weekStart, .legacyWorkout, .legacyMeals, .legacyBill]
        for kind in kinds {
            let link = NotificationRoute.link(for: NotificationEngine.prefix + kind.rawValue + ".2026-11-07")
            XCTAssertNotNil(link, "\(kind)")
            if let link { XCTAssertEqual(DeepLink(url: link.url), link) }
        }
    }

    // MARK: W-12 the ceiling of 64

    private func candidates(_ count: Int) -> [NotificationEngine.Candidate] {
        let start = Date().addingTimeInterval(3_600)
        // Handed over in reverse order: the cap must keep the soonest, not the first of the list.
        return (0..<count).reversed().map { index in
            NotificationEngine.Candidate(id: "tessera.smart.n.test.\(index)", category: .general, kind: .weekStart, title: "t", body: "b",
                                         date: start.addingTimeInterval(Double(index) * 3_600), basis: "", priority: 3, flexible: true)
        }
    }

    func testThePlanNeverPassesTheCeilingAndKeepsTheSoonest() {
        let plan = candidates(80)
        let kept = NotificationEngine.capped(plan, pendingOutside: 10)
        XCTAssertEqual(kept.count, NotificationEngine.systemLimit - NotificationEngine.reservedRoom - 10)
        XCTAssertLessThanOrEqual(kept.count + 10, NotificationEngine.systemLimit)
        XCTAssertEqual(kept.first?.id, "tessera.smart.n.test.0")
        XCTAssertEqual(kept.map(\.date), kept.map(\.date).sorted())
        XCTAssertTrue(NotificationEngine.capped(plan, pendingOutside: 200).isEmpty)
        XCTAssertEqual(NotificationEngine.capped(candidates(3), pendingOutside: 0).count, 3)
    }

    func testRoomLeftForOtherReminders() {
        XCTAssertEqual(NotificationScheduler.pendingLimit, 64)
        XCTAssertEqual(NotificationScheduler.room(pending: 10), 54)
        XCTAssertEqual(NotificationScheduler.room(pending: 64), 0)
        XCTAssertEqual(NotificationScheduler.room(pending: 90), 0)
    }

    func testTheHistoryOnlyKeepsWhatIsPlanned() {
        let suite = "audit24.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var log = NotificationLog()
        let when = Date().addingTimeInterval(3_600)
        log.entries = [NotificationLog.Entry(id: "a", categoryName: "general", date: when),
                       NotificationLog.Entry(id: "b", categoryName: "general", date: when)]
        log.save(defaults)
        NotificationEngine.forget(ids: ["a"], defaults: defaults)
        XCTAssertEqual(NotificationLog.load(defaults).entries.map(\.id), ["b"])
    }
}
