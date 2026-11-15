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

    func testTheProposalFallsBackToTheCaloriesLeft() {
        XCTAssertEqual(SpaceCatalog.proposal(for: [], isPremium: false).kind, .caloriesLeft)
        XCTAssertEqual(SpaceCatalog.proposal(for: [.markets], isPremium: false).kind, .caloriesLeft)
        XCTAssertEqual(SpaceCatalog.proposal(for: [], isPremium: false).format, .small)
    }
}
