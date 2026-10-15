import WidgetKit
import XCTest
@testable import Tessera

/// « Mes widgets » on the Home Screen: a placed widget keeps the widget it was added with (or the one
/// chosen in « Modifier le widget »), whatever is made afterwards; the gallery offers the latest widget
/// of each size. And the Lock Screen scanner opens the app on the scanner.
@MainActor
final class WidgetGalleryTests: XCTestCase {
    private func design(_ name: String, format: WidgetFormat, minutesAgo: Double) -> WidgetDesign {
        var design = WidgetDesign(name: name, kind: .note, format: format)
        design.lastUsedAt = Date().addingTimeInterval(-minutesAgo * 60)
        return design
    }

    func testANewWidgetKeepsTheLatestWidgetOfItsSizeWhateverIsMadeAfterwards() throws {
        let small = design("Petit A", format: .small, minutesAgo: 30)
        let medium = design("Moyen B", format: .medium, minutesAgo: 10)
        let id = try XCTUnwrap(MyWidgetsChoice.newestID(in: [small, medium]))
        XCTAssertTrue(MyWidgetsChoice.isNewestID(id))
        XCTAssertNil(UUID(uuidString: id))
        XCTAssertEqual(MyWidgetsChoice.resolve(id, family: .systemSmall, designs: [small, medium], remembered: nil).design, small)
        XCTAssertEqual(MyWidgetsChoice.resolve(id, family: .systemMedium, designs: [small, medium], remembered: nil).design, medium)
        // No large widget made: the latest that fits the size.
        XCTAssertEqual(MyWidgetsChoice.resolve(id, family: .systemLarge, designs: [small, medium], remembered: nil).design, medium)

        // A widget of the same size made afterwards: the widget already placed doesn't change…
        let newer = design("Petit C", format: .small, minutesAgo: 1)
        let all = [small, medium, newer]
        let placed = MyWidgetsChoice.resolve(id, family: .systemSmall, designs: all, remembered: nil)
        XCTAssertEqual(placed.design, small)
        XCTAssertFalse(placed.isFallback)
        // …and a widget added now gets the new one, which the gallery shows.
        let added = try XCTUnwrap(MyWidgetsChoice.newestID(in: all))
        XCTAssertEqual(MyWidgetsChoice.resolve(added, family: .systemSmall, designs: all, remembered: nil).design, newer)
        XCTAssertEqual(MyWidgetsChoice.latest(in: all, for: .systemSmall), newer)
    }

    func testAWidgetChosenInModifierLeWidgetNeverChanges() {
        let chosen = design("Choisi", format: .medium, minutesAgo: 60)
        let newer = design("Plus récent", format: .medium, minutesAgo: 1)
        let resolution = MyWidgetsChoice.resolve(chosen.id.uuidString, family: .systemMedium, designs: [chosen, newer], remembered: newer.id)
        XCTAssertEqual(resolution.design, chosen)
        XCTAssertFalse(resolution.isFallback)
    }

    func testAWidgetPlacedWithoutChoiceKeepsTheOneRememberedForItsSize() {
        let first = design("Premier", format: .small, minutesAgo: 60)
        let newer = design("Nouveau", format: .small, minutesAgo: 1)
        let kept = MyWidgetsChoice.resolve(nil, family: .systemSmall, designs: [first, newer], remembered: first.id)
        XCTAssertEqual(kept.design, first, "Placed by an earlier version: no longer follows the latest widget")
        XCTAssertTrue(kept.isFallback)
        // Nothing remembered yet, or the remembered widget deleted: the latest of the size, remembered from then on.
        XCTAssertEqual(MyWidgetsChoice.resolve(nil, family: .systemSmall, designs: [first, newer], remembered: nil).design, newer)
        XCTAssertEqual(MyWidgetsChoice.resolve(nil, family: .systemSmall, designs: [newer], remembered: first.id).design, newer)
    }

    func testADeletedWidgetFallsBackAndNoWidgetShowsTheInvitation() throws {
        let gone = design("Supprimé", format: .small, minutesAgo: 5)
        let other = design("Autre", format: .small, minutesAgo: 50)
        let id = try XCTUnwrap(MyWidgetsChoice.newestID(in: [gone, other]))
        let resolution = MyWidgetsChoice.resolve(id, family: .systemSmall, designs: [other], remembered: nil)
        XCTAssertEqual(resolution.design, other)
        XCTAssertTrue(resolution.isFallback)
        XCTAssertNil(MyWidgetsChoice.resolve(gone.id.uuidString, family: .systemSmall, designs: [], remembered: nil).design)
        XCTAssertNil(MyWidgetsChoice.newestID(in: []), "Before the first widget, a widget added shows the invitation")
    }

    func testModifierLeWidgetListsEveryWidgetTheLatestFirst() {
        let old = design("Ancien", format: .large, minutesAgo: 600)
        let mid = design("Milieu", format: .small, minutesAgo: 60)
        let new = design("Nouveau", format: .medium, minutesAgo: 1)
        XCTAssertEqual(MyWidgetsChoice.recent([old, new, mid]).map(\.name), ["Nouveau", "Milieu", "Ancien"])
    }

    func testLockScreenWidgetsIgnoreTheDefaultOfMesWidgets() throws {
        let id = try XCTUnwrap(MyWidgetsChoice.newestID(in: [design("A", format: .small, minutesAgo: 1)]))
        // Neither a saved widget nor a catalog widget: the Lock Screen essentials keep their own content.
        XCTAssertNil(UUID(uuidString: id))
        XCTAssertNil(DesignEntity.starterKind(id))
        XCTAssertNil(MyWidgetsChoice.newestDesignID(id, for: .accessoryRectangular))
        XCTAssertEqual(DesignEntity(newestID: id).id, id)
    }

    func testTheGuideNeverDescribesAWidgetThatOnlySharesTheName() {
        let older = design("Calories restantes", format: .small, minutesAgo: 60)
        let newer = design("Calories restantes", format: .small, minutesAgo: 1)
        let other = design("Météo", format: .medium, minutesAgo: 5)
        let all = [older, newer, other]
        XCTAssertNil(AddToHomeScreenGuide.subject(id: nil, name: "Calories restantes", in: all), "Two namesakes: generic steps")
        XCTAssertEqual(AddToHomeScreenGuide.subject(id: older.id, name: "Calories restantes", in: all), older)
        XCTAssertEqual(AddToHomeScreenGuide.subject(id: nil, name: "Météo", in: all), other)
        XCTAssertNil(AddToHomeScreenGuide.subject(id: nil, name: nil, in: all))
    }

    func testTheScannerWidgetAndControlOpenTheScanner() {
        XCTAssertEqual(DeepLink.scanFood.url.absoluteString, "tessera://scan-food")
        XCTAssertEqual(DeepLink(url: DeepLink.scanFood.url), .scanFood)
        XCTAssertEqual(ArdaneScreen.foodScanner.link, .scanFood)
    }
}
