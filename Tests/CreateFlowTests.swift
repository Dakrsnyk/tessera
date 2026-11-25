import XCTest
import WidgetKit
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

/// Le parcours « taille d'abord » : Taille, Catégorie, widgets, Atelier. Un seul widget au bout, seul ou réuni.
@MainActor
final class CreateSizeFirstFlowTests: XCTestCase {
    private func hasSmall(_ kind: WidgetKind) -> Bool { kind.families.contains(.systemSmall) }

    /// Une catégorie qui propose au moins `count` widgets existant en petit à cette taille, avec ces widgets.
    private func category(offering count: Int, format: WidgetFormat) -> (CreateCategory, [WidgetKind])? {
        for category in CreateCategory.all(preferred: []) {
            let kinds = category.kinds(for: format).filter { hasSmall($0) }
            if kinds.count >= count { return (category, kinds) }
        }
        return nil
    }

    // MARK: Étapes

    func testStepsFollowSizeThenCategoryThenPick() {
        let format = WidgetFormat.medium
        let pick = CreateStep.pick(format, .space(.life))
        // « Changer de widget » revient aux catégories, à la même taille.
        if case let .pick(back, _) = pick {
            XCTAssertEqual(CreateStep.category(back), CreateStep.category(.medium))
        } else {
            XCTFail("pick attendu")
        }
        XCTAssertNotEqual(CreateStep.category(.small), CreateStep.category(.large))
        XCTAssertNotEqual(CreateStep.pick(.small, .time), CreateStep.pick(.medium, .time))
        XCTAssertNotEqual(CreateStep.size, CreateStep.category(.small))
    }

    /// Le retour remonte d'une étape : widgets → catégories (même taille) → tailles ; aux tailles, il ne bouge plus.
    func testBackGoesUpOneStepAndKeepsTheSize() {
        XCTAssertEqual(CreateStep.pick(.medium, .time).back, .category(.medium))
        XCTAssertEqual(CreateStep.pick(.large, .space(.life)).back, .category(.large))
        XCTAssertEqual(CreateStep.category(.small).back, .size)
        XCTAssertEqual(CreateStep.size.back, .size)
    }

    // MARK: Catégories

    func testCategoriesAreTimeThenSpacesThenPhotosWithoutDuplicate() {
        let all = CreateCategory.all(preferred: [])
        XCTAssertEqual(all.count, Space.offered.count + 2)
        XCTAssertEqual(all.first, .time)
        XCTAssertEqual(all.last, .photos)
        XCTAssertEqual(Set(all.map { $0.id }).count, all.count)
        for space in Space.offered { XCTAssertTrue(all.contains(.space(space)), "Espace absent : \(space.rawValue)") }
        XCTAssertFalse(all.contains(.space(.car)), "Auto est retiré (PDG, 2026-11-25)")
    }

    func testPreferredSpacesComeFirstWithoutDuplicates() {
        let preferred: [Space] = [Space.allCases[1], Space.allCases[0]]
        let all = CreateCategory.all(preferred: preferred)
        XCTAssertEqual(all[1], .space(preferred[0]))
        XCTAssertEqual(all[2], .space(preferred[1]))
        XCTAssertEqual(Set(all.map { $0.id }).count, all.count)
        XCTAssertEqual(all.count, Space.offered.count + 2)
        // Un ancien compte qui avait choisi Auto ne retrouve pas la catégorie.
        XCTAssertEqual(CreateCategory.all(preferred: [.car] + preferred), all)
    }

    func testEveryCategoryOffersWidgetsInSmallExceptPhotos() {
        for category in CreateCategory.all(preferred: []) where category != .photos {
            XCTAssertFalse(category.kinds.isEmpty, "Catégorie vide : \(category.id)")
            XCTAssertFalse(category.kinds(for: .small).isEmpty, "Rien en petit : \(category.id)")
            XCTAssertFalse(category.kinds(for: .medium).isEmpty, "Rien en moyen : \(category.id)")
            XCTAssertFalse(category.kinds(for: .large).isEmpty, "Rien en grand : \(category.id)")
        }
        XCTAssertTrue(CreateCategory.photos.kinds.isEmpty, "Photos et citations ont leur propre éditeur")
    }

    func testCategoryKindsForASizeAreFilteredByFamily() {
        for category in CreateCategory.all(preferred: []) {
            for kind in category.kinds(for: .small) { XCTAssertTrue(hasSmall(kind), "\(kind.rawValue) n'existe pas en petit") }
            for format in [WidgetFormat.medium, .large] {
                for kind in category.kinds(for: format) {
                    XCTAssertTrue(hasSmall(kind) || kind.families.contains(.systemMedium), "\(kind.rawValue) ne tient pas en \(format.rawValue)")
                }
            }
        }
    }

    func testTimeCategoryHasNoSpaceWidgets() {
        XCTAssertFalse(CreateCategory.time.kinds.isEmpty)
        for kind in CreateCategory.time.kinds { XCTAssertNil(kind.space) }
    }

    // MARK: Places

    func testRoomPerSize() {
        XCTAssertEqual(CreationDraft(format: .small).room, 1)
        XCTAssertEqual(CreationDraft(format: .medium).room, 2)
        XCTAssertEqual(CreationDraft(format: .large).room, 4)
    }

    func testEmptyDraftIsNotReadyAndHasNoDesign() {
        for format in WidgetFormat.allCases {
            let draft = CreationDraft(format: format)
            XCTAssertFalse(draft.isReady)
            XCTAssertNil(draft.design)
            XCTAssertNil(draft.blocker, "Rien de choisi : pas de reproche")
            XCTAssertTrue(draft.picked.isEmpty)
        }
    }

    // MARK: Petit

    func testSmallHoldsOneWidgetAndANewPickReplacesTheOld() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 2, format: .small))
        var draft = CreationDraft(format: .small)
        draft.toggle(kinds[0])
        XCTAssertEqual(draft.picked, [kinds[0]])
        XCTAssertTrue(draft.isReady)
        draft.toggle(kinds[1])
        XCTAssertEqual(draft.picked, [kinds[1]], "Petit : un nouveau choix remplace l'ancien")
        XCTAssertNil(draft.refusal(adding: kinds[0]), "Petit ne refuse pas un widget qui existe en petit")
    }

    func testSmallTouchingThePickedWidgetKeepsItSoTheAtelierOpensAgain() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 1, format: .small))
        var draft = CreationDraft(format: .small)
        draft.toggle(kinds[0])
        draft.toggle(kinds[0])
        XCTAssertEqual(draft.picked, [kinds[0]])
        XCTAssertNotNil(draft.design)
    }

    func testSmallDesignIsOneSingleSmallWidget() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 1, format: .small))
        var draft = CreationDraft(format: .small)
        draft.toggle(kinds[0])
        let design = try XCTUnwrap(draft.design)
        XCTAssertEqual(design.kind, kinds[0])
        XCTAssertEqual(design.format, .small)
        XCTAssertFalse(design.isCombo)
    }

    // MARK: Moyen

    func testMediumAcceptsOneThenTwoAndRefusesAThird() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 3, format: .medium))
        var draft = CreationDraft(format: .medium)
        draft.toggle(kinds[0])
        XCTAssertEqual(draft.picked.count, 1)
        draft.toggle(kinds[1])
        XCTAssertEqual(draft.picked, [kinds[0], kinds[1]])
        XCTAssertTrue(draft.isReady)
        XCTAssertNotNil(draft.refusal(adding: kinds[2]), "Moyen : 2 au plus, avec une raison")
        draft.toggle(kinds[2])
        XCTAssertEqual(draft.picked, [kinds[0], kinds[1]], "Le troisième n'est pas ajouté")
    }

    func testMediumCanStopAtOneAndTheWidgetIsSingle() throws {
        let medium = try XCTUnwrap(CreateCategory.all(preferred: []).flatMap { $0.kinds(for: .medium) }
            .first { $0.families.contains(.systemMedium) })
        var draft = CreationDraft(format: .medium)
        draft.toggle(medium)
        let design = try XCTUnwrap(draft.design)
        XCTAssertFalse(design.isCombo)
        XCTAssertEqual(design.format, .medium)
        XCTAssertEqual(design.kind, medium)
    }

    func testMediumTwoWidgetsMakeOneComboOfTwoSmallPartsInPickOrder() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 2, format: .medium))
        var draft = CreationDraft(format: .medium)
        draft.toggle(kinds[1])
        draft.toggle(kinds[0])
        let design = try XCTUnwrap(draft.design)
        XCTAssertTrue(design.isCombo)
        XCTAssertEqual(design.format, .medium)
        XCTAssertEqual(design.options.parts.map { $0.kind }, [kinds[1], kinds[0]])
        XCTAssertEqual(design.options.parts.map { $0.size }, [.small, .small])
        XCTAssertEqual(design.displayFormat, .medium)
    }

    func testMediumRefusesASecondWidgetThatHasNoSmallSize() throws {
        let noSmall = WidgetKind.offered.first { !hasSmall($0) && $0.families.contains(.systemMedium) }
        let other = WidgetKind.offered.first { hasSmall($0) }
        guard let noSmall, let other else { throw XCTSkip("Aucun widget sans petite taille") }
        var draft = CreationDraft(format: .medium)
        draft.toggle(other)
        XCTAssertNotNil(draft.refusal(adding: noSmall))
        draft.toggle(noSmall)
        XCTAssertEqual(draft.picked, [other])
        // Seul, il existe en moyen : accepté.
        var alone = CreationDraft(format: .medium)
        XCTAssertNil(alone.refusal(adding: noSmall))
        alone.toggle(noSmall)
        XCTAssertTrue(alone.isReady)
    }

    // MARK: Grand

    func testLargeAcceptsUpToFourAndRefusesAFifth() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 5, format: .large))
        var draft = CreationDraft(format: .large)
        for kind in kinds.prefix(4) { draft.toggle(kind) }
        XCTAssertEqual(draft.picked, Array(kinds.prefix(4)))
        XCTAssertNotNil(draft.refusal(adding: kinds[4]), "Grand : 4 au plus, avec une raison")
        draft.toggle(kinds[4])
        XCTAssertEqual(draft.picked.count, 4)
    }

    func testLargeFourSmallWidgetsMakeOneComboOfFourSmallParts() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 4, format: .large))
        var draft = CreationDraft(format: .large)
        for kind in kinds.prefix(4) { draft.toggle(kind) }
        let design = try XCTUnwrap(draft.design)
        XCTAssertTrue(design.isCombo)
        XCTAssertEqual(design.format, .large)
        XCTAssertEqual(design.options.parts.map { $0.kind }, Array(kinds.prefix(4)))
        XCTAssertEqual(design.options.parts.map { $0.size }, [.small, .small, .small, .small])
    }

    func testLargeThreeWidgetsHaveOneMediumRowAndTwoSmall() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 3, format: .large))
        guard let wide = kinds.first(where: { $0.families.contains(.systemMedium) }) else { throw XCTSkip("Aucun widget moyen") }
        let three = Array(([wide] + kinds.filter { $0 != wide }).prefix(3))
        var draft = CreationDraft(format: .large)
        for kind in three { draft.toggle(kind) }
        let design = try XCTUnwrap(draft.design, "3 widgets en grand devraient former un widget : \(String(describing: draft.blocker))")
        let sizes = design.options.parts.map { $0.size }
        XCTAssertEqual(sizes.filter { $0 == .medium }.count, 1)
        XCTAssertEqual(sizes.filter { $0 == .small }.count, 2)
        XCTAssertEqual(design.options.parts.map { $0.kind }, three)
        XCTAssertEqual(design.format, .large)
    }

    func testLargeOneWidgetWithoutALargeLayoutExplainsWhatToDo() throws {
        let noLarge = try XCTUnwrap(WidgetKind.offered.first { !$0.families.contains(.systemLarge) && hasSmall($0) })
        var draft = CreationDraft(format: .large)
        draft.toggle(noLarge)
        XCTAssertFalse(draft.isReady)
        XCTAssertNil(draft.design)
        XCTAssertNotNil(draft.blocker)
    }

    func testLargeOneWidgetWithALargeLayoutIsSingleAtLargeSize() throws {
        guard let large = CreateCategory.all(preferred: []).flatMap({ $0.kinds(for: .large) })
            .first(where: { $0.families.contains(.systemLarge) }) else { throw XCTSkip("Aucun widget grand") }
        var draft = CreationDraft(format: .large)
        draft.toggle(large)
        let design = try XCTUnwrap(draft.design)
        XCTAssertFalse(design.isCombo)
        XCTAssertEqual(design.format, .large)
    }

    // MARK: Sélection et places

    func testTogglingAPickedWidgetTakesItOutAndFreesAPlace() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 3, format: .large))
        var draft = CreationDraft(format: .large)
        draft.toggle(kinds[0])
        draft.toggle(kinds[1])
        draft.toggle(kinds[2])
        draft.toggle(kinds[1])
        XCTAssertEqual(draft.picked, [kinds[0], kinds[2]], "Le retrait garde l'ordre des autres")
        XCTAssertEqual(draft.room - draft.picked.count, 2)
        draft.toggle(kinds[1])
        XCTAssertEqual(draft.picked, [kinds[0], kinds[2], kinds[1]])
    }

    func testNoDuplicateInThePicks() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 2, format: .large))
        var draft = CreationDraft(format: .large)
        for _ in 0..<3 { draft.toggle(kinds[0]) }
        XCTAssertEqual(draft.picked, [kinds[0]])
        for _ in 0..<3 { draft.toggle(kinds[1]) }
        XCTAssertEqual(Set(draft.picked).count, draft.picked.count)
    }

    func testAPickedWidgetIsNeverRefusedEvenWhenFull() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 2, format: .medium))
        var draft = CreationDraft(format: .medium)
        draft.toggle(kinds[0])
        draft.toggle(kinds[1])
        XCTAssertNil(draft.refusal(adding: kinds[0]))
        XCTAssertNil(draft.refusal(adding: kinds[1]))
    }

    func testPlacesTakenAndFreeAfterEachAddAndRemove() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 4, format: .large))
        var draft = CreationDraft(format: .large)
        for (index, kind) in kinds.prefix(4).enumerated() {
            draft.toggle(kind)
            XCTAssertEqual(draft.picked.count, index + 1)
            XCTAssertEqual(draft.room - draft.picked.count, 3 - index)
        }
        for expectedTaken in stride(from: 3, through: 0, by: -1) {
            draft.toggle(draft.picked[draft.picked.count - 1])
            XCTAssertEqual(draft.picked.count, expectedTaken)
            XCTAssertEqual(draft.room - draft.picked.count, 4 - expectedTaken)
        }
        XCTAssertFalse(draft.isReady)
    }

    func testTheCombinedWidgetIsOneDesignNamedAfterItsParts() throws {
        let (_, kinds) = try XCTUnwrap(category(offering: 2, format: .medium))
        var draft = CreationDraft(format: .medium)
        draft.toggle(kinds[0])
        draft.toggle(kinds[1])
        let design = try XCTUnwrap(draft.design)
        XCTAssertEqual(design.options.parts.count, 2)
        XCTAssertEqual(design.name, design.options.parts.map { $0.name }.joined(separator: " + "))
    }

    // MARK: Plan du compositeur

    func testPlanRefusesTooManyWidgetsAtEverySize() {
        let kinds = Array(WidgetKind.offered.filter { hasSmall($0) }.prefix(5))
        guard kinds.count == 5 else { return XCTFail("Il faut au moins 5 widgets existant en petit") }
        for (format, count) in [(WidgetFormat.small, 2), (.medium, 3), (.large, 5)] {
            guard case .invalid = Composer.plan(Array(kinds.prefix(count)), format: format) else {
                return XCTFail("\(count) widgets en \(format.rawValue) devraient être refusés")
            }
        }
    }

    func testDraftsAreEqualOnlyWithTheSameSizeAndPicks() throws {
        var a = CreationDraft(format: .medium)
        let b = CreationDraft(format: .medium)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, CreationDraft(format: .large))
        let kind = try XCTUnwrap(WidgetKind.offered.first { hasSmall($0) })
        a.toggle(kind)
        XCTAssertNotEqual(a, b)
    }

    /// Every widget of a category shows the same look, and no two categories share one; all free (PDG, 2026-11-22).
    func testEachCategoryHasItsOwnFreeLook() {
        let categories = CreateCategory.all(preferred: [])
        var seen = Set<String>()
        for category in categories {
            let look = category.look
            XCTAssertFalse(ThemeCatalog.theme(look.theme).isPremium, "\(category.id) : thème Premium")
            XCTAssertTrue(Palette.freeAccents.contains { $0.hex == look.accentHex }, "\(category.id) : couleur Premium")
            XCTAssertTrue(seen.insert("\(look.theme.rawValue)-\(look.accentHex)").inserted, "\(category.id) : même style qu'une autre catégorie")
            for kind in category.kinds {
                let design = category.design(for: kind)
                XCTAssertEqual(design.themeID, look.theme, "\(kind.rawValue) dans \(category.id)")
                XCTAssertEqual(design.accentHex, look.accentHex, "\(kind.rawValue) dans \(category.id)")
            }
        }
        // The widget made from the picks keeps the category's look.
        var draft = CreationDraft(format: .small, category: .space(.nutrition))
        draft.toggle(.caloriesLeft)
        XCTAssertEqual(draft.design?.themeID, CreateCategory.space(.nutrition).look.theme)
        // Combined too (Moyen, two widgets).
        var combo = CreationDraft(format: .medium, category: .space(.fitness))
        combo.toggle(.nextSet)
        combo.toggle(.trainingStreak)
        let look = CreateCategory.space(.fitness).look
        XCTAssertEqual(combo.design?.themeID, look.theme)
        XCTAssertEqual(combo.design?.accentHex, look.accentHex)
    }
}
