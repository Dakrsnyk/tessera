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
        let start = DateMath.startOfDay(now).addingTimeInterval(30 * 86_400 + 9 * 3_600)
        return Trip(destination: "", start: start, end: start.addingTimeInterval(7 * 86_400))
    }

    static func dates(_ trip: Trip) -> String {
        "\(Fmt.format(trip.start, template: "dMMM")) – \(Fmt.format(trip.end, template: "dMMMyyyy"))"
    }
}

/// The Travel mini-app: the trip under way or coming (countdown, local time, weather), what comes
/// next (flight, stay, activity), the budget, the checklist and the currency; then the program.
struct TravelAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: TravelSheet?

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Travel.accentHex }

    var body: some View {
        let now = Date()
        let state = model.travel
        MiniAppScroll {
            if let trip = TravelMath.currentTrip(state, at: now) {
                TripHero(trip: trip, weather: model.tripWeather, now: now)
                next(trip: trip, state: state, now: now)
                HStack(spacing: 10) {
                    budgetTile(trip: trip, state: state)
                    checklistTile(trip: trip, state: state)
                }
                converter(trip: trip, state: state)
                tripRows(trip: trip, state: state)
            } else {
                start
            }
            others(state: state, now: now)
            MiniAppSettingsSection(app: .travel)
        }
        .navigationTitle(tr("Voyage"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await model.refreshTripWeather()
            await model.refreshFX()
        }
        .sheet(item: $sheet) { $0.editor }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "airplane.departure").font(.system(size: 28)).foregroundStyle(Color(hex: accentHex))
            Text(tr("Ton prochain voyage")).font(.title3.weight(.bold))
            Text(tr("Ajoute un voyage : compte à rebours, heure et météo sur place, vols, hébergements, programme, budget et liste des choses à ne pas oublier, au même endroit."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MiniActionButton(title: tr("Nouveau voyage"), symbol: "plus", colorHex: accentHex) { sheet = .trip(Travel.newTrip()) }
                .accessibilityIdentifier("travel-new-trip")
        }
        .card()
    }

    // MARK: Next

    @ViewBuilder
    private func next(trip: Trip, state: TravelState, now: Date) -> some View {
        let flight = TravelMath.flights(state, for: trip).first { $0.departure.addingTimeInterval(3_600) > now }
        let stay = TravelMath.stays(state, for: trip).first { $0.checkOut > now }
        let activity = TravelMath.activities(state, for: trip).first { $0.date.addingTimeInterval(1_800) > now }
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
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("travel-next")
            }
        }
    }

    // MARK: Budget and checklist

    private func budgetTile(trip: Trip, state: TravelState) -> some View {
        let spending = TravelMath.spending(state, for: trip, home: currency, rates: model.fx)
        return NavigationLink(value: HomeRoute.page(.travelBudget(trip.id))) {
            VStack(alignment: .leading, spacing: 6) {
                Label(tr("Budget"), systemImage: "creditcard.fill").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(TF.money(spending.total, currency)).font(.title3.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                if let budget = trip.budget, budget > 0 {
                    ProgressView(value: min(1, spending.total / budget)).tint(spending.total > budget ? Color(hex: "E5484D") : Color(hex: accentHex))
                    Text(tr("sur \(TF.money(budget, currency))")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(tr("dépensés")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("travel-budget")
    }

    private func checklistTile(trip: Trip, state: TravelState) -> some View {
        let items = state.checklist.filter { $0.tripID == trip.id }
        let done = items.filter(\.isDone).count
        return NavigationLink(value: HomeRoute.page(.travelChecklist(trip.id))) {
            VStack(alignment: .leading, spacing: 6) {
                Label(tr("À ne pas oublier"), systemImage: "checklist").font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                Text(items.isEmpty ? "–" : "\(done)/\(items.count)").font(.title3.weight(.bold)).monospacedDigit()
                if items.isEmpty {
                    Text(tr("liste à préparer")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ProgressView(value: Double(done), total: Double(items.count)).tint(Color(hex: "1E9E75"))
                    Text(done == items.count ? tr("tout est prêt") : tr("\(items.count - done) à préparer")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("travel-checklist")
    }

    // MARK: Currency

    @ViewBuilder
    private func converter(trip: Trip, state: TravelState) -> some View {
        if trip.currencyCode != currency, let rates = model.fx, rates.base == currency, let rate = rates.rates[trip.currencyCode] {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("Devise")).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("1 \(currency) = \(TF.decimal(rate, 3)) \(trip.currencyCode)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
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

    // MARK: Rows

    private func tripRows(trip: Trip, state: TravelState) -> some View {
        MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.travelProgram(trip.id))) {
                MiniRow(symbol: "list.bullet.below.rectangle", colorHex: accentHex, title: tr("Programme"),
                        detail: tr("Vols, hébergements et activités, jour par jour"),
                        value: "\(TravelMath.program(state, for: trip).count) j")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("travel-program")
            MiniDivider()
            Button { sheet = .trip(trip) } label: {
                MiniRow(symbol: "pencil", colorHex: "8A8A8E", title: tr("Modifier le voyage"), detail: "\(trip.destination) · \(Travel.dates(trip))", showsChevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Other trips

    @ViewBuilder
    private func others(state: TravelState, now: Date) -> some View {
        let current = TravelMath.currentTrip(state, at: now)
        let rest = state.trips.filter { $0.id != current?.id }.sorted { $0.start > $1.start }
        if !rest.isEmpty || current != nil {
          VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Mes voyages"))
            MiniRowsCard {
                ForEach(Array(rest.prefix(4).enumerated()), id: \.element.id) { index, trip in
                    if index > 0 { MiniDivider() }
                    Button { sheet = .trip(trip) } label: {
                        MiniRow(symbol: trip.end < now ? "clock.arrow.circlepath" : "airplane", colorHex: trip.end < now ? "8A8A8E" : accentHex,
                                title: trip.destination, detail: Travel.dates(trip), showsChevron: false)
                    }
                    .buttonStyle(.plain)
                }
                if !rest.isEmpty { MiniDivider() }
                if current != nil {
                    Button { sheet = .trip(Travel.newTrip()) } label: {
                        MiniRow(symbol: "plus", colorHex: accentHex, title: tr("Nouveau voyage"), showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("travel-add-trip")
                }
            }
          }
        }
    }
}

/// The trip at a glance: where, when, the local time and the weather there.
struct TripHero: View {
    let trip: Trip
    let weather: WeatherSnapshot?
    let now: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        let ongoing = TravelMath.isOngoing(trip, at: now)
        let offset = TravelMath.offsetHours(trip.timeZone, at: now)
        VStack(alignment: .leading, spacing: 8) {
            Text(ongoing ? tr("EN VOYAGE") : tr("PROCHAIN VOYAGE"))
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color(hex: Travel.accentHex))
            Text(trip.destination).font(.largeTitle.weight(.bold))
            Text(countdown(ongoing: ongoing)).font(.headline)
            Text(Travel.dates(trip)).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 18) {
                if offset != 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Heure locale")).font(.caption).foregroundStyle(.secondary)
                        TimelineView(.everyMinute) { context in
                            Text(Fmt.time(context.date, uses24Hour: true, timeZone: trip.timeZone)).font(.title3.weight(.semibold)).monospacedDigit()
                        }
                        Text(offsetText(offset)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let weather {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Météo")).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            WeatherGlyph(code: weather.code, isDay: weather.isDay)
                            Text(Fmt.temperature(weather.temperature, unit: model.settings.temperatureUnit)).font(.title3.weight(.semibold))
                        }
                        Text(WeatherCode.description(weather.code)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(hex: Travel.accentHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("travel-hero")
    }

    private func countdown(ongoing: Bool) -> String {
        if ongoing {
            let day = TravelMath.tripDay(trip, at: now)
            return tr("Jour \(day.day) sur \(day.total)")
        }
        let days = DateMath.daysBetween(now, trip.start)
        switch days {
        case ..<1: return tr("Départ aujourd'hui")
        case 1: return tr("Départ demain")
        default: return tr("Départ dans \(days) jours")
        }
    }

    private func offsetText(_ hours: Double) -> String {
        let value = hours.rounded() == hours ? TF.int(abs(hours)) : TF.decimal(abs(hours), 1)
        return hours > 0 ? tr("\(value) h de plus qu'ici") : tr("\(value) h de moins qu'ici")
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
