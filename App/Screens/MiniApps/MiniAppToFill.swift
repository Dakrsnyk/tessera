import SwiftUI
import UIKit

/// What each mini-app asks the person to give, right on its page. These are the key data of « Mes informations »
/// that the page itself needs and that nothing else on it asks for yet. The same cards as the old « Tes données »
/// page used (`DataItemRow`), now met where the data is used; once given, they stay editable in « Mes paramètres ».
extension MiniApp {
    var toFillItems: [DataItem] {
        switch self {
        case .nutrition: [.kcalTarget, .macroTargets]
        case .fitness: [.routines, .weeklyWorkouts, .weight, .stepGoal]
        case .planning: [.habits, .timetable, .exams]
        case .finances: [.monthlyBudget]
        case .business: [.businessGoal]
        case .travel: [.trip]
        case .car: [.carName]
        case .weather: [.city]
        case .photos: []
        }
    }
}

extension AppModel {
    /// The cards of this mini-app still to fill: the same « filled » rule as « Mes informations »
    /// (`isFilled`, a default never counts), a log with nothing yet is not « to fill ».
    func toFillItems(in app: MiniApp) -> [DataItem] {
        missingItems(app.toFillItems)
    }

    /// How many of the mini-app's cards are given, over how many it has.
    func toFillProgress(in app: MiniApp) -> (filled: Int, total: Int) {
        let all = app.toFillItems.filter(\.countsAsMissing)
        return (all.filter { isFilled($0) }.count, all.count)
    }
}

/// « À remplir » at the top of a mini-app's sheet: the information it still needs, each as a card with its own way
/// to give it (create a workout, pick the sessions per week, type the weight…). A card leaves the block, softly, a
/// moment after it is given (not while the person is still typing, nor while a form is open); when nothing is left
/// the block draws nothing at all. Never shows an example value.
struct MiniAppToFillSection: View {
    let app: MiniApp
    @Environment(AppModel.self) private var model
    /// The forms the cards open (a workout, the nutrition needs…), presented from here so that they live as long as the block.
    @State private var sheets = SpaceSheets()
    /// What this block has shown, and what it has already let go. A plain box: it is read and written while the
    /// body is drawn, and only `revision` asks for a new drawing.
    @State private var memory = Memory()
    @State private var revision = 0
    /// Whether the keyboard is up: a card being typed in never leaves (the field would vanish under the fingers).
    @State private var keyboardIsUp = false

    private final class Memory {
        var seen = Set<DataItem>()
        var gone = Set<DataItem>()
    }

    /// The missing cards, plus those given a moment ago that have not left yet. A card already given when the
    /// screen opens is never shown.
    private func shownItems() -> [DataItem] {
        _ = revision
        let missing = model.toFillItems(in: app)
        memory.seen.formUnion(missing)
        memory.gone.subtract(missing)
        return app.toFillItems.filter { item in
            missing.contains(item) || (memory.seen.contains(item) && !memory.gone.contains(item))
        }
    }

    /// Changes at every answer (the summary of each card), so the delay before a card leaves starts over while the person types.
    private var signature: [String] {
        app.toFillItems.map { model.summary($0) ?? "" }
    }

    var body: some View {
        let shown = shownItems()
        Group {
            if !shown.isEmpty {
                let progress = model.toFillProgress(in: app)
                VStack(alignment: .leading, spacing: 12) {
                    MiniSectionTitle(title: tr("À remplir"), detail: "\(progress.filled) / \(progress.total)")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(tr("À remplir")))
                        .accessibilityValue(Text(tr("\(progress.filled) sur \(progress.total) renseignées")))
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 12) {
                        ForEach(shown) { item in
                            DataItemRow(item: item)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("mini-to-fill-\(item.rawValue)")
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .animation(.smooth(duration: 0.35), value: shown)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("mini-to-fill")
                .environment(sheets)
                .sheet(item: $sheets.current) { sheet in
                    sheet.content
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardIsUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in keyboardIsUp = false }
        .task(id: signature) { await settle() }
    }

    /// Lets the cards given leave the block after a short pause, once no form of the block is open and the
    /// keyboard is down (the pause starts over after the keyboard goes, so a card never goes while it is typed in).
    @MainActor private func settle() async {
        func hasStayingCard() -> Bool {
            app.toFillItems.contains { model.isFilled($0) && memory.seen.contains($0) && !memory.gone.contains($0) }
        }
        func isBusy() -> Bool { sheets.current != nil || keyboardIsUp }
        guard hasStayingCard() else { return }
        try? await Task.sleep(for: .seconds(1.4))
        while isBusy() && !Task.isCancelled {
            while isBusy() && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.4))
            }
            // Free: a last pause (a field about to be tapped again, a form about to open) before the card goes.
            if !Task.isCancelled { try? await Task.sleep(for: .seconds(1.4)) }
        }
        guard !Task.isCancelled else { return }
        memory.gone.formUnion(app.toFillItems.filter { model.isFilled($0) })
        revision += 1
    }
}
