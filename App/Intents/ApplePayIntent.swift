import AppIntents
import Foundation
import WidgetKit

/// « Ajouter une dépense Apple Pay »: the action the « Transaction » personal automation of Shortcuts calls
/// at each Apple Pay payment, with the amount, the shop and the card as text. It is offered in the
/// Shortcuts app like any discoverable AppIntent (the app has no `AppShortcutsProvider`, and none is added
/// here so that nothing else is hidden). It writes straight to the budget in the shared container, without
/// opening the app, and nothing leaves the iPhone.
struct AddApplePayExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter une dépense Apple Pay"
    static var description = IntentDescription(
        "Note dans le budget d'Ardane un paiement Apple Pay. À brancher sur l'automatisation « Transaction » de Raccourcis, avec les variables Montant, Commerçant et Carte.",
        categoryName: "Finances"
    )
    static var isDiscoverable: Bool { true }
    /// Runs in the background, without opening the app and without waiting for the iPhone to be unlocked.
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    /// Text, as Shortcuts gives it (« 12,50 $ »): read by `ApplePayExpense.parseAmount`.
    @Parameter(title: "Montant", description: "Le montant de la transaction, tel que Raccourcis le donne (12,50 $).")
    var amount: String

    /// Optional on purpose: an automation can't answer a question, so an empty shop never stops the action.
    @Parameter(title: "Commerçant")
    var merchant: String?

    @Parameter(title: "Carte")
    var card: String?

    init() {}

    init(amount: String, merchant: String?, card: String?) {
        self.amount = amount
        self.merchant = merchant
        self.card = card
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = ApplePayRecorder.record(amountText: amount, merchant: merchant ?? "", card: card)
        if case .added = outcome.result {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result(dialog: "\(outcome.message)")
    }
}

/// What the action did, with the sentence it answers.
struct ApplePayOutcome {
    var result: ApplePayResult
    /// The amount as read, with its sign; nil when the text had no number.
    var amount: Double?
    var merchant: String
    var currencyCode: String

    var message: String {
        let money = Fmt.money(abs(amount ?? 0), currency: currencyCode)
        switch result {
        case .added:
            return tr("\(money) · \(merchant) ajoutés")
        case .duplicate:
            return tr("Déjà noté : \(money) · \(merchant)")
        case let .ignored(reason):
            switch reason {
            case ApplePayExpense.Reason.refund: return tr("Remboursement ignoré : rien n'a été ajouté")
            case ApplePayExpense.Reason.zero: return tr("Montant nul : rien n'a été ajouté")
            case ApplePayExpense.Reason.storeUnreadable: return tr("Budget illisible pour le moment : rien n'a été ajouté")
            default: return tr("Montant illisible : rien n'a été ajouté")
            }
        }
    }
}

/// The work of the action, apart from App Intents so that tests can run it on a store of their own.
enum ApplePayRecorder {
    /// Reads the amount, adds the payment to the budget (in one atomic read-modify-write of the file, so that
    /// two runs for the same payment never both add it) and says what happened. A text without a number, a
    /// refund, a null amount and a duplicate write nothing. The amount is taken as is, in the currency of the
    /// settings; an amount that says another currency is kept but marked « à vérifier » with that currency in
    /// its note, never converted.
    @discardableResult
    static func record(amountText: String, merchant: String, card: String?, store: SharedStore = .shared, at date: Date = Date()) -> ApplePayOutcome {
        let currency = store.settings.currencyCode
        let shown = ApplePayExpense.displayName(merchant)
        let signed = ApplePayExpense.parseSignedAmount(amountText)
        var outcome = ApplePayOutcome(result: .ignored(ApplePayExpense.Reason.unreadable), amount: signed, merchant: shown, currencyCode: currency)
        guard let signed else { return outcome }

        let foreign = ApplePayExpense.currencyCode(in: amountText).flatMap { $0 == currency ? nil : $0 }
        var result = ApplePayResult.ignored(ApplePayExpense.Reason.unreadable)
        let saved = store.update(BudgetState.self) { state in
            result = state.addApplePay(amount: signed, merchant: merchant, card: card, date: date)
            if case let .added(expense) = result, let foreign,
               let index = state.expenses.firstIndex(where: { $0.id == expense.id }) {
                state.expenses[index].needsReview = true
                state.expenses[index].note += " (\(foreign))"
                result = .added(state.expenses[index])
            }
        }
        outcome.result = saved ? result : .ignored(ApplePayExpense.Reason.storeUnreadable)
        return outcome
    }
}
