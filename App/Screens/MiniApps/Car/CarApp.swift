import Charts
import SwiftUI

/// Everything the Auto mini-app edits in a sheet.
enum CarSheet: Identifiable {
    case fuel(FuelFill?)
    case odometer
    case service(ServiceItem)
    case deadline(CarDeadline)
    case settings

    var id: String {
        switch self {
        case let .fuel(fill): "fuel-\(fill?.id.uuidString ?? "new")"
        case .odometer: "odometer"
        case let .service(service): "service-\(service.id)"
        case let .deadline(deadline): "deadline-\(deadline.id)"
        case .settings: "settings"
        }
    }

    @ViewBuilder
    var editor: some View {
        switch self {
        case let .fuel(fill): FuelEditor(fill: fill)
        case .odometer: OdometerEditor()
        case let .service(service): ServiceEditor(service: service)
        case let .deadline(deadline): CarDeadlineEditor(deadline: deadline)
        case .settings: CarSettingsEditor()
        }
    }
}

enum Car {
    static var accentHex: String { MiniApp.car.colorHex }
    static let fuelHex = "F08A24"
    static let alertHex = MiniStyle.alertHex

    static func remaining(_ status: CarMath.ServiceStatus) -> String {
        var parts: [String] = []
        if let km = status.kmLeft { parts.append(km >= 0 ? tr("dans \(Fmt.number(Int(km))) km") : tr("dépassé de \(Fmt.number(Int(-km))) km")) }
        if let days = status.daysLeft { parts.append(days >= 0 ? tr("d'ici \(days) j") : tr("en retard de \(-days) j")) }
        return parts.isEmpty ? tr("Pas encore de repère") : parts.joined(separator: tr(" ou "))
    }
}

/// One line of the log of a day: a fill-up, an odometer reading or a maintenance done.
private enum CarJournalEntry: Identifiable {
    case fill(FuelFill)
    case reading(OdometerReading, Int)
    case service(ServiceItem)

    var id: String {
        switch self {
        case let .fill(fill): "fill-\(fill.id)"
        case let .reading(_, index): "reading-\(index)"
        case let .service(service): "service-\(service.id)"
        }
    }
}

/// The Auto mini-app: the week selector, the odometer and the range left with the actions, the log of the day
/// picked; then the consumption and the cost, what maintenance comes, the deadlines and the pages.
struct CarAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: CarSheet?
    /// The day the log tells about (it stops at today).
    @State private var day = Date()

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Car.accentHex }

    var body: some View {
        let now = Date()
        let state = model.car
        let hasData = !(state.fills.isEmpty && state.readings.isEmpty && state.services.isEmpty && state.deadlines.isEmpty)
        MiniAppScroll {
            if hasData {
                WeekSelector(day: $day, colorHex: accentHex, allowsFuture: false, mark: { date in
                    WeekDayMark(isPlanned: hasRecord(state, on: date))
                })
                hero(state: state, now: now)
            } else {
                start
            }
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Plein"), symbol: "fuelpump.fill", colorHex: Car.fuelHex) { sheet = .fuel(nil) }
                    .accessibilityIdentifier("car-add-fuel")
                MiniActionButton(title: tr("Kilométrage"), symbol: "speedometer", colorHex: accentHex, isProminent: false) { sheet = .odometer }
                    .accessibilityIdentifier("car-add-odometer")
            }
            if hasData {
                journal(state: state)
            }
            stats(state: state, now: now)
            maintenance(state: state, now: now)
            deadlines(state: state, now: now)
            more(state: state, now: now, hasData: hasData)
            MiniAppInfoSection(app: .car)
        }
        .navigationTitle(state.name.isEmpty ? tr("Auto") : state.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "car.fill").font(.system(size: 28)).foregroundStyle(Color(hex: accentHex))
            Text(tr("Ta voiture, sans surprise")).font(.title3.weight(.bold))
            Text(tr("Note tes pleins et ton kilométrage : consommation, autonomie, coût réel par mois, entretiens et échéances se suivent tout seuls."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Odometer and range

    private func hero(state: CarState, now: Date) -> some View {
        let range = CarMath.range(state)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Compteur")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(CarMath.odometer(state).map { tr("\(Fmt.number(Int($0))) km") } ?? "–")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                if let month = CarMath.kmThisMonth(state, at: now) {
                    // It opens the mileage page: the « Kilométrage » row of the list below is only there when this figure is not.
                    NavigationLink(value: HomeRoute.page(.carMileage)) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(tr("Ce mois-ci")).font(.caption).foregroundStyle(.secondary)
                            Text(tr("\(Fmt.number(Int(month))) km")).font(.headline).foregroundStyle(.primary).monospacedDigit()
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-mileage")
                }
            }
            if let range {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(tr("Autonomie estimée"), systemImage: "fuelpump.fill").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(tr("≈ \(Fmt.number(Int(range.km))) km")).font(.headline).monospacedDigit()
                    }
                    ProgressView(value: range.share)
                        .tint(range.share < 0.2 ? Color(hex: Car.alertHex) : Color(hex: Car.fuelHex))
                    Text(tr("Environ \(TF.int(range.liters)) L dans le réservoir, d'après ta consommation depuis le plein du \(Fmt.format(range.since.date, template: "dMMMM"))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(hex: Car.fuelHex).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if state.tankLiters == nil && CarMath.consumption(state) != nil {
                Button { sheet = .settings } label: {
                    Label(tr("Indique la taille du réservoir pour voir l'autonomie"), systemImage: "fuelpump")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: Car.fuelHex))
                }
                .buttonStyle(.pressable)
            }
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("car-hero")
    }

    // MARK: Log of the day

    private func hasRecord(_ state: CarState, on date: Date) -> Bool {
        state.fills.contains { DateMath.isSameDay($0.date, date) }
            || state.readings.contains { DateMath.isSameDay($0.date, date) }
            || state.services.contains { service in
                guard let done = service.lastDate else { return false }
                return DateMath.isSameDay(done, date)
            }
    }

    private func dayFills(_ state: CarState) -> [FuelFill] {
        state.fills.filter { DateMath.isSameDay($0.date, day) }.sorted { $0.date < $1.date }
    }

    private func dayServices(_ state: CarState) -> [ServiceItem] {
        state.services.filter { service in
            guard let done = service.lastDate else { return false }
            return DateMath.isSameDay(done, day)
        }
    }

    private func entries(_ state: CarState) -> [CarJournalEntry] {
        var result: [CarJournalEntry] = dayFills(state).map { CarJournalEntry.fill($0) }
        let readings = state.readings.filter { DateMath.isSameDay($0.date, day) }.sorted { $0.date < $1.date }
        for (index, reading) in readings.enumerated() {
            result.append(.reading(reading, index))
        }
        result += dayServices(state).map { CarJournalEntry.service($0) }
        return result
    }

    /// What was noted on the day picked: fill-ups, odometer readings and maintenance done, with what it cost.
    private func journal(state: CarState) -> some View {
        let list = entries(state)
        let fillsSpent: Double = dayFills(state).reduce(0) { $0 + $1.total }
        let servicesSpent: Double = dayServices(state).reduce(0) { $0 + $1.cost }
        let spent = fillsSpent + servicesSpent
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: Fmt.longDay(day), detail: spent > 0 ? TF.money(spent, currency) : nil)
            if list.isEmpty {
                Text(tr("Rien noté ce jour-là."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            } else {
                MiniRowsCard {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { MiniDivider() }
                        journalRow(entry)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("car-journal")
    }

    @ViewBuilder
    private func journalRow(_ entry: CarJournalEntry) -> some View {
        switch entry {
        case let .fill(fill):
            Button { sheet = .fuel(fill) } label: {
                MiniRow(symbol: fill.isFull ? "fuelpump.fill" : "fuelpump", colorHex: Car.fuelHex, title: tr("Plein"),
                        detail: tr("\(TF.decimal(fill.liters, 1)) L · \(TF.money(fill.pricePerLiter, currency, decimals: 3))/L · \(Fmt.number(Int(fill.odometer))) km\(fill.isFull ? "" : tr(" · partiel"))"),
                        value: TF.money(fill.total, currency, decimals: 2), showsChevron: false)
            }
            .buttonStyle(.pressable)
        case let .reading(reading, _):
            MiniRow(symbol: "speedometer", colorHex: accentHex, title: tr("Kilométrage"),
                    value: tr("\(Fmt.number(Int(reading.km))) km"), showsChevron: false)
        case let .service(service):
            Button { sheet = .service(service) } label: {
                MiniRow(symbol: "wrench.and.screwdriver.fill", colorHex: "3366FF", title: service.name, detail: tr("Entretien"),
                        value: service.cost > 0 ? TF.money(service.cost, currency, decimals: 2) : nil, showsChevron: false)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: Figures

    @ViewBuilder
    private func stats(state: CarState, now: Date) -> some View {
        let consumption = CarMath.consumption(state)
        let cost = CarMath.monthlyCost(state, at: now)
        if consumption != nil || cost.total > 0 {
            HStack(spacing: 10) {
                if let consumption {
                    NavigationLink(value: HomeRoute.page(.carFuel)) {
                        MiniStat(title: tr("Consommation"), value: TF.decimal(consumption, 1), unit: "L/100",
                                 detail: CarMath.fuelCostPerKm(state).map { tr("\(TF.money($0 * 100, currency, decimals: 2)) / 100 km") })
                    }
                    .buttonStyle(.pressable)
                    // The « Carburant » row of the list below is only there when this figure is not.
                    .accessibilityIdentifier("car-fuel")
                }
                if cost.total > 0 {
                    NavigationLink(value: HomeRoute.page(.carCosts)) {
                        MiniStat(title: tr("Coût réel"), value: TF.money(cost.total, currency), detail: tr("par mois, tout compris"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-cost")
                }
            }
        }
    }

    // MARK: Maintenance

    @ViewBuilder
    private func maintenance(state: CarState, now: Date) -> some View {
        let statuses = CarMath.serviceStatus(state, at: now)
        if !statuses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Entretien"))
                NavigationLink(value: HomeRoute.page(.carMaintenance)) {
                    VStack(spacing: 12) {
                        ForEach(statuses.prefix(2), id: \.item.id) { status in
                            ServiceStatusRow(status: status)
                        }
                    }
                    .card(padding: 14)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("car-maintenance")
            }
        }
    }

    @ViewBuilder
    private func deadlines(state: CarState, now: Date) -> some View {
        let upcoming = CarMath.upcomingDeadlines(state, at: now)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Échéances"))
                NavigationLink(value: HomeRoute.page(.carDeadlines)) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.prefix(2).enumerated()), id: \.element.id) { index, deadline in
                            if index > 0 { MiniDivider() }
                            let days = DateMath.daysBetween(now, deadline.date)
                            MiniRow(symbol: deadline.symbol, colorHex: days <= 14 ? Car.alertHex : accentHex, title: deadline.title,
                                    detail: Fmt.format(deadline.date, template: "dMMMMyyyy"), value: days == 0 ? tr("aujourd'hui") : "J-\(days)", showsChevron: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .miniCard()
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("car-deadlines")
            }
        }
    }

    // MARK: More

    /// The list under the sections. A destination already shown above (a figure or a section) is not
    /// repeated; its row comes back only when that figure or section is hidden (nothing to show yet), so
    /// every page stays reachable. The identifiers move with the link. The mileage page is opened by
    /// « Ce mois-ci » of the hero; with nothing to show, there is no list.
    @ViewBuilder
    private func more(state: CarState, now: Date, hasData: Bool) -> some View {
        let wants = [
            CarMath.consumption(state) == nil,
            !(hasData && CarMath.kmThisMonth(state, at: now) != nil),
            CarMath.serviceStatus(state, at: now).isEmpty,
            CarMath.upcomingDeadlines(state, at: now).isEmpty,
            CarMath.monthlyCost(state, at: now).total <= 0,
        ]
        if wants.contains(true) {
            MiniRowsCard {
                if wants[0] {
                    NavigationLink(value: HomeRoute.page(.carFuel)) {
                        MiniRow(symbol: "fuelpump.fill", colorHex: Car.fuelHex, title: tr("Carburant"), detail: tr("Pleins, prix et consommation"),
                                value: state.fills.isEmpty ? nil : "\(state.fills.count)")
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-fuel")
                }
                if wants[1] {
                    if wants[..<1].contains(true) { MiniDivider() }
                    NavigationLink(value: HomeRoute.page(.carMileage)) {
                        MiniRow(symbol: "speedometer", colorHex: accentHex, title: tr("Kilométrage"), detail: tr("Kilomètres par mois"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-mileage")
                }
                if wants[2] {
                    if wants[..<2].contains(true) { MiniDivider() }
                    NavigationLink(value: HomeRoute.page(.carMaintenance)) {
                        MiniRow(symbol: "wrench.and.screwdriver.fill", colorHex: "3366FF", title: tr("Entretien"), detail: tr("Vidange, pneus, freins…"),
                                value: state.services.isEmpty ? nil : "\(state.services.count)")
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-maintenance")
                }
                if wants[3] {
                    if wants[..<3].contains(true) { MiniDivider() }
                    NavigationLink(value: HomeRoute.page(.carDeadlines)) {
                        MiniRow(symbol: "calendar.badge.exclamationmark", colorHex: Car.alertHex, title: tr("Échéances"), detail: tr("Assurance, immatriculation, pneus d'hiver…"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-deadlines")
                }
                if wants[4] {
                    if wants[..<4].contains(true) { MiniDivider() }
                    NavigationLink(value: HomeRoute.page(.carCosts)) {
                        MiniRow(symbol: "creditcard.fill", colorHex: "2F8F7A", title: tr("Coûts"), detail: tr("Ce que la voiture coûte vraiment chaque mois"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-cost")
                }
            }
        }
    }
}

/// A maintenance item: how much of its interval is used and when it is due.
struct ServiceStatusRow: View {
    let status: CarMath.ServiceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(status.item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Text(Car.remaining(status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.used >= 1 ? Color(hex: Car.alertHex) : Color.secondary)
            }
            ProgressView(value: min(1, status.used))
                .tint(status.used >= 1 ? Color(hex: Car.alertHex) : (status.used >= 0.85 ? Color.orange : Color(hex: "3366FF")))
        }
    }
}

/// The car's name and tank size.
struct CarSettingsEditor: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var tank: Double = 0

    var body: some View {
        SheetForm(title: tr("Ma voiture"), canSave: true, onSave: save) {
            Section {
                TextField(tr("Nom de la voiture"), text: $name)
                NumberRow(title: tr("Réservoir"), value: $tank, unit: "L")
                    .accessibilityIdentifier("car-tank")
            } footer: {
                Text(tr("La taille du réservoir (dans le manuel ou sur le site du constructeur) sert à estimer l'autonomie après un plein complet."))
            }
        }
        .onAppear {
            name = model.car.name
            tank = model.car.tankLiters ?? 0
        }
    }

    private func save() {
        let liters = tank
        model.setCarName(name.trimmed.isEmpty ? tr("Ma voiture") : name.trimmed)
        model.update(\.car) { $0.tankLiters = liters > 0 ? liters : nil }
    }
}
