import XCTest
@testable import Tessera

/// Dépenses Apple Pay reçues par l'automatisation Raccourcis « Transaction » : lecture du montant,
/// nom du commerçant, catégorie devinée ou apprise, doublons, anciennes données sauvegardées.
@MainActor
final class ApplePayExpenseTests: XCTestCase {
    private let groceries = BudgetState.fixedID(1)
    private let restaurants = BudgetState.fixedID(2)
    private let transport = BudgetState.fixedID(3)
    private let outings = BudgetState.fixedID(4)
    private let home = BudgetState.fixedID(5)

    private func day(_ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private var now: Date { day(10, 24) }

    /// Le résultat d'un ajout, ramené à des valeurs simples pour les assertions.
    private func added(_ result: ApplePayResult) -> Expense? {
        if case .added(let expense) = result { return expense }
        return nil
    }

    private func isDuplicate(_ result: ApplePayResult) -> Bool {
        if case .duplicate = result { return true }
        return false
    }

    private func isIgnored(_ result: ApplePayResult) -> Bool {
        if case .ignored = result { return true }
        return false
    }

    // MARK: - Montants

    func testAmountsInFrenchAndEnglishFormats() {
        XCTAssertEqual(ApplePayExpense.parseAmount("12,50 $"), 12.5)
        XCTAssertEqual(ApplePayExpense.parseAmount("12.50 $"), 12.5)
        XCTAssertEqual(ApplePayExpense.parseAmount("$12.50"), 12.5)
        XCTAssertEqual(ApplePayExpense.parseAmount("12.50"), 12.5)
        XCTAssertEqual(ApplePayExpense.parseAmount("12,5"), 12.5)
        XCTAssertEqual(ApplePayExpense.parseAmount("3,00€"), 3)
        XCTAssertEqual(ApplePayExpense.parseAmount("CA$ 5.00"), 5)
        XCTAssertEqual(ApplePayExpense.parseAmount("  12,50 $  "), 12.5, "Les espaces autour ne comptent pas")
    }

    func testAmountsWithThousandsSeparators() throws {
        XCTAssertEqual(try XCTUnwrap(ApplePayExpense.parseAmount("1 234,56")), 1_234.56, accuracy: 0.0001)
        // Espace insécable (U+00A0) et fine insécable (U+202F), comme le formatage français d'iOS.
        XCTAssertEqual(try XCTUnwrap(ApplePayExpense.parseAmount("1\u{00A0}234,56")), 1_234.56, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(ApplePayExpense.parseAmount("1\u{202F}234,56\u{00A0}$")), 1_234.56, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(ApplePayExpense.parseAmount("1,234.56")), 1_234.56, accuracy: 0.0001)
    }

    func testUnusableAmountsAreNeverInvented() {
        XCTAssertNil(ApplePayExpense.parseAmount("abc"))
        XCTAssertNil(ApplePayExpense.parseAmount(""))
        XCTAssertNil(ApplePayExpense.parseAmount("   "))
        XCTAssertNil(ApplePayExpense.parseAmount("$"))
        XCTAssertNil(ApplePayExpense.parseAmount("0"), "Un montant nul n'est pas une dépense")
        XCTAssertNil(ApplePayExpense.parseAmount("0,00 $"))
    }

    func testARefundIsNotAnExpenseAmount() {
        XCTAssertNil(ApplePayExpense.parseAmount("-12.50"))
        XCTAssertNil(ApplePayExpense.parseAmount("-12,50 $"))
    }

    // MARK: - Commerçant

    func testMerchantNormalizationDropsTerminalNumberAndCity() {
        let normalized = ApplePayExpense.normalizedMerchant("TIM HORTONS #1234 MONTREAL QC")
        XCTAssertTrue(normalized.contains("tim hortons"), normalized)
        XCTAssertFalse(normalized.contains("1234"), normalized)
        XCTAssertFalse(normalized.contains("#"), normalized)
        XCTAssertEqual(normalized, normalized.lowercased())
    }

    func testMerchantNormalizationFoldsAccentsCaseAndSpaces() {
        XCTAssertEqual(ApplePayExpense.normalizedMerchant("Café Dépôt"), "cafe depot")
        XCTAssertEqual(ApplePayExpense.normalizedMerchant("  Tim    Hortons  "), "tim hortons")
        XCTAssertEqual(ApplePayExpense.normalizedMerchant("Tim\tHortons"), "tim hortons")
        XCTAssertEqual(ApplePayExpense.normalizedMerchant("IGA"), "iga")
    }

    func testMerchantNormalizationOfNothing() {
        XCTAssertEqual(ApplePayExpense.normalizedMerchant(""), "")
        XCTAssertEqual(ApplePayExpense.normalizedMerchant("   "), "")
    }

    func testTheSameMerchantWrittenDifferentlyNormalizesTheSame() {
        XCTAssertEqual(ApplePayExpense.normalizedMerchant("TIM HORTONS #1234 MONTREAL QC"),
                       ApplePayExpense.normalizedMerchant("Tim Hortons #88 LAVAL QC"))
    }

    // MARK: - Catégorie

    func testBuiltInKeywordsPickAnExistingCategory() {
        let state = BudgetState()
        let merchants = ["Tim Hortons", "Starbucks", "McDonald's", "Restaurant Le Pied de Cochon",
                         "IGA", "Metro Épicerie", "Super C", "Maxi", "Provigo",
                         "Petro-Canada", "Esso", "Shell",
                         "STM", "Uber", "Opus Bus",
                         "Netflix", "Spotify", "Apple.com/bill",
                         "Pharmaprix", "Jean Coutu", "Familiprix"]
        for merchant in merchants {
            guard let id = ApplePayExpense.categoryID(for: merchant, in: state) else {
                XCTFail("« \(merchant) » devrait avoir une catégorie intégrée")
                continue
            }
            XCTAssertNotNil(state.category(id), "« \(merchant) » doit pointer vers une catégorie qui existe dans le budget")
        }
    }

    func testBuiltInKeywordsGoToTheObviousDefaultCategory() {
        let state = BudgetState()
        XCTAssertEqual(ApplePayExpense.categoryID(for: "Tim Hortons", in: state), restaurants)
        XCTAssertEqual(ApplePayExpense.categoryID(for: "TIM HORTONS #1234 MONTREAL QC", in: state), restaurants)
        XCTAssertEqual(ApplePayExpense.categoryID(for: "Starbucks", in: state), restaurants)
        XCTAssertEqual(ApplePayExpense.categoryID(for: "IGA Extra", in: state), groceries)
        XCTAssertEqual(ApplePayExpense.categoryID(for: "Metro Épicerie", in: state), groceries)
        XCTAssertEqual(ApplePayExpense.categoryID(for: "STM", in: state), transport)
    }

    func testAnUnknownMerchantHasNoCategory() {
        let state = BudgetState()
        XCTAssertNil(ApplePayExpense.categoryID(for: "Zorglub Quantique Inc", in: state))
        XCTAssertNil(ApplePayExpense.categoryID(for: "", in: state))
        XCTAssertNil(ApplePayExpense.categoryID(for: "   ", in: state))
    }

    func testAKeywordNeverPointsToADeletedCategory() {
        var state = BudgetState()
        state.categories.removeAll()
        if let id = ApplePayExpense.categoryID(for: "Tim Hortons", in: state) {
            XCTAssertNotNil(state.category(id), "Sans catégorie dans le budget, rien ne doit être inventé")
        }
    }

    func testALearnedRuleBeatsTheKeyword() {
        var state = BudgetState()
        XCTAssertEqual(ApplePayExpense.categoryID(for: "Tim Hortons", in: state), restaurants)
        state.merchantRules[ApplePayExpense.normalizedMerchant("Tim Hortons")] = outings
        XCTAssertEqual(ApplePayExpense.categoryID(for: "Tim Hortons", in: state), outings)
        // Le même commerçant écrit autrement sur le relevé.
        XCTAssertEqual(ApplePayExpense.categoryID(for: "TIM HORTONS #1234 MONTREAL QC", in: state), outings)
        // Les autres commerçants gardent leur mot-clé.
        XCTAssertEqual(ApplePayExpense.categoryID(for: "IGA", in: state), groceries)
    }

    // MARK: - Ajout d'une dépense

    func testAnApplePayExpenseIsRecorded() throws {
        var state = BudgetState()
        let result = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: "Visa", date: now)
        let expense = try XCTUnwrap(added(result))
        XCTAssertEqual(expense.amount, 12.5)
        XCTAssertEqual(expense.source, .applePay)
        XCTAssertEqual(expense.merchant, "Tim Hortons")
        XCTAssertEqual(expense.date, now)
        XCTAssertEqual(expense.categoryID, restaurants)
        XCTAssertEqual(state.expenses.count, 1)
        XCTAssertEqual(state.expenses.first?.id, expense.id, "La dépense renvoyée est celle qui est enregistrée")
        XCTAssertEqual(BudgetMath.spent(state, in: BudgetMath.monthInterval(now), now: now), 12.5)
    }

    func testAGuessedCategoryNeedsReview() throws {
        var state = BudgetState()
        let expense = try XCTUnwrap(added(state.addApplePay(amount: 8, merchant: "Starbucks", card: nil, date: now)))
        XCTAssertNotNil(expense.categoryID)
        XCTAssertEqual(expense.needsReview, true, "Une catégorie devinée par mot-clé reste à vérifier")
    }

    func testAnUnknownMerchantIsRecordedWithoutCategoryAndNeedsReview() throws {
        var state = BudgetState()
        let expense = try XCTUnwrap(added(state.addApplePay(amount: 42, merchant: "Zorglub Quantique Inc", card: "Mastercard", date: now)))
        XCTAssertNil(expense.categoryID, "Aucune catégorie n'est inventée")
        XCTAssertEqual(expense.needsReview, true)
        XCTAssertEqual(expense.source, .applePay)
        XCTAssertEqual(state.expenses.count, 1)
    }

    func testAnEmptyMerchantBecomesApplePay() throws {
        var state = BudgetState()
        let expense = try XCTUnwrap(added(state.addApplePay(amount: 9.99, merchant: "", card: nil, date: now)))
        XCTAssertEqual(expense.merchant, "Apple Pay")
        let blank = try XCTUnwrap(added(state.addApplePay(amount: 5, merchant: "   ", card: nil, date: day(10, 25))))
        XCTAssertEqual(blank.merchant, "Apple Pay")
        XCTAssertEqual(state.expenses.count, 2)
    }

    func testTheCardIsOptional() throws {
        var state = BudgetState()
        XCTAssertNotNil(added(state.addApplePay(amount: 3, merchant: "IGA", card: nil, date: now)))
        XCTAssertNotNil(added(state.addApplePay(amount: 4, merchant: "IGA", card: "", date: now.addingTimeInterval(3_600))))
        XCTAssertEqual(state.expenses.count, 2)
    }

    func testUnusableAmountsAreIgnoredAndNothingIsAdded() {
        var state = BudgetState()
        for amount in [0, -12.5, Double.nan, Double.infinity, -0.01] {
            let result = state.addApplePay(amount: amount, merchant: "Tim Hortons", card: nil, date: now)
            XCTAssertTrue(isIgnored(result), "Le montant \(amount) doit être ignoré")
        }
        XCTAssertTrue(state.expenses.isEmpty)
    }

    func testARefundIsIgnored() {
        var state = BudgetState()
        XCTAssertTrue(isIgnored(state.addApplePay(amount: -25, merchant: "Amazon", card: "Visa", date: now)))
        XCTAssertTrue(state.expenses.isEmpty, "Un remboursement n'est pas une dépense")
    }

    // MARK: - Doublons

    func testTheSameTransactionTwiceInARowIsRecordedOnce() {
        // L'automatisation Raccourcis peut se déclencher deux fois pour un même paiement.
        var state = BudgetState()
        XCTAssertNotNil(added(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: "Visa", date: now)))
        let second = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: "Visa", date: now)
        XCTAssertTrue(isDuplicate(second))
        XCTAssertEqual(state.expenses.count, 1)
    }

    func testTheDuplicateWindowIsTwoMinutes() {
        XCTAssertEqual(ApplePayExpense.duplicateWindow, 120)
    }

    func testAnIdenticalPaymentInsideTheWindowIsADuplicate() {
        var state = BudgetState()
        _ = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now)
        XCTAssertTrue(isDuplicate(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(30))))
        XCTAssertTrue(isDuplicate(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(100))))
        XCTAssertEqual(state.expenses.count, 1)
    }

    func testAnIdenticalPaymentAfterTheWindowIsAdded() {
        var state = BudgetState()
        _ = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now)
        XCTAssertNotNil(added(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(121))))
        XCTAssertEqual(state.expenses.count, 2, "Deux vrais cafés à quelques minutes d'intervalle comptent tous les deux")
        XCTAssertNotNil(added(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(3_600))))
        XCTAssertEqual(state.expenses.count, 3)
    }

    func testADifferentAmountOrMerchantIsNotADuplicate() {
        var state = BudgetState()
        _ = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now)
        XCTAssertNotNil(added(state.addApplePay(amount: 13, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(10))))
        XCTAssertNotNil(added(state.addApplePay(amount: 12.5, merchant: "Starbucks", card: nil, date: now.addingTimeInterval(20))))
        XCTAssertEqual(state.expenses.count, 3)
    }

    func testADuplicateIsFoundEvenIfTheMerchantIsWrittenDifferently() {
        var state = BudgetState()
        _ = state.addApplePay(amount: 12.5, merchant: "TIM HORTONS #1234 MONTREAL QC", card: nil, date: now)
        XCTAssertTrue(isDuplicate(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(5))))
        XCTAssertEqual(state.expenses.count, 1)
    }

    func testAManualExpenseIsNotTakenForAnApplePayDuplicate() {
        var state = BudgetState()
        state.add(Expense(amount: 12.5, categoryID: restaurants, note: "Tim Hortons", date: now))
        XCTAssertNotNil(added(state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now.addingTimeInterval(10))),
                        "Seules les dépenses Apple Pay se dédoublonnent entre elles")
        XCTAssertEqual(state.expenses.count, 2)
    }

    // MARK: - Apprentissage

    func testLearningAMerchantCategoryIsUsedNextTime() throws {
        var state = BudgetState()
        var first = try XCTUnwrap(added(state.addApplePay(amount: 30, merchant: "Boutique Zorglub", card: nil, date: now)))
        XCTAssertNil(first.categoryID)
        XCTAssertEqual(first.needsReview, true)

        // La personne choisit la catégorie dans la liste des opérations.
        first.categoryID = outings
        first.needsReview = false
        state.save(first)
        state.learnMerchantCategory(for: first)
        XCTAssertEqual(state.merchantRules[ApplePayExpense.normalizedMerchant("Boutique Zorglub")], outings)

        // Plus tard, le même commerçant (écrit comme sur un relevé) prend cette catégorie, sans vérification.
        let second = try XCTUnwrap(added(state.addApplePay(amount: 18, merchant: "BOUTIQUE ZORGLUB #55 LAVAL QC", card: nil, date: day(10, 26))))
        XCTAssertEqual(second.categoryID, outings)
        XCTAssertEqual(second.needsReview, false)
        XCTAssertEqual(second.source, .applePay)
    }

    func testLearningOverridesAKeywordCategory() throws {
        var state = BudgetState()
        var coffee = try XCTUnwrap(added(state.addApplePay(amount: 5, merchant: "Tim Hortons", card: nil, date: now)))
        XCTAssertEqual(coffee.categoryID, restaurants)
        coffee.categoryID = home
        coffee.needsReview = false
        state.save(coffee)
        state.learnMerchantCategory(for: coffee)

        let next = try XCTUnwrap(added(state.addApplePay(amount: 6, merchant: "TIM HORTONS #9 QUEBEC QC", card: nil, date: day(10, 25))))
        XCTAssertEqual(next.categoryID, home, "La règle apprise passe avant le mot-clé")
        XCTAssertEqual(next.needsReview, false)
    }

    func testLearningAgainReplacesTheRule() throws {
        var state = BudgetState()
        var expense = try XCTUnwrap(added(state.addApplePay(amount: 5, merchant: "Boutique Zorglub", card: nil, date: now)))
        expense.categoryID = outings
        state.learnMerchantCategory(for: expense)
        expense.categoryID = home
        state.learnMerchantCategory(for: expense)
        XCTAssertEqual(state.merchantRules[ApplePayExpense.normalizedMerchant("Boutique Zorglub")], home)
        XCTAssertEqual(state.merchantRules.count, 1)
    }

    func testLearningFromAnExpenseWithoutMerchantOrCategoryDoesNothing() {
        var state = BudgetState()
        // Dépense manuelle : pas de commerçant.
        state.learnMerchantCategory(for: Expense(amount: 10, categoryID: groceries, note: "Marché", date: now))
        XCTAssertTrue(state.merchantRules.isEmpty)
        // Commerçant sans catégorie choisie.
        state.learnMerchantCategory(for: Expense(amount: 10, categoryID: nil, note: "", date: now, source: .applePay, merchant: "Boutique Zorglub"))
        XCTAssertTrue(state.merchantRules.isEmpty, "Aucune règle ne doit être inventée")
    }

    func testALearnedRuleAppliesToTheSameMerchantOnly() throws {
        var state = BudgetState()
        var expense = try XCTUnwrap(added(state.addApplePay(amount: 5, merchant: "Boutique Zorglub", card: nil, date: now)))
        expense.categoryID = outings
        state.learnMerchantCategory(for: expense)
        XCTAssertNil(ApplePayExpense.categoryID(for: "Boutique Autre", in: state))
        XCTAssertEqual(ApplePayExpense.categoryID(for: "boutique zorglub", in: state), outings)
    }

    // MARK: - Anciennes données et encodage

    func testAnOldExpenseWithoutTheNewFieldsDecodes() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","amount":12.5,"note":"Café","date":780000000}
        """
        let expense = try JSONDecoder().decode(Expense.self, from: Data(json.utf8))
        XCTAssertEqual(expense.amount, 12.5)
        XCTAssertEqual(expense.note, "Café")
        XCTAssertNil(expense.source)
        XCTAssertNil(expense.merchant)
        XCTAssertNotEqual(expense.needsReview, true)
    }

    func testAnOldBudgetWithoutTheNewFieldsDecodes() throws {
        let json = """
        {"monthlyBudget":1500,
         "expenses":[{"id":"11111111-1111-1111-1111-111111111111","amount":12.5,"note":"Café","date":780000000},
                     {"id":"22222222-2222-2222-2222-222222222222","amount":40,"categoryID":"00000000-0000-0000-0000-000000000001","note":"","date":780100000}]}
        """
        let state = try JSONDecoder().decode(BudgetState.self, from: Data(json.utf8))
        XCTAssertEqual(state.monthlyBudget, 1_500)
        XCTAssertEqual(state.expenses.count, 2)
        XCTAssertEqual(state.expenses.map(\.amount), [12.5, 40])
        XCTAssertTrue(state.expenses.allSatisfy { $0.source == nil || $0.source == .manual })
        XCTAssertTrue(state.expenses.allSatisfy { $0.needsReview != true })
        XCTAssertTrue(state.merchantRules.isEmpty)
        XCTAssertEqual(state.categories.count, BudgetState.defaultCategories.count)
    }

    func testEmptyBudgetJSONHasNoRules() throws {
        let state = try JSONDecoder().decode(BudgetState.self, from: Data("{}".utf8))
        XCTAssertTrue(state.merchantRules.isEmpty)
        XCTAssertTrue(state.expenses.isEmpty)
    }

    func testExpenseRoundTripKeepsTheNewFields() throws {
        let original = Expense(amount: 21.75, categoryID: restaurants, note: "", date: now,
                               source: .applePay, merchant: "Tim Hortons", needsReview: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Expense.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.source, .applePay)
        XCTAssertEqual(decoded.merchant, "Tim Hortons")
        XCTAssertEqual(decoded.needsReview, true)
    }

    func testBudgetRoundTripKeepsTheRulesAndApplePayExpenses() throws {
        var state = BudgetState()
        _ = state.addApplePay(amount: 12.5, merchant: "Boutique Zorglub", card: "Visa", date: now)
        state.merchantRules[ApplePayExpense.normalizedMerchant("Boutique Zorglub")] = outings
        state.merchantRules["tim hortons"] = home

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(BudgetState.self, from: data)
        XCTAssertEqual(decoded.merchantRules, state.merchantRules)
        XCTAssertEqual(decoded.expenses, state.expenses)
        XCTAssertEqual(decoded.expenses.first?.source, .applePay)
        XCTAssertEqual(decoded.expenses.first?.merchant, "Boutique Zorglub")
        XCTAssertEqual(decoded.expenses.first?.needsReview, true)
    }

    func testTheBudgetIsSavedAndReloadedThroughTheSharedStore() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SharedStore(directory: directory)
        let date = now
        let rule = outings
        store.update(BudgetState.self) { state in
            _ = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: date)
            state.merchantRules["tim hortons"] = rule
        }
        let reloaded = store.state(BudgetState.self)
        XCTAssertEqual(reloaded.expenses.count, 1)
        XCTAssertEqual(reloaded.expenses.first?.source, .applePay)
        XCTAssertEqual(reloaded.expenses.first?.merchant, "Tim Hortons")
        XCTAssertEqual(reloaded.merchantRules["tim hortons"], outings)
    }

    func testTwoTriggersOfTheAutomationThroughTheStoreRecordOneExpense() {
        // Deux exécutions de l'action pour le même paiement, l'une après l'autre dans le même fichier.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SharedStore(directory: directory)
        let date = now
        for offset in [0.0, 2.0] {
            store.update(BudgetState.self) { state in
                _ = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: "Visa", date: date.addingTimeInterval(offset))
            }
        }
        XCTAssertEqual(store.state(BudgetState.self).expenses.count, 1)
    }

    // MARK: - Non-régression

    func testAManualExpenseIsUnchanged() {
        var state = BudgetState()
        let manual = Expense(amount: 20, categoryID: groceries, note: "Marché", date: now)
        XCTAssertTrue(manual.source == nil || manual.source == .manual)
        XCTAssertNil(manual.merchant)
        XCTAssertNotEqual(manual.needsReview, true)
        state.add(manual)
        XCTAssertEqual(state.expenses, [manual])
        XCTAssertEqual(state.expenses.first?.categoryID, groceries, "Une dépense manuelle garde sa catégorie")
        XCTAssertTrue(state.merchantRules.isEmpty, "Ajouter une dépense à la main n'apprend rien")
    }

    func testAQuickExpenseStillCreatesAPlainExpense() {
        // Même construction que QuickExpenseIntent.
        var state = BudgetState()
        let quick = QuickExpense(name: "Café", amount: 4.5, categoryID: restaurants)
        state.add(Expense(amount: quick.amount, categoryID: quick.categoryID, note: quick.name, date: now))
        let expense = state.expenses[0]
        XCTAssertEqual(expense.amount, 4.5)
        XCTAssertEqual(expense.categoryID, restaurants)
        XCTAssertEqual(expense.note, "Café")
        XCTAssertTrue(expense.source == nil || expense.source == .manual)
        XCTAssertNotEqual(expense.needsReview, true)
    }

    func testApplePayAndManualExpensesCountTogether() {
        var state = BudgetState()
        state.add(Expense(amount: 20, categoryID: groceries, note: "Marché", date: now))
        _ = state.addApplePay(amount: 12.5, merchant: "Tim Hortons", card: nil, date: now)
        XCTAssertEqual(BudgetMath.spent(state, in: BudgetMath.monthInterval(now), now: now), 32.5)
    }
}
