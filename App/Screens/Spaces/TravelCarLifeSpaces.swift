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
                Label("Nouveau voyage", systemImage: "plus")
            }
        } header: {
            Text("Voyages")
        }

        Section("Vols") {
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
                Label("Nouveau vol", systemImage: "plus")
            }
        }

        Section("Hébergement") {
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
                Label("Nouvel hébergement", systemImage: "plus")
            }
        }

        Section("Activités") {
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
                Label("Nouvelle activité", systemImage: "plus")
            }
        }

        Section {
            NumberRow(title: "Montant à convertir", value: Binding(get: { state.sampleAmount }, set: { amount in model.update(\.travel) { $0.sampleAmount = max(1, amount) } }), unit: model.settings.currencyCode)
        } header: {
            Text("Devise")
        } footer: {
            Text("Taux de référence de la Banque centrale européenne, mis à jour chaque jour ouvrable (Frankfurter).")
        }
    }
}

struct TripEditor: View {
    @Environment(AppModel.self) private var model
    @State var trip: Trip
    @State private var query = ""
    @State private var results: [DestinationResult] = []

    var body: some View {
        SheetForm(title: "Voyage", canSave: !trip.destination.trimmed.isEmpty && trip.end >= trip.start, onSave: save) {
            Section {
                TextField("Destination", text: $trip.destination)
                HStack {
                    TextField("Chercher la ville (météo et fuseau)", text: $query)
                        .onSubmit { Task { results = await DestinationSearch.search(query) } }
                    Button("Chercher") { Task { results = await DestinationSearch.search(query) } }
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
                    Label("Ville trouvée : météo et heure locale activées", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
            Section {
                DatePicker("Départ", selection: $trip.start).environment(\.locale, Fmt.locale)
                DatePicker("Retour", selection: $trip.end).environment(\.locale, Fmt.locale)
                Picker("Devise sur place", selection: $trip.currencyCode) {
                    ForEach(FXService.currencies, id: \.self) { Text($0).tag($0) }
                }
                Picker("Fuseau horaire", selection: $trip.timeZoneID) {
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
        SheetForm(title: "Vol", canSave: !flight.number.trimmed.isEmpty, onSave: save) {
            TextField("Numéro de vol (AC 870…)", text: $flight.number).textInputAutocapitalization(.characters)
            TextField("Départ (YUL)", text: $flight.from).textInputAutocapitalization(.characters)
            TextField("Arrivée (CDG)", text: $flight.to).textInputAutocapitalization(.characters)
            DatePicker("Décollage", selection: $flight.departure).environment(\.locale, Fmt.locale)
            DatePicker("Atterrissage", selection: Binding(get: { flight.arrival ?? flight.departure.addingTimeInterval(7 * 3600) }, set: { flight.arrival = $0 }))
                .environment(\.locale, Fmt.locale)
            TextField("Terminal", text: $flight.terminal)
            TextField("Porte", text: $flight.gate)
            TextField("Siège", text: $flight.seat)
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
        SheetForm(title: "Hébergement", canSave: !stay.name.trimmed.isEmpty && stay.checkOut > stay.checkIn, onSave: save) {
            TextField("Nom", text: $stay.name)
            TextField("Adresse", text: $stay.address)
            DatePicker("Arrivée", selection: $stay.checkIn).environment(\.locale, Fmt.locale)
            DatePicker("Départ", selection: $stay.checkOut).environment(\.locale, Fmt.locale)
            TextField("Numéro de réservation", text: $stay.confirmation)
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
        SheetForm(title: "Activité", canSave: !activity.title.trimmed.isEmpty, onSave: save) {
            TextField("Activité (visite, restaurant…)", text: $activity.title)
            DatePicker("Date et heure", selection: $activity.date).environment(\.locale, Fmt.locale)
            TextField("Lieu", text: $activity.place)
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
            TextField("Nom de la voiture", text: Binding(get: { state.name }, set: { name in model.update(\.car) { $0.name = name } }))
            if let odometer = CarMath.odometer(state) {
                ValueRow(title: "Compteur", value: "\(TF.int(odometer)) km", symbol: "gauge.with.dots.needle.33percent")
            }
            if let consumption = CarMath.consumption(state) {
                ValueRow(title: "Consommation", value: "\(TF.decimal(consumption, 1)) L/100 km", symbol: "fuelpump")
            }
            ValueRow(title: "Coût par mois", value: TF.money(cost.total, currency), symbol: "car.fill")
            Button { sheets?.open { FuelEditor() } } label: { Label("Noter un plein", systemImage: "fuelpump.fill") }
            Button { sheets?.open { OdometerEditor() } } label: { Label("Noter le kilométrage", systemImage: "speedometer") }
        } header: {
            Text("Ma voiture")
        }

        Section("Entretien") {
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
                        Label("Fait", systemImage: "checkmark")
                    }
                    .tint(.green)
                    Button(role: .destructive) {
                        model.update(\.car) { $0.services.removeAll { $0.id == status.item.id } }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
            Button {
                sheets?.open { ServiceEditor(service: ServiceItem(name: "", intervalKm: 8_000, intervalMonths: 6, lastKm: CarMath.odometer(state), lastDate: now)) }
            } label: {
                Label("Nouvel entretien", systemImage: "plus")
            }
        }

        Section("Échéances") {
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
                Label("Nouvelle échéance", systemImage: "plus")
            }
        }

        Section {
            NumberRow(title: "Assurance", value: carBinding(\.insuranceMonthly), unit: "/ mois")
            NumberRow(title: "Prêt ou location", value: carBinding(\.loanMonthly), unit: "/ mois")
            NumberRow(title: "Stationnement", value: carBinding(\.parkingMonthly), unit: "/ mois")
            NumberRow(title: "Autres frais", value: carBinding(\.otherMonthly), unit: "/ mois")
            NumberRow(title: "Entretien prévu", value: carBinding(\.maintenanceYearly), unit: "/ an")
        } header: {
            Text("Coûts fixes")
        } footer: {
            Text("Le coût mensuel ajoute la moyenne de tes pleins des trois derniers mois.")
        }

        Section("Derniers pleins") {
            ForEach(state.fills.sorted { $0.date > $1.date }.prefix(8)) { fill in
                ValueRow(title: Fmt.shortDay(fill.date), value: "\(TF.decimal(fill.liters, 1)) L · \(TF.money(fill.total, currency, decimals: 2))")
                    .swipeActions {
                        Button(role: .destructive) {
                            model.update(\.car) { $0.fills.removeAll { $0.id == fill.id } }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private static func remaining(_ status: CarMath.ServiceStatus) -> String {
        if let km = status.kmLeft { return "\(TF.int(km)) km" }
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
    @State private var fill = FuelFill(liters: 0, total: 0, odometer: 0)

    var body: some View {
        SheetForm(title: "Plein", canSave: fill.liters > 0 && fill.total > 0 && fill.odometer > 0, onSave: save) {
            NumberRow(title: "Litres", value: $fill.liters, unit: "L")
            NumberRow(title: "Total payé", value: $fill.total, unit: model.settings.currencyCode)
            NumberRow(title: "Compteur", value: $fill.odometer, unit: "km")
            Toggle("Plein complet", isOn: $fill.isFull)
            DatePicker("Date", selection: $fill.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
        }
        .onAppear {
            if fill.odometer == 0, let odometer = CarMath.odometer(model.car) { fill.odometer = odometer }
        }
    }

    private func save() {
        let saved = fill
        model.update(\.car) { $0.fills.append(saved) }
        Haptics.success()
    }
}

struct OdometerEditor: View {
    @Environment(AppModel.self) private var model
    @State private var km: Double = 0

    var body: some View {
        SheetForm(title: "Kilométrage", canSave: km > 0, onSave: save) {
            NumberRow(title: "Compteur", value: $km, unit: "km")
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
        SheetForm(title: "Entretien", canSave: !service.name.trimmed.isEmpty, onSave: save) {
            TextField("Nom (vidange, pneus…)", text: $service.name)
            NumberRow(title: "Tous les", value: Binding(get: { service.intervalKm ?? 0 }, set: { service.intervalKm = $0 > 0 ? $0 : nil }), unit: "km")
            IntRow(title: "ou tous les", value: Binding(get: { service.intervalMonths ?? 0 }, set: { service.intervalMonths = $0 > 0 ? $0 : nil }), unit: "mois")
            NumberRow(title: "Dernier au compteur", value: Binding(get: { service.lastKm ?? 0 }, set: { service.lastKm = $0 > 0 ? $0 : nil }), unit: "km")
            DatePicker("Dernière fois", selection: Binding(get: { service.lastDate ?? Date() }, set: { service.lastDate = $0 }), displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
            NumberRow(title: "Coût habituel", value: $service.cost, unit: model.settings.currencyCode)
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
        SheetForm(title: "Échéance", canSave: !deadline.title.trimmed.isEmpty, onSave: save) {
            TextField("Titre (assurance, immatriculation…)", text: $deadline.title)
            DatePicker("Date", selection: $deadline.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
            Picker("Icône", selection: $deadline.symbol) {
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
            Toggle("Afficher mon anniversaire", isOn: Binding(
                get: { life.birthday != nil },
                set: { on in model.update(\.life) { $0.birthday = on ? ($0.birthday ?? Holidays.make(1995, 1, 1)) : nil } }
            ))
            if let birthday = life.birthday {
                DatePicker("Date de naissance", selection: Binding(get: { birthday }, set: { date in model.update(\.life) { $0.birthday = date } }), in: ...now, displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
                ValueRow(title: "Âge", value: "\(TF.decimal(LifeMath.age(birthday: birthday, at: now), 2)) ans", symbol: "person.crop.circle")
                let next = LifeMath.nextBirthday(birthday: birthday, after: now)
                ValueRow(title: "Prochain anniversaire", value: "dans \(DateMath.daysBetween(now, next.date)) j", symbol: "gift")
            }
        } header: {
            Text("Anniversaire")
        } footer: {
            Text("Ta date de naissance reste sur ton iPhone.")
        }

        Section("Jours fériés") {
            Picker("Région", selection: Binding(get: { life.holidayRegion }, set: { region in model.update(\.life) { $0.holidayRegion = region } })) {
                ForEach(HolidayRegion.allCases) { Text($0.title).tag($0) }
            }
            ForEach(Holidays.upcoming(life.holidayRegion, from: now, count: 6), id: \.self) { holiday in
                ValueRow(title: holiday.name, value: Fmt.shortDay(holiday.date), symbol: "sun.max")
            }
        }

        Section("Lune") {
            ValueRow(title: MoonPhase.name(at: now), value: Fmt.percent(MoonPhase.illumination(at: now)), symbol: MoonPhase.symbol(at: now))
            ValueRow(title: "Pleine lune", value: Fmt.shortDay(MoonPhase.next(0.5, after: now)), symbol: "moonphase.full.moon")
        }
    }
}
