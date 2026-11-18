import SwiftUI

/// The small figures of the hybrid Travel screens (direction 5, 2026-11-17): where a trip stands in time, what is
/// left to spend each day, how the trips are grouped on « Mes voyages ». Pure functions, no stored data.
enum TravelHybrid {
    /// Where a trip stands on a given day (whole days: a trip is under way from the day it starts to the day it ends).
    enum Phase: Equatable {
        case upcoming, ongoing, finished
    }

    static func phase(_ trip: Trip, at now: Date) -> Phase {
        let today = DateMath.startOfDay(now)
        if DateMath.startOfDay(trip.end) < today { return .finished }
        if DateMath.startOfDay(trip.start) <= today { return .ongoing }
        return .upcoming
    }

    /// What is left of the budget for each remaining day (today included), only for a trip under way with some budget
    /// left; nil otherwise, so no « par jour jusqu'au retour » is ever written for a trip not begun or finished.
    static func perDay(budget: Double?, spent: Double, trip: Trip, at now: Date) -> Double? {
        guard let budget, budget > spent, phase(trip, at: now) == .ongoing else { return nil }
        let days = TravelMath.tripDay(trip, at: now)
        return (budget - spent) / Double(max(1, days.total - days.day + 1))
    }

    /// By how much the spending goes over the budget; nil without a budget or within it.
    static func overrun(budget: Double?, spent: Double) -> Double? {
        guard let budget, budget > 0, spent > budget else { return nil }
        return spent - budget
    }

    /// The trips under way or to come (the soonest first) and the finished ones (the latest first).
    static func grouped(_ trips: [Trip], at now: Date) -> (ahead: [Trip], finished: [Trip]) {
        let ahead = trips.filter { phase($0, at: now) != .finished }.sorted { $0.start < $1.start }
        let finished = trips.filter { phase($0, at: now) == .finished }.sorted { $0.start > $1.start }
        return (ahead, finished)
    }

    /// The sheet that edits a line of a trip's program (its id is « flight-», « in-», « out- » or « activity- » + the UUID).
    static func sheet(for item: TravelMath.ProgramItem, in state: TravelState) -> TravelSheet? {
        let parts = item.id.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "flight": return state.flights.first { $0.id == id }.map { .flight($0) }
        case "in", "out": return state.stays.first { $0.id == id }.map { .stay($0) }
        default: return state.activities.first { $0.id == id }.map { .activity($0) }
        }
    }
}

/// The new expense of a trip: in the currency there while under way, in the home currency otherwise.
extension Travel {
    static func newExpense(for trip: Trip, home: String, now: Date = Date()) -> TripExpense {
        TripExpense(tripID: trip.id, amount: 0, currencyCode: TravelMath.isOngoing(trip, at: now) ? trip.currencyCode : home)
    }
}

// MARK: - Floating actions

/// The two floating actions of a trip: « Dépense » (filled, straight to the expense sheet) and « Ajouter » (glass, the
/// other choices). A double tap runs an action once.
struct TravelFloatingActions: View {
    let colorHex: String
    let expense: () -> Void
    let add: () -> Void
    @State private var tapGuard = TapGuard()
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strong = CristalPalette.of(style.id).strongHex(colorHex)
        let hex = scheme == .dark ? strong.dark : strong.light
        HStack(spacing: 10) {
            Button {
                tapGuard.run(expense)
            } label: {
                Label(tr("Dépense"), systemImage: "creditcard")
                    .font(.headline)
                    .foregroundStyle(Color.readableInk(on: hex))
                    .padding(.horizontal, 22)
                    .frame(minHeight: 50)
                    .background(Color(hex: hex), in: Capsule())
                    .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("travel-expense")
            Button {
                tapGuard.run(add)
            } label: {
                Label(tr("Ajouter"), systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .cristalGlass(in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("travel-add")
        }
    }
}

// MARK: - Mes voyages

/// All the trips: those to come and the finished ones, each opening its program, budget and checklist, and able to
/// be edited or deleted (with its expenses, checklist and the flights, stays and activities of its dates).
struct TravelTripsPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: TravelSheet?
    @State private var opened: UUID?
    @State private var pendingDelete: UUID?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.travel
        let now = Date()
        let groups = TravelHybrid.grouped(state.trips, at: now)
        MiniAppScroll {
            if state.trips.isEmpty {
                Text(tr("Aucun voyage pour l'instant."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            if !groups.ahead.isEmpty {
                section(tr("À venir"), trips: groups.ahead, state: state)
            }
            if !groups.finished.isEmpty {
                section(tr("Terminés"), trips: groups.finished, state: state)
            }
            MiniActionButton(title: tr("Nouveau voyage"), symbol: "plus", colorHex: Travel.accentHex, isProminent: false) {
                sheet = .trip(Travel.newTrip())
            }
            .accessibilityIdentifier("travel-add-trip")
        }
        .navigationTitle(tr("Mes voyages"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { $0.editor }
        .task { await model.refreshFX() }
        .confirmDelete($pendingDelete, title: tr("Supprimer le voyage ?"), button: tr("Supprimer le voyage"),
                       message: tr("Ses dépenses, sa liste et les vols, hébergements et activités de ses dates seront aussi supprimés.")) { id in
            model.update(\.travel) { $0.deleteTrip(id) }
            opened = nil
            pendingDelete = nil
        }
    }

    private func section(_ title: String, trips: [Trip], state: TravelState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: title, detail: "\(trips.count)")
            MiniRowsCard {
                ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                    if index > 0 { MiniDivider() }
                    tripRows(trip, state: state)
                }
            }
        }
    }

    @ViewBuilder
    private func tripRows(_ trip: Trip, state: TravelState) -> some View {
        let now = Date()
        let phase = TravelHybrid.phase(trip, at: now)
        let spending = TravelMath.spending(state, for: trip, home: currency, rates: model.fx)
        let isOpen = opened == trip.id
        Button {
            withAnimation(.snappy) { opened = isOpen ? nil : trip.id }
        } label: {
            MiniRow(symbol: phase == .finished ? "clock.arrow.circlepath" : "airplane", colorHex: phase == .finished ? "8A8A8E" : Travel.accentHex,
                    title: trip.destination, detail: Travel.dates(trip), value: spending.total > 0 ? TF.money(spending.total, currency) : nil, showsChevron: false)
        }
        .buttonStyle(.pressable)
        if isOpen {
            MiniDivider()
            let items = state.checklist.filter { $0.tripID == trip.id }
            let overrun = TravelHybrid.overrun(budget: trip.budget, spent: spending.total)
            NavigationLink(value: HomeRoute.page(.travelProgram(trip.id))) {
                MiniRow(symbol: "calendar", colorHex: Travel.accentHex, title: tr("Programme"),
                        detail: Fmt.plural(TravelMath.program(state, for: trip).count, tr("jour"), tr("jours")))
            }
            .buttonStyle(.pressable)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.travelBudget(trip.id))) {
                MiniRow(symbol: "creditcard", colorHex: Travel.accentHex, title: tr("Budget"),
                        detail: overrun.map { tr("dépassé de \(TF.money($0, currency))") } ?? ((trip.budget ?? 0) > 0 ? tr("sur \(TF.money(trip.budget ?? 0, currency))") : nil),
                        value: TF.money(spending.total, currency))
            }
            .buttonStyle(.pressable)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.travelChecklist(trip.id))) {
                MiniRow(symbol: "checkmark.circle", colorHex: Travel.accentHex, title: tr("À ne pas oublier"),
                        detail: items.isEmpty ? nil : tr("\(items.filter(\.isDone).count) sur \(items.count) prêts"))
            }
            .buttonStyle(.pressable)
            MiniDivider()
            HStack(spacing: 8) {
                MiniActionButton(title: tr("Modifier le voyage"), symbol: "pencil", colorHex: Travel.accentHex, isProminent: false) { sheet = .trip(trip) }
                MiniActionButton(title: tr("Supprimer le voyage"), symbol: "trash", colorHex: MiniStyle.alertHex, isProminent: false) { pendingDelete = trip.id }
            }
            .padding(.vertical, 8)
        }
    }
}
