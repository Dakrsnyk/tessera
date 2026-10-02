import CoreLocation
import SwiftUI

// MARK: - Voyage

struct DestinationResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String?
    let currency: String?
}

enum DestinationSearch {
    static func search(_ query: String) async -> [DestinationResult] {
        let text = query.trimmed
        guard text.count >= 2, let placemarks = try? await CLGeocoder().geocodeAddressString(text) else { return [] }
        return placemarks.compactMap { placemark -> DestinationResult? in
            guard let location = placemark.location else { return nil }
            let city = placemark.locality ?? placemark.name ?? text
            let country = placemark.country.map { ", \($0)" } ?? ""
            let currency = placemark.isoCountryCode.flatMap { Locale(identifier: "fr_\($0)").currency?.identifier }
            return DestinationResult(
                name: city + country,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneID: placemark.timeZone?.identifier,
                currency: currency
            )
        }
    }
}

struct TravelSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    var body: some View {
        let now = Date()
        let state = model.travel
        Section {
            ForEach(state.trips.sorted { $0.start < $1.start }) { trip in
                Button { sheets?.open { TripEditor(trip: trip) } } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.destination).foregroundStyle(Color.primary)
                        Text("\(Fmt.format(trip.start, template: "dMMM")) – \(Fmt.format(trip.end, template: "dMMMyyyy")) · \(trip.currencyCode)")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let sorted = state.trips.sorted { $0.start < $1.start }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.travel) { $0.trips.removeAll { ids.contains($0.id) } }
            }
            Button {
                sheets?.open { TripEditor(trip: Trip(destination: "", start: now.addingTimeInterval(30 * 86_400), end: now.addingTimeInterval(37 * 86_400))) }
            } label: {
                Label(tr("Nouveau voyage"), systemImage: "plus")
            }
        } header: {
            Text(tr("Voyages"))
        }

        Section(tr("Vols")) {
            ForEach(state.flights.sorted { $0.departure < $1.departure }) { flight in
                Button { sheets?.open { FlightEditor(flight: flight) } } label: {
                    ValueRow(title: "\(flight.number) · \(flight.from) → \(flight.to)", value: Fmt.format(flight.departure, template: "dMMMHHmm"), symbol: "airplane")
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let sorted = state.flights.sorted { $0.departure < $1.departure }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.travel) { $0.flights.removeAll { ids.contains($0.id) } }
            }
            Button {
                let start = TravelMath.currentTrip(state, at: now)?.start ?? now.addingTimeInterval(7 * 86_400)
                sheets?.open { FlightEditor(flight: Flight(number: "", from: "", to: "", departure: start)) }
            } label: {
                Label(tr("Nouveau vol"), systemImage: "plus")
            }
        }

        Section(tr("Hébergement")) {
            ForEach(state.stays.sorted { $0.checkIn < $1.checkIn }) { stay in
                Button { sheets?.open { StayEditor(stay: stay) } } label: {
                    ValueRow(title: stay.name, value: "\(Fmt.format(stay.checkIn, template: "dMMM")) – \(Fmt.format(stay.checkOut, template: "dMMM"))", symbol: "bed.double.fill")
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let sorted = state.stays.sorted { $0.checkIn < $1.checkIn }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.travel) { $0.stays.removeAll { ids.contains($0.id) } }
            }
            Button {
                let trip = TravelMath.currentTrip(state, at: now)
                sheets?.open { StayEditor(stay: Stay(name: "", checkIn: trip?.start ?? now, checkOut: trip?.end ?? now.addingTimeInterval(3 * 86_400))) }
            } label: {
                Label(tr("Nouvel hébergement"), systemImage: "plus")
            }
        }

        Section(tr("Activités")) {
            ForEach(state.activities.sorted { $0.date < $1.date }) { activity in
                Button { sheets?.open { ActivityEditor(activity: activity) } } label: {
                    ValueRow(title: activity.title, value: Fmt.format(activity.date, template: "dMMMHHmm"), symbol: "mappin.and.ellipse")
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let sorted = state.activities.sorted { $0.date < $1.date }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.travel) { $0.activities.removeAll { ids.contains($0.id) } }
            }
            Button {
                sheets?.open { ActivityEditor(activity: TripActivity(title: "", date: TravelMath.currentTrip(state, at: now)?.start ?? now)) }
            } label: {
                Label(tr("Nouvelle activité"), systemImage: "plus")
            }
        }

        Section {
            NumberRow(title: tr("Montant à convertir"), value: Binding(get: { state.sampleAmount }, set: { amount in model.update(\.travel) { $0.sampleAmount = max(1, amount) } }), unit: model.settings.currencyCode)
        } header: {
            Text(tr("Devise"))
        } footer: {
            Text(tr("Taux de référence de la Banque centrale européenne, mis à jour chaque jour ouvrable (Frankfurter)."))
        }
    }
}

struct TripEditor: View {
    @Environment(AppModel.self) private var model
    @State var trip: Trip
    @State private var query = ""
    @State private var results: [DestinationResult] = []

    var body: some View {
        SheetForm(title: tr("Voyage"), canSave: !trip.destination.trimmed.isEmpty && trip.end >= trip.start, onSave: save) {
            Section {
                TextField(tr("Destination"), text: $trip.destination)
                HStack {
                    TextField(tr("Chercher la ville (météo et fuseau)"), text: $query)
                        .onSubmit { Task { results = await DestinationSearch.search(query) } }
                    Button(tr("Chercher")) { Task { results = await DestinationSearch.search(query) } }
                        .disabled(query.trimmed.count < 2)
                }
                ForEach(results) { result in
                    Button(result.name) {
                        trip.destination = result.name.components(separatedBy: ",").first ?? result.name
                        trip.latitude = result.latitude
                        trip.longitude = result.longitude
                        if let zone = result.timeZoneID { trip.timeZoneID = zone }
                        if let currency = result.currency, FXService.currencies.contains(currency) { trip.currencyCode = currency }
                        results = []
                    }
                }
                if trip.latitude != nil {
                    Label(tr("Ville trouvée : météo et heure locale activées"), systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
            Section {
                DatePicker(tr("Départ"), selection: $trip.start).environment(\.locale, Fmt.locale)
                DatePicker(tr("Retour"), selection: $trip.end).environment(\.locale, Fmt.locale)
                Picker(tr("Devise sur place"), selection: $trip.currencyCode) {
                    ForEach(FXService.currencies, id: \.self) { Text($0).tag($0) }
                }
                Picker(tr("Fuseau horaire"), selection: $trip.timeZoneID) {
                    ForEach(timeZones, id: \.self) { Text(zoneLabel($0)).tag($0) }
                }
            }
        }
    }

    private var timeZones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        return all.contains(trip.timeZoneID) ? all : [trip.timeZoneID] + all
    }

    private func zoneLabel(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
    }

    private func save() {
        var saved = trip
        saved.destination = saved.destination.trimmed
        model.update(\.travel) { state in
            if let index = state.trips.firstIndex(where: { $0.id == saved.id }) { state.trips[index] = saved } else { state.trips.append(saved) }
        }
        Task { await model.refreshTripWeather() }
    }
}

struct FlightEditor: View {
    @Environment(AppModel.self) private var model
    @State var flight: Flight

    var body: some View {
        SheetForm(title: tr("Vol"), canSave: !flight.number.trimmed.isEmpty, onSave: save) {
            TextField(tr("Numéro de vol (AC 870…)"), text: $flight.number).textInputAutocapitalization(.characters)
            TextField(tr("Départ (YUL)"), text: $flight.from).textInputAutocapitalization(.characters)
            TextField(tr("Arrivée (CDG)"), text: $flight.to).textInputAutocapitalization(.characters)
            DatePicker(tr("Décollage"), selection: $flight.departure).environment(\.locale, Fmt.locale)
            DatePicker(tr("Atterrissage"), selection: Binding(get: { flight.arrival ?? flight.departure.addingTimeInterval(7 * 3600) }, set: { flight.arrival = $0 }))
                .environment(\.locale, Fmt.locale)
            TextField(tr("Terminal"), text: $flight.terminal)
            TextField(tr("Porte"), text: $flight.gate)
            TextField(tr("Siège"), text: $flight.seat)
        }
    }

    private func save() {
        var saved = flight
        saved.number = saved.number.trimmed.uppercased()
        model.update(\.travel) { state in
            if let index = state.flights.firstIndex(where: { $0.id == saved.id }) { state.flights[index] = saved } else { state.flights.append(saved) }
        }
    }
}

struct StayEditor: View {
    @Environment(AppModel.self) private var model
    @State var stay: Stay

    var body: some View {
        SheetForm(title: tr("Hébergement"), canSave: !stay.name.trimmed.isEmpty && stay.checkOut > stay.checkIn, onSave: save) {
            TextField(tr("Nom"), text: $stay.name)
            TextField(tr("Adresse"), text: $stay.address)
            DatePicker(tr("Arrivée"), selection: $stay.checkIn).environment(\.locale, Fmt.locale)
            DatePicker(tr("Départ"), selection: $stay.checkOut).environment(\.locale, Fmt.locale)
            TextField(tr("Numéro de réservation"), text: $stay.confirmation)
        }
    }

    private func save() {
        var saved = stay
        saved.name = saved.name.trimmed
        model.update(\.travel) { state in
            if let index = state.stays.firstIndex(where: { $0.id == saved.id }) { state.stays[index] = saved } else { state.stays.append(saved) }
        }
    }
}

struct ActivityEditor: View {
    @Environment(AppModel.self) private var model
    @State var activity: TripActivity

    var body: some View {
        SheetForm(title: tr("Activité"), canSave: !activity.title.trimmed.isEmpty, onSave: save) {
            TextField(tr("Activité (visite, restaurant…)"), text: $activity.title)
            DatePicker(tr("Date et heure"), selection: $activity.date).environment(\.locale, Fmt.locale)
            TextField(tr("Lieu"), text: $activity.place)
        }
    }

    private func save() {
        var saved = activity
        saved.title = saved.title.trimmed
        model.update(\.travel) { state in
            if let index = state.activities.firstIndex(where: { $0.id == saved.id }) { state.activities[index] = saved } else { state.activities.append(saved) }
        }
    }
}

// MARK: - Auto

struct CarSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let now = Date()
        let state = model.car
        let cost = CarMath.monthlyCost(state, at: now)
        Section {
            TextField(tr("Nom de la voiture"), text: Binding(get: { state.name }, set: { name in model.setCarName(name) }))
            if let odometer = CarMath.odometer(state) {
                ValueRow(title: tr("Compteur"), value: tr("\(TF.int(odometer)) km"), symbol: "gauge.with.dots.needle.33percent")
            }
            if let consumption = CarMath.consumption(state) {
                ValueRow(title: tr("Consommation"), value: tr("\(TF.decimal(consumption, 1)) L/100 km"), symbol: "fuelpump")
            }
            ValueRow(title: tr("Coût par mois"), value: TF.money(cost.total, currency), symbol: "car.fill")
            Button { sheets?.open { FuelEditor() } } label: { Label(tr("Noter un plein"), systemImage: "fuelpump.fill") }
            Button { sheets?.open { OdometerEditor() } } label: { Label(tr("Noter le kilométrage"), systemImage: "speedometer") }
        } header: {
            Text(tr("Ma voiture"))
        }

        Section(tr("Entretien")) {
            ForEach(CarMath.serviceStatus(state, at: now), id: \.item.id) { status in
                Button { sheets?.open { ServiceEditor(service: status.item) } } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(status.item.name).foregroundStyle(Color.primary)
                            Spacer()
                            Text(Self.remaining(status))
                                .foregroundStyle(status.used >= 1 ? Color.red : Color.secondary)
                                .monospacedDigit()
                        }
                        ProgressView(value: min(1, status.used)).tint(status.used >= 0.9 ? .orange : .accentColor)
                    }
                }
                .swipeActions {
                    Button {
                        let km = CarMath.odometer(state) ?? 0
                        model.update(\.car) { $0.markServiceDone(status.item.id, km: km) }
                    } label: {
                        Label(tr("Fait"), systemImage: "checkmark")
                    }
                    .tint(.green)
                    Button(role: .destructive) {
                        model.update(\.car) { $0.services.removeAll { $0.id == status.item.id } }
                    } label: {
                        Label(tr("Supprimer"), systemImage: "trash")
                    }
                }
            }
            Button {
                sheets?.open { ServiceEditor(service: ServiceItem(name: "", intervalKm: 8_000, intervalMonths: 6, lastKm: CarMath.odometer(state), lastDate: now)) }
            } label: {
                Label(tr("Nouvel entretien"), systemImage: "plus")
            }
        }

        Section(tr("Échéances")) {
            ForEach(state.deadlines.sorted { $0.date < $1.date }) { deadline in
                Button { sheets?.open { CarDeadlineEditor(deadline: deadline) } } label: {
                    ValueRow(title: deadline.title, value: Fmt.format(deadline.date, template: "dMMMyyyy"), symbol: deadline.symbol)
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let sorted = state.deadlines.sorted { $0.date < $1.date }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.car) { $0.deadlines.removeAll { ids.contains($0.id) } }
            }
            Button {
                sheets?.open { CarDeadlineEditor(deadline: CarDeadline(title: "", date: now.addingTimeInterval(60 * 86_400))) }
            } label: {
                Label(tr("Nouvelle échéance"), systemImage: "plus")
            }
        }

        Section {
            NumberRow(title: tr("Assurance"), value: carBinding(\.insuranceMonthly), unit: tr("/ mois"))
            NumberRow(title: tr("Prêt ou location"), value: carBinding(\.loanMonthly), unit: tr("/ mois"))
            NumberRow(title: tr("Stationnement"), value: carBinding(\.parkingMonthly), unit: tr("/ mois"))
            NumberRow(title: tr("Autres frais"), value: carBinding(\.otherMonthly), unit: tr("/ mois"))
            NumberRow(title: tr("Entretien prévu"), value: carBinding(\.maintenanceYearly), unit: tr("/ an"))
        } header: {
            Text(tr("Coûts fixes"))
        } footer: {
            Text(tr("Le coût mensuel ajoute la moyenne de tes pleins des trois derniers mois."))
        }

        Section(tr("Derniers pleins")) {
            ForEach(state.fills.sorted { $0.date > $1.date }.prefix(8)) { fill in
                ValueRow(title: Fmt.shortDay(fill.date), value: "\(TF.decimal(fill.liters, 1)) L · \(TF.money(fill.total, currency, decimals: 2))")
                    .swipeActions {
                        Button(role: .destructive) {
                            model.update(\.car) { $0.fills.removeAll { $0.id == fill.id } }
                        } label: {
                            Label(tr("Supprimer"), systemImage: "trash")
                        }
                    }
            }
        }
    }

    private static func remaining(_ status: CarMath.ServiceStatus) -> String {
        if let km = status.kmLeft { return tr("\(TF.int(km)) km") }
        if let days = status.daysLeft { return "\(days) j" }
        return "—"
    }

    private func carBinding(_ keyPath: WritableKeyPath<CarState, Double>) -> Binding<Double> {
        Binding(
            get: { model.car[keyPath: keyPath] },
            set: { value in model.update(\.car) { $0[keyPath: keyPath] = max(0, value) } }
        )
    }
}

struct FuelEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var fill: FuelFill
    private let isNew: Bool

    /// A new fill-up, or an existing one to change or delete.
    init(fill: FuelFill? = nil) {
        _fill = State(initialValue: fill ?? FuelFill(liters: 0, total: 0, odometer: 0))
        isNew = fill == nil
    }

    var body: some View {
        SheetForm(title: isNew ? tr("Plein") : tr("Modifier le plein"), canSave: fill.liters > 0 && fill.total > 0 && fill.odometer > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Litres"), value: $fill.liters, unit: "L")
                NumberRow(title: tr("Total payé"), value: $fill.total, unit: model.settings.currencyCode)
                NumberRow(title: tr("Compteur"), value: $fill.odometer, unit: tr("km"))
                Toggle(tr("Plein complet"), isOn: $fill.isFull)
                DatePicker(tr("Date"), selection: $fill.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
            } footer: {
                Text(tr("Un plein complet permet de calculer la consommation exacte et l'autonomie."))
            }
            if !isNew {
                Section {
                    Button(tr("Supprimer le plein"), role: .destructive) {
                        let id = fill.id
                        model.update(\.car) { $0.fills.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if fill.odometer == 0, let odometer = CarMath.odometer(model.car) { fill.odometer = odometer }
        }
    }

    private func save() {
        let saved = fill
        model.update(\.car) { $0.save(saved) }
        Haptics.success()
    }
}

struct OdometerEditor: View {
    @Environment(AppModel.self) private var model
    @State private var km: Double = 0

    var body: some View {
        SheetForm(title: tr("Kilométrage"), canSave: km > 0, onSave: save) {
            NumberRow(title: tr("Compteur"), value: $km, unit: tr("km"))
        }
        .onAppear { km = CarMath.odometer(model.car) ?? 0 }
    }

    private func save() {
        let value = km
        model.update(\.car) { $0.readings.append(OdometerReading(date: Date(), km: value)) }
    }
}

struct ServiceEditor: View {
    @Environment(AppModel.self) private var model
    @State var service: ServiceItem

    var body: some View {
        SheetForm(title: tr("Entretien"), canSave: !service.name.trimmed.isEmpty, onSave: save) {
            TextField(tr("Nom (vidange, pneus…)"), text: $service.name)
            NumberRow(title: tr("Tous les"), value: Binding(get: { service.intervalKm ?? 0 }, set: { service.intervalKm = $0 > 0 ? $0 : nil }), unit: tr("km"))
            IntRow(title: tr("ou tous les"), value: Binding(get: { service.intervalMonths ?? 0 }, set: { service.intervalMonths = $0 > 0 ? $0 : nil }), unit: tr("mois"))
            NumberRow(title: tr("Dernier au compteur"), value: Binding(get: { service.lastKm ?? 0 }, set: { service.lastKm = $0 > 0 ? $0 : nil }), unit: tr("km"))
            DatePicker(tr("Dernière fois"), selection: Binding(get: { service.lastDate ?? Date() }, set: { service.lastDate = $0 }), displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
            NumberRow(title: tr("Coût habituel"), value: $service.cost, unit: model.settings.currencyCode)
        }
    }

    private func save() {
        var saved = service
        saved.name = saved.name.trimmed
        model.update(\.car) { state in
            if let index = state.services.firstIndex(where: { $0.id == saved.id }) { state.services[index] = saved } else { state.services.append(saved) }
        }
    }
}

struct CarDeadlineEditor: View {
    @Environment(AppModel.self) private var model
    @State var deadline: CarDeadline

    var body: some View {
        SheetForm(title: tr("Échéance"), canSave: !deadline.title.trimmed.isEmpty, onSave: save) {
            TextField(tr("Titre (assurance, immatriculation…)"), text: $deadline.title)
            DatePicker(tr("Date"), selection: $deadline.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
            Picker(tr("Icône"), selection: $deadline.symbol) {
                ForEach(["calendar", "shield.fill", "doc.text.fill", "snowflake", "wrench.and.screwdriver", "creditcard"], id: \.self) { Image(systemName: $0).tag($0) }
            }
        }
    }

    private func save() {
        var saved = deadline
        saved.title = saved.title.trimmed
        model.update(\.car) { state in
            if let index = state.deadlines.firstIndex(where: { $0.id == saved.id }) { state.deadlines[index] = saved } else { state.deadlines.append(saved) }
        }
    }
}

// MARK: - Ma vie

struct LifeSpaceSections: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let now = Date()
        let life = model.life
        Section {
            Toggle(tr("Afficher mon anniversaire"), isOn: Binding(
                get: { life.birthday != nil },
                set: { on in model.update(\.life) { $0.birthday = on ? ($0.birthday ?? Holidays.make(1995, 1, 1)) : nil } }
            ))
            if let birthday = life.birthday {
                DatePicker(tr("Date de naissance"), selection: Binding(get: { birthday }, set: { date in model.update(\.life) { $0.birthday = date } }), in: ...now, displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
                ValueRow(title: tr("Âge"), value: tr("\(TF.decimal(LifeMath.age(birthday: birthday, at: now), 2)) ans"), symbol: "person.crop.circle")
                let next = LifeMath.nextBirthday(birthday: birthday, after: now)
                ValueRow(title: tr("Prochain anniversaire"), value: tr("dans \(DateMath.daysBetween(now, next.date)) j"), symbol: "gift")
            }
        } header: {
            Text(tr("Anniversaire"))
        } footer: {
            Text(tr("Ta date de naissance reste sur ton iPhone."))
        }

        Section(tr("Jours fériés")) {
            Picker(tr("Région"), selection: Binding(get: { life.holidayRegion }, set: { region in model.update(\.life) { $0.holidayRegion = region } })) {
                ForEach(HolidayRegion.allCases) { Text($0.title).tag($0) }
            }
            ForEach(Holidays.upcoming(life.holidayRegion, from: now, count: 6), id: \.self) { holiday in
                ValueRow(title: holiday.name, value: Fmt.shortDay(holiday.date), symbol: "sun.max")
            }
        }

        Section(tr("Lune")) {
            ValueRow(title: MoonPhase.name(at: now), value: Fmt.percent(MoonPhase.illumination(at: now)), symbol: MoonPhase.symbol(at: now))
            ValueRow(title: tr("Pleine lune"), value: Fmt.shortDay(MoonPhase.next(0.5, after: now)), symbol: "moonphase.full.moon")
        }
    }
}
