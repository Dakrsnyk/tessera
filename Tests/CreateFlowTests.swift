import XCTest
@testable import Ardane

/// L'onglet Créer s'ouvre sur un widget proposé : petit, et jamais Premium pour un compte gratuit.
@MainActor
final class CreateFlowTests: XCTestCase {
    func testTheProposalIsFreeForEverySpace() {
        for space in Space.allCases {
            let design = SpaceCatalog.proposal(for: [space], isPremium: false)
            XCTAssertFalse(design.usesPremiumFeatures, "Proposition Premium pour \(space.rawValue) : \(design.premiumFeatures)")
            XCTAssertEqual(design.format, .small)
        }
    }

    /// The guide after a save is counted in the settings: an old file without the count starts at zero.
    func testTheAddGuideCountIsKeptAndDefaultsToZero() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"hasCompletedOnboarding":true}"#.utf8))
        XCTAssertEqual(old.addGuideCount, 0)
        var settings = AppSettings()
        settings.addGuideCount = 2
        let again = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(again.addGuideCount, 2)
    }

    func testTheProposalFallsBackToTheCaloriesLeft() {
        XCTAssertEqual(SpaceCatalog.proposal(for: [], isPremium: false).kind, .caloriesLeft)
        XCTAssertEqual(SpaceCatalog.proposal(for: [.markets], isPremium: false).kind, .caloriesLeft)
        XCTAssertEqual(SpaceCatalog.proposal(for: [], isPremium: false).format, .small)
    }
}
