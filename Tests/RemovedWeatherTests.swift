import XCTest
@testable import Ardane

/// The weather was removed from Ardane: what an earlier version saved about it (widgets, merged widgets,
/// settings) is left out when read, and everything else stays.
@MainActor
final class RemovedWeatherTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return SharedStore(directory: directory)
    }

    private func encoded(_ design: WidgetDesign) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return String(decoding: try encoder.encode(design), as: UTF8.self)
    }

    /// A saved list as an older version wrote it: every `countdown` stands for the removed `weather`
    /// where the design is marked, so the JSON holds a kind this version no longer knows.
    private func oldJSON(_ designs: [(design: WidgetDesign, wasWeather: Bool)]) throws -> Data {
        let items = try designs.map { entry -> String in
            let text = try encoded(entry.design)
            return entry.wasWeather ? text.replacingOccurrences(of: "\"kind\":\"countdown\"", with: "\"kind\":\"weather\"") : text
        }
        return Data(("[" + items.joined(separator: ",") + "]").utf8)
    }

    private func part(_ kind: WidgetKind, _ name: String) -> ComboPart {
        ComboPart(kind: kind, options: DesignOptions(), name: name, size: .small)
    }

    func testAWeatherWidgetIsLeftOutAndTheOthersStay() throws {
        let clock = WidgetDesign(kind: .clock)
        let weather = WidgetDesign(kind: .countdown)
        let note = WidgetDesign(kind: .note)
        let data = try oldJSON([(clock, false), (weather, true), (note, false)])
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"weather\""), "The old JSON holds the removed kind")

        let list = try JSONDecoder().decode(LossyList<WidgetDesign>.self, from: data)
        XCTAssertEqual(list.elements.map(\.id), [clock.id, note.id], "The weather widget goes, the two others stay in order")
        XCTAssertNil(WidgetKind(rawValue: "weather"))
        XCTAssertNil(WidgetKind(rawValue: "sunCycle"))
        XCTAssertNil(WidgetKind(rawValue: "destinationWeather"))
    }

    func testTheStoreAndTheAppReadTheDesignsThatSurvive() throws {
        let store = temporaryStore()
        let clock = WidgetDesign(kind: .clock)
        let weather = WidgetDesign(kind: .countdown)
        store.setRawData(try oldJSON([(weather, true), (clock, false)]), for: .designs)
        XCTAssertEqual(store.designs.map(\.id), [clock.id], "One unreadable widget no longer empties the whole list")
        XCTAssertEqual(AppModel(store: store).designs.map(\.id), [clock.id])
    }

    func testAMergedWidgetKeepsItsOtherWidgets() throws {
        var merged = WidgetDesign(kind: .clock)
        merged.options.parts = [part(.clock, "A"), part(.countdown, "B"), part(.note, "C")]
        // Only the second part is a `countdown` in the JSON, so only it becomes the removed kind.
        let data = try oldJSON([(merged, true)])
        let list = try JSONDecoder().decode(LossyList<WidgetDesign>.self, from: data)
        let read = try XCTUnwrap(list.elements.first)
        XCTAssertEqual(read.options.parts.map(\.name), ["A", "C"], "The weather part goes, the others stay")
        XCTAssertEqual(read.kind, .clock)
    }

    func testAMergedWidgetLedByTheWeatherTakesItsFirstRemainingWidget() throws {
        var merged = WidgetDesign(kind: .countdown)
        merged.options.parts = [part(.countdown, "A"), part(.note, "B")]
        // Both the widget's own kind and its first part carry the removed kind.
        let list = try JSONDecoder().decode(LossyList<WidgetDesign>.self, from: try oldJSON([(merged, true)]))
        let read = try XCTUnwrap(list.elements.first, "The merged widget is kept")
        XCTAssertEqual(read.kind, .note)
        XCTAssertEqual(read.options.parts.map(\.name), ["B"])
    }

    func testSettingsKeepEverythingButTheWeatherChoices() throws {
        let json = #"{"profileName":"Léa","currencyCode":"EUR","temperatureUnit":"fahrenheit","weatherLocation":{"name":"Montréal","latitude":45.5,"longitude":-73.6},"dailyAdded":["weather","cat-weather","cat-steps"]}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.profileName, "Léa")
        XCTAssertEqual(settings.currencyCode, "EUR")
        XCTAssertEqual(DailyCategories.added(settings), [.steps], "The weather entries of Mon Quotidien are ignored")
    }

    func testTheProfileIgnoresTheWeatherInterestAndTopic() throws {
        let json = #"{"interests":["sport","weather","budget"],"skippedTopics":["weather","money"]}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.interests, [.sport, .budget])
        XCTAssertEqual(profile.skippedTopics, [.money])
    }

    func testAnOldDeepLinkToTheWeatherOpensNothing() {
        XCTAssertNil(DeepLink(url: URL(string: "tessera://weather")!))
    }
}
