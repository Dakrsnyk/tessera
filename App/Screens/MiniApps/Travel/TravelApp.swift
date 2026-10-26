import SwiftUI

/// Everything the Travel mini-app edits in a sheet.
enum TravelSheet: Identifiable {
    case trip(Trip)
    case flight(Flight)
    case stay(Stay)
    case activity(TripActivity)
    case expense(TripExpense)

    var id: String {
        switch self {
        case let .trip(trip): "trip-\(trip.id)"
        case let .flight(flight): "flight-\(flight.id)"
        case let .stay(stay): "stay-\(stay.id)"
        case let .activity(activity): "activity-\(activity.id)"
        case let .expense(expense): "expense-\(expense.id)"
        }
    }

    @ViewBuilder
    var editor: some View {
        switch self {
        case let .trip(trip): TripEditor(trip: trip)
        case let .flight(flight): FlightEditor(flight: flight)
        case let .stay(stay): StayEditor(stay: stay)
        case let .activity(activity): ActivityEditor(activity: activity)
        case let .expense(expense): TripExpenseEditor(expense: expense)
        }
    }
}

enum Travel {
    static var accentHex: String { MiniApp.travel.colorHex }

    static func newTrip(now: Date = Date()) -> Trip {
        let start = DateMath.date(on: DateMath.calendar.date(byAdding: .day, value: 30, to: now) ?? now, minute: 9 * 60)
        return Trip(destination: "", start: start, end: start.addingTimeInterval(7 * 86_400))
    }

    static func dates(_ trip: Trip) -> String {
        "\(Fmt.format(trip.start, template: "dMMM")) – \(Fmt.format(trip.end, template: "dMMMyyyy"))"
    }
}

/// The Travel mini-app: the week selector, the trip under way or coming (countdown, local time) and
/// the program of the day picked; then what comes next (flight, stay, activity), the budget, the checklist,
/// the currency and the other trips.
struct TravelAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: TravelSheet?
    /// The day of the trip the program tells about.
    @State private var day = Date()
    /// The choices of the floating « Ajouter » (a trip under way).
    @State private var adding = false

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Travel.accentHex }

    var body: some View {
        let now = Date()
        let state = model.travel
        let current = TravelMath.currentTrip(state, at: now)
        // The one main action floats: « Nouveau voyage » with no trip, « Ajouter » (a flight, a stay, an activity, an expense) with one.
        MiniAppScaffold(colorHex: accentHex, action: current == nil ? newTripAction : addAction) {
            if let trip = current {
                let program = TravelMath.program(state, for: trip)
                WeekSelector(day: $day, colorHex: accentHex, allowsFuture: true, mark: { date in
                    WeekDayMark(isPlanned: program.contains { DateMath.isSameDay($0.day, date) })
                })
                TripHero(trip: trip, now: now)
            } else {
                start
            }
        } sheet: {
            MiniAppToFillSection(app: .travel)
            if let trip = current {
                let program = TravelMath.program(state, for: trip)
                let dayItems = program.first { DateMath.isSameDay($0.day, day) }?.items ?? []
                dayProgram(trip: trip, items: dayItems, days: program.count)
                next(trip: trip, state: state, now: now, shown: Set(dayItems.map(\.id)))
                // Two tiles side by side: the budget and the checklist.
                HStack(spacing: 10) {
                    budgetTile(trip: trip, state: state)
                    checklistTile(trip: trip, state: state)
                }
                converter(trip: trip, state: state)
            }
            others(state: state, now: now, current: current)
            MiniAppInfoSection(app: .travel)
        }
        .navigationTitle(tr("Voyage"))
        .onAppear {
            // A trip still to come: the selector opens on its first day, not on a week with nothing in it.
            if let trip = TravelMath.currentTrip(model.travel, at: Date()), trip.start > Date(), DateMath.isSameDay(day, Date()) {
                day = trip.start
            }
        }
        .task {
            await model.refreshFX()
        }
        .sheet(item: $sheet) { $0.editor }
        .confirmationDialog(tr("Ajouter"), isPresented: $adding, titleVisibility: .visible) {
            if let trip = TravelMath.currentTrip(model.travel, at: Date()) {
                Button(tr("Vol")) { sheet = .flight(Flight(number: "", from: "", to: "", departure: trip.start)) }
                Button(tr("Hébergement")) { sheet = .stay(Stay(name: "", checkIn: trip.start, checkOut: trip.end)) }
                Button(tr("Activité")) { sheet = .activity(TripActivity(title: "", date: max(trip.start, Date()))) }
                Button(tr("Dépense")) {
                    sheet = .expense(TripExpense(tripID: trip.id, amount: 0, currencyCode: TravelMath.isOngoing(trip, at: Date()) ? trip.currencyCode : currency))
                }
            }
            Button(tr("Nouveau voyage")) { sheet = .trip(Travel.newTrip()) }
            Button(tr("Annuler"), role: .cancel) {}
        }
    }

    /// The floating action of a trip under way: what to add to it.
    private var addAction: MiniFloatingAction {
        MiniFloatingAction(title: tr("Ajouter"), symbol: "plus", colorHex: accentHex, identifier: "travel-add") { adding = true }
    }

    /// The floating action of a screen with no trip yet.
    private var newTripAction: MiniFloatingAction {
        MiniFloatingAction(title: tr("Nouveau voyage"), symbol: "plus", colorHex: accentHex, identifier: "travel-new-trip") { sheet = .trip(Travel.newTrip()) }
    }

    /// The start card on the band, with no trip yet (its action is the floating « Nouveau voyage »).
    private var start: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "airplane.departure").font(.system(size: 28)).foregroundStyle(Color(hex: accentHex))
            Text(tr("Ton prochain voyage")).font(.title3.weight(.bold))
            Text(tr("Ajoute un voyage : compte à rebours, heure sur place, vols, hébergements, programme, budget et liste des choses à ne pas oublier, au même endroit."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Program of the day

    /// The program of the day picked: the card opens the whole program, the only « Programme » of the screen.
    private func dayProgram(trip: Trip, items: [TravelMath.ProgramItem], days: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Programme"), detail: Fmt.shortDay(day))
            NavigationLink(value: HomeRoute.page(.travelProgram(trip.id))) {
                MiniRowsCard {
                    if items.isEmpty {
                        MiniRow(symbol: "list.bullet.below.rectangle", colorHex: accentHex, title: tr("Rien de prévu ce jour-là."),
                                detail: tr("Vols, hébergements et activités, jour par jour"), value: "\(days) j")
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { MiniDivider() }
                            MiniRow(symbol: item.symbol, colorHex: itemHex(item.kind), title: item.title, detail: item.detail,
                                    value: Fmt.time(item.date, uses24Hour: true))
                        }
                    }
                }
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("travel-program")
        }
    }

    private func itemHex(_ kind: TravelMath.ProgramItem.Kind) -> String {
        switch kind {
        case .flight: accentHex
        case .checkIn, .checkOut: "8C6CFF"
        case .activity: "F08A24"
        }
    }

    // MARK: Next

    /// What comes next, without what the program of the day picked already tells (`shown`: its item ids).
    @ViewBuilder
    private func next(trip: Trip, state: TravelState, now: Date, shown: Set<String>) -> some View {
        let flight = TravelMath.flights(state, for: trip).first { $0.departure.addingTimeInterval(3_600) > now && !shown.contains("flight-\($0.id)") }
        let stay = TravelMath.stays(state, for: trip).first { candidate in
            candidate.checkOut > now && !shown.contains((candidate.checkIn > now ? "in-" : "out-") + candidate.id.uuidString)
        }
        let activity = TravelMath.activities(state, for: trip).first { $0.date.addingTimeInterval(1_800) > now && !shown.contains("activity-\($0.id)") }
        if flight != nil || stay != nil || activity != nil {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("À venir"))
                NavigationLink(value: HomeRoute.page(.travelProgram(trip.id))) {
                    VStack(spacing: 0) {
                        if let flight {
                            MiniRow(symbol: "airplane", colorHex: accentHex, title: tr("Vol \(flight.number)"),
                                    detail: [Fmt.format(flight.departure, template: "EEEdMMMHHmm"), TravelMath.flightDetail(flight)].compactMap { $0 }.joined(separator: " · "), showsChevron: false)
                        }
                        if let stay {
                            if flight != nil { MiniDivider() }
                            MiniRow(symbol: "bed.double.fill", colorHex: "8C6CFF", title: stay.name,
                                    detail: stay.checkIn > now ? tr("Arrivée \(Fmt.format(stay.checkIn, template: "EEEdMMMHHmm"))") : tr("Départ \(Fmt.format(stay.checkOut, template: "EEEdMMMHHmm"))"),
                                    value: stay.confirmation.isEmpty ? nil : stay.confirmation, showsChevron: false)
                        }
                        if let activity {
                            if flight != nil || stay != nil { MiniDivider() }
                            MiniRow(symbol: "mappin.and.ellipse", colorHex: "F08A24", title: activity.title,
                                    detail: [Fmt.format(activity.date, template: "EEEdMMMHHmm"), activity.place.isEmpty ? nil : activity.place].compactMap { $0 }.joined(separator: " · "), showsChevron: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .miniCard()
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: Budget and checklist

    private func budgetTile(trip: Trip, state: TravelState) -> some View {
        let spending = TravelMath.spending(state, for: trip, home: currency, rates: model.fx)
        let budget = trip.budget ?? 0
        return NavigationLink(value: HomeRoute.page(.travelBudget(trip.id))) {
            // The figure spent, the budget beside it in small; red over the budget.
            MiniStat(title: tr("Budget"), value: TF.money(spending.total, currency),
                     unit: budget > 0 ? "/ \(TF.money(budget, currency))" : tr("dépensés"),
                     colorHex: budget > 0 && spending.total > budget ? MiniStyle.alertHex : nil)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("travel-budget")
    }

    private func checklistTile(trip: Trip, state: TravelState) -> some View {
        let items = state.checklist.filter { $0.tripID == trip.id }
        let done = items.filter(\.isDone).count
        return NavigationLink(value: HomeRoute.page(.travelChecklist(trip.id))) {
            // « 3 / 9 »: done over the total; green once everything is ready.
            MiniStat(title: tr("À ne pas oublier"), value: items.isEmpty ? "–" : "\(done)",
                     unit: items.isEmpty ? nil : "/ \(items.count)",
                     detail: items.isEmpty ? tr("liste à préparer") : (done == items.count ? tr("tout est prêt") : tr("\(items.count - done) à préparer")),
                     colorHex: !items.isEmpty && done == items.count ? MiniStyle.goodHex : nil)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("travel-checklist")
    }

    // MARK: Currency

    @ViewBuilder
    private func converter(trip: Trip, state: TravelState) -> some View {
        if trip.currencyCode != currency, let rates = model.fx, rates.base == currency, let rate = rates.rates[trip.currencyCode] {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Devise"), detail: "1 \(currency) = \(TF.decimal(rate, 3)) \(trip.currencyCode)")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach([10.0, 50.0, 100.0], id: \.self) { amount in
                            VStack(spacing: 2) {
                                Text("\(TF.int(amount)) \(trip.currencyCode)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(TF.money(amount / rate, currency, decimals: 2)).font(.subheadline.weight(.bold)).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(hex: accentHex).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    Text(tr("Taux de référence de la BCE du \(rates.day) (Frankfurter).")).font(.caption2).foregroundStyle(.tertiary)
                }
                .card(padding: 14)
            }
        }
    }

    // MARK: Other trips

    /// The last block, the mockup's « Plus »: with a trip under way, its edit row, the other trips and
    /// « Nouveau voyage »; with none, the trips already made.
    @ViewBuilder
    private func others(state: TravelState, now: Date, current: Trip?) -> some View {
        let rest = state.trips.filter { $0.id != current?.id }.sorted { $0.start > $1.start }
        if !rest.isEmpty || current != nil {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Mes voyages"))
                MiniRowsCard {
                    if let current {
                        Button { sheet = .trip(current) } label: {
                            MiniRow(symbol: "pencil", colorHex: "8A8A8E", title: tr("Modifier le voyage"), detail: "\(current.destination) · \(Travel.dates(current))")
                        }
                        .buttonStyle(.pressable)
                        MiniDivider()
                    }
                    ForEach(Array(rest.prefix(4).enumerated()), id: \.element.id) { index, trip in
                        if index > 0 { MiniDivider() }
                        Button { sheet = .trip(trip) } label: {
                            MiniRow(symbol: trip.end < now ? "clock.arrow.circlepath" : "airplane", colorHex: trip.end < now ? "8A8A8E" : accentHex,
                                    title: trip.destination, detail: Travel.dates(trip))
                        }
                        .buttonStyle(.pressable)
                    }
                    if !rest.isEmpty && current != nil { MiniDivider() }
                    if current != nil {
                        Button { sheet = .trip(Travel.newTrip()) } label: {
                            MiniRow(symbol: "plus", colorHex: accentHex, title: tr("Nouveau voyage"), showsChevron: false)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("travel-add-trip")
                    }
                }
            }
        }
    }
}

/// The trip at a glance, on the band (no card): the place and « EN VOYAGE » in small caps, the day of the trip (or
/// the countdown) in big, then one line with the local time there.
struct TripHero: View {
    let trip: Trip
    let now: Date

    var body: some View {
        let ongoing = TravelMath.isOngoing(trip, at: now)
        // The local time moves on by itself: the line is redrawn every minute.
        TimelineView(.everyMinute) { context in
            MiniHero(label: "\(trip.destination) · \(ongoing ? tr("EN VOYAGE") : tr("PROCHAIN VOYAGE"))",
                     value: headline(ongoing: ongoing),
                     caption: caption(ongoing: ongoing, at: context.date),
                     valueSize: ongoing ? 54 : 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("travel-hero")
    }

    /// « Jour 2 / 6 » under way, the countdown before.
    private func headline(ongoing: Bool) -> String {
        if ongoing {
            let day = TravelMath.tripDay(trip, at: now)
            return "\(tr("Jour")) \(day.day) / \(day.total)"
        }
        let days = DateMath.daysBetween(now, trip.start)
        switch days {
        case ..<1: return tr("Départ aujourd'hui")
        case 1: return tr("Départ demain")
        default: return tr("Départ dans \(days) jours")
        }
    }

    /// The dates (before the trip), the local time (when it differs from here).
    private func caption(ongoing: Bool, at date: Date) -> String? {
        var parts: [String] = []
        if !ongoing { parts.append(Travel.dates(trip)) }
        if TravelMath.offsetHours(trip.timeZone, at: now) != 0 {
            parts.append("\(tr("Heure locale")) \(Fmt.time(date, uses24Hour: true, timeZone: trip.timeZone))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// A trip expense, in the home currency or the currency there.
struct TripExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var expense: TripExpense

    private var isNew: Bool { !model.travel.expenses.contains { $0.id == expense.id } }

    var body: some View {
        let tripCurrency = model.travel.trips.first { $0.id == expense.tripID }?.currencyCode
        let choices = Array(Set([model.settings.currencyCode, tripCurrency ?? model.settings.currencyCode, expense.currencyCode])).sorted()
        SheetForm(title: isNew ? tr("Dépense de voyage") : tr("Modifier la dépense"), canSave: expense.amount > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Montant"), value: $expense.amount, unit: expense.currencyCode)
                Picker(tr("Devise"), selection: $expense.currencyCode) {
                    ForEach(choices, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker(tr("Type"), selection: $expense.kind) {
                    ForEach(TripExpenseKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                TextField(tr("Note (facultatif)"), text: $expense.label)
                DatePicker(tr("Date"), selection: $expense.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
            }
            if !isNew {
                Section {
                    Button(tr("Supprimer la dépense"), role: .destructive) {
                        let id = expense.id
                        model.update(\.travel) { $0.expenses.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        var saved = expense
        saved.label = saved.label.trimmed
        model.update(\.travel) { state in
            if let index = state.expenses.firstIndex(where: { $0.id == saved.id }) { state.expenses[index] = saved } else { state.expenses.append(saved) }
        }
        Haptics.success()
    }
}
