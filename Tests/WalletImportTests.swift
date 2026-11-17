import XCTest
@testable import Ardane

/// Premium : les achats lus dans Cartes (FinanceKit) deviennent des dépenses Apple Pay. Lire deux fois le même achat
/// n'ajoute rien ; un achat déjà envoyé par l'automatisation Raccourcis n'est pas compté deux fois ; un remboursement
/// ou un montant nul n'ajoute rien ; la catégorie apprise pour le commerçant est reprise.
final class WalletImportTests: XCTestCase {
    private func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testAPurchaseIsAddedOnceUnderItsWalletIdentifier() {
        var state = BudgetState()
        let id = UUID()
        guard case let .added(expense) = state.addWalletPurchase(id: id, amount: 14.499, merchant: "Café Myriade", date: date(12)) else {
            return XCTFail("The purchase must be added")
        }
        XCTAssertEqual(expense.id, id)
        XCTAssertEqual(expense.amount, 14.5, accuracy: 0.0001, "Rounded to the cent")
        XCTAssertEqual(expense.source, .applePay)
        XCTAssertEqual(expense.merchant, "Café Myriade")

        // Changed by the person, then read again: still one expense.
        state.expenses[0].amount = 15
        XCTAssertEqual(state.addWalletPurchase(id: id, amount: 14.5, merchant: "Café Myriade", date: date(12)), .duplicate)
        XCTAssertEqual(state.expenses.count, 1)
    }

    func testAPurchaseAlreadySentByTheShortcutIsNotCountedTwice() {
        var state = BudgetState()
        state.addApplePay(amount: 41, merchant: "IGA", card: "Apple Card", date: date(10, 18, 2))
        XCTAssertEqual(state.addWalletPurchase(id: UUID(), amount: 41, merchant: "IGA Extra", date: date(10, 18, 9)), .duplicate)
        // The same amount the next day is another purchase.
        if case .added = state.addWalletPurchase(id: UUID(), amount: 41, merchant: "IGA", date: date(11, 18)) {} else {
            XCTFail("A day later, it is another purchase")
        }
        XCTAssertEqual(state.expenses.count, 2)
    }

    func testTwoWalletPurchasesOfTheSameAmountAreBothKept() {
        var state = BudgetState()
        let first = UUID(), second = UUID()
        state.addWalletPurchase(id: first, amount: 4.5, merchant: "Café", date: date(12, 8, 0))
        // Two coffees five minutes apart: only a purchase from the Shortcuts automation counts as the same payment.
        guard case .added = state.addWalletPurchase(id: second, amount: 4.5, merchant: "Café", date: date(12, 8, 5), importedIDs: [first]) else {
            return XCTFail("The second coffee is another purchase")
        }
        XCTAssertEqual(state.expenses.count, 2)
    }

    func testADeletedPurchaseDoesNotComeBack() {
        var state = BudgetState()
        let id = UUID()
        state.addWalletPurchase(id: id, amount: 30, merchant: "Shop", date: date(7))
        state.expenses.removeAll { $0.id == id }
        XCTAssertEqual(state.addWalletPurchase(id: id, amount: 30, merchant: "Shop", date: date(7), importedIDs: [id]), .duplicate)
        XCTAssertTrue(state.expenses.isEmpty)
    }

    func testARefundOrANullAmountAddsNothing() {
        var state = BudgetState()
        if case .ignored = state.addWalletPurchase(id: UUID(), amount: -20, merchant: "Shop", date: date(5)) {} else { XCTFail("A refund") }
        if case .ignored = state.addWalletPurchase(id: UUID(), amount: 0, merchant: "Shop", date: date(5)) {} else { XCTFail("Zero") }
        if case .ignored = state.addWalletPurchase(id: UUID(), amount: .nan, merchant: "Shop", date: date(5)) {} else { XCTFail("Unreadable") }
        XCTAssertTrue(state.expenses.isEmpty)
    }

    func testTheCategoryLearnedForTheShopIsUsed() {
        var state = BudgetState()
        guard case let .added(first) = state.addWalletPurchase(id: UUID(), amount: 12, merchant: "Cinéma du Parc", date: date(3)) else {
            return XCTFail("Added")
        }
        var chosen = first
        chosen.categoryID = BudgetState.fixedID(4)
        state.save(chosen)
        state.learnMerchantCategory(for: chosen)
        guard case let .added(second) = state.addWalletPurchase(id: UUID(), amount: 14, merchant: "Cinéma du Parc", date: date(9)) else {
            return XCTFail("Added")
        }
        XCTAssertEqual(second.categoryID, BudgetState.fixedID(4))
        XCTAssertEqual(second.needsReview, false, "A learned category needs no check")
    }
}
