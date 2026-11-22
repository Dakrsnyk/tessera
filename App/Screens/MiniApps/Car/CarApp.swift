import Charts
import SwiftUI

/// Everything the Auto mini-app edits in a sheet.
enum CarSheet: Identifiable {
    case fuel(FuelFill?)
    case odometer
    case service(ServiceItem)
    case deadline(CarDeadline)
    case settings
    case reading(OdometerReading)

    var id: String {
        switch self {
        case let .fuel(fill): "fuel-\(fill?.id.uuidString ?? "new")"
        case .odometer: "odometer"
        case let .service(service): "service-\(service.id)"
        case let .deadline(deadline): "deadline-\(deadline.id)"
        case .settings: "settings"
        case let .reading(reading): "reading-\(reading.date.timeIntervalSince1970)-\(reading.km)"
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
        case let .reading(reading): CarReadingEditor(reading: reading)
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

/// The Auto mini-app: on the band the week selector, the odometer and the range left; in the sheet the two
/// actions, the log of the day picked, the consumption and the cost, what maintenance comes, the deadlines and the pages.
struct CarAppView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var sheet: CarSheet?
    /// The day the log tells about (it stops at today).
    @State private var day = Date()

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Car.accentHex }

    var body: some View {
        let now = Date()
        let state = model.car
        let hasData = !(state.fills.isEmpty && state.readings.isEmpty && state.services.isEmpty && state.deadlines.isEmpty)
        MiniAppScaffold(colorHex: accentHex) {
            // The band: the figure the Mon quotidien card shows (the range, else the odometer), then what comes.
            if hasData {
                hero(state: state, now: now)
            } else {
                start
            }
        } sheet: {
            MiniAppToFillSection(app: .car)
            // Two actions: a row at the head of the sheet.
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Plein"), symbol: "plus", colorHex: accentHex) { sheet = .fuel(nil) }
                    .accessibilityIdentifier("car-add-fuel")
                    .tourAnchor(.car, 0)
                MiniActionButton(title: tr("Kilométrage"), symbol: "speedometer", colorHex: accentHex, isProminent: false) { sheet = .odometer }
                    .accessibilityIdentifier("car-add-odometer")
                    .tourAnchor(.car, 1)
            }
            // What presses first: the deadlines, then the maintenance, then the figures; the day and its log come last.
            deadlines(state: state, now: now)
            maintenance(state: state, now: now)
            stats(state: state, now: now)
            if hasData {
                WeekSelector(day: $day, colorHex: accentHex, allowsFuture: false, mark: { date in
                    WeekDayMark(isPlanned: hasRecord(state, on: date))
                })
                journal(state: state)
            }
            more(state: state, now: now, hasData: hasData)
            MiniAppInfoSection(app: .car)
        }
        .navigationTitle(state.name.isEmpty ? tr("Auto") : state.name)
        .miniAppTour(.car)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .settings } label: { Image(systemName: "pencil") }
                    .accessibilityLabel(tr("Ma voiture"))
                    .accessibilityIdentifier("car-edit")
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "car.fill").font(.system(size: 28)).foregroundStyle(CristalPalette.of(style.id).category(accentHex))
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
        let odometer = CarMath.odometer(state).map { tr("\(Fmt.number(Int($0))) km") } ?? "–"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if let range {
                    // The range is the figure; the odometer is the line under it.
                    MiniHero(label: tr("Autonomie estimée"), value: tr("≈ \(Fmt.number(Int(range.km))) km"), caption: "\(tr("Compteur")) \(odometer)")
                } else {
                    MiniHero(label: tr("Compteur"), value: odometer, caption: nil)
                }
                if let month = CarMath.kmThisMonth(state, at: now) {
                    // It opens the mileage page: the « Kilométrage » row of the list below is only there when this figure is not.
                    NavigationLink(value: HomeRoute.page(.carMileage)) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(tr("Ce mois-ci")).font(.caption).opacity(0.75)
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
                // Where the tank stands and what it is worked out from.
                Text(tr("Environ \(TF.int(range.liters)) L dans le réservoir, d'après ta consommation depuis le plein du \(Fmt.format(range.since.date, template: "dMMMM"))"))
                    .font(.caption)
                    .opacity(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            } else if state.tankLiters == nil && CarMath.consumption(state) != nil {
                Button { sheet = .settings } label: {
                    Label(tr("Indique la taille du réservoir pour voir l'autonomie"), systemImage: "fuelpump")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CristalPalette.of(style.id).strong(Car.fuelHex))
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        value: TF.money(fill.total, currency, decimals: 2))
            }
            .buttonStyle(.pressable)
        case let .reading(reading, _):
            MiniRow(symbol: "speedometer", colorHex: accentHex, title: tr("Relevé"),
                    detail: tr("\(Fmt.number(Int(reading.km))) km"), showsChevron: false)
        case let .service(service):
            Button { sheet = .service(service) } label: {
                MiniRow(symbol: "wrench.and.screwdriver.fill", colorHex: "3366FF", title: service.name, detail: tr("Entretien"),
                        value: service.cost > 0 ? TF.money(service.cost, currency, decimals: 2) : nil)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: Figures

    /// The two figures are always there (« – » while unknown), so the pages « Carburant » and « Coûts »
    /// always have their one door.
    @ViewBuilder
    private func stats(state: CarState, now: Date) -> some View {
        let consumption = CarMath.consumption(state)
        let cost = CarMath.monthlyCost(state, at: now)
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Chiffres"))
            HStack(spacing: 10) {
                NavigationLink(value: HomeRoute.page(.carFuel)) {
                    if let consumption {
                        MiniStat(title: tr("Consommation"), value: TF.decimal(consumption, 1), unit: "L/100",
                                 detail: CarMath.fuelCostPerKm(state).map { tr("\(TF.money($0 * 100, currency, decimals: 2)) / 100 km") })
                    } else {
                        MiniStat(title: tr("Consommation"), value: "–", detail: tr("L / 100 km"))
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("car-fuel")
                NavigationLink(value: HomeRoute.page(.carCosts)) {
                    if cost.total > 0 {
                        MiniStat(title: tr("Coût réel"), value: TF.money(cost.total, currency), detail: tr("par mois, tout compris"))
                    } else {
                        MiniStat(title: tr("Coût réel"), value: "–", detail: tr("par mois"))
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("car-cost")
            }
            if consumption == nil {
                // Without two full tanks nothing is worked out: say why, where one looks for it.
                MiniFootnote(text: tr("Aucun plein noté. À chaque plein, note les litres, le prix et le compteur : la consommation se calcule entre deux pleins complets."))
            }
        }
    }

    // MARK: Maintenance

    @ViewBuilder
    private func maintenance(state: CarState, now: Date) -> some View {
        let statuses = CarMath.serviceStatus(state, at: now)
        if !statuses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CarSectionHead(title: tr("Entretien"), page: .carMaintenance)
                NavigationLink(value: HomeRoute.page(.carMaintenance)) {
                    MiniRowsCard {
                        ForEach(Array(statuses.prefix(2).enumerated()), id: \.element.item.id) { index, status in
                            if index > 0 { MiniDivider() }
                            MiniRow(symbol: "wrench.and.screwdriver.fill",
                                    colorHex: status.used >= 1 ? Car.alertHex : (status.used >= 0.85 ? "F08A24" : "3366FF"),
                                    title: status.item.name, detail: Car.remaining(status))
                        }
                    }
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
                CarSectionHead(title: tr("Échéances"), page: .carDeadlines)
                NavigationLink(value: HomeRoute.page(.carDeadlines)) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.prefix(2).enumerated()), id: \.element.id) { index, deadline in
                            if index > 0 { MiniDivider() }
                            let days = DateMath.daysBetween(now, deadline.date)
                            MiniRow(symbol: deadline.symbol, colorHex: days <= 14 ? Car.alertHex : accentHex, title: deadline.title,
                                    detail: Fmt.format(deadline.date, template: "dMMMMyyyy"), value: days == 0 ? tr("aujourd'hui") : tr("J-\(days)"))
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

    /// The list under the sections, only for a page whose other door is hidden (nothing to show yet): « Kilométrage »
    /// (opened by « Ce mois-ci »), « Entretien » and « Échéances » (opened by their sections). « Carburant » and
    /// « Coûts » have their figure always; with every door open there is no list. The identifiers move with the link.
    @ViewBuilder
    private func more(state: CarState, now: Date, hasData: Bool) -> some View {
        let wants = [
            !(hasData && CarMath.kmThisMonth(state, at: now) != nil),
            CarMath.serviceStatus(state, at: now).isEmpty,
            CarMath.upcomingDeadlines(state, at: now).isEmpty,
        ]
        if wants.contains(true) {
            MiniRowsCard {
                if wants[0] {
                    NavigationLink(value: HomeRoute.page(.carMileage)) {
                        MiniRow(symbol: "speedometer", colorHex: accentHex, title: tr("Kilométrage"), detail: tr("Kilomètres par mois"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-mileage")
                }
                if wants[1] {
                    if wants[..<1].contains(true) { MiniDivider() }
                    NavigationLink(value: HomeRoute.page(.carMaintenance)) {
                        MiniRow(symbol: "wrench.and.screwdriver.fill", colorHex: "3366FF", title: tr("Entretien"), detail: tr("Vidange, pneus, freins…"),
                                value: state.services.isEmpty ? nil : "\(state.services.count)")
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-maintenance")
                }
                if wants[2] {
                    if wants[..<2].contains(true) { MiniDivider() }
                    NavigationLink(value: HomeRoute.page(.carDeadlines)) {
                        MiniRow(symbol: "calendar.badge.exclamationmark", colorHex: Car.alertHex, title: tr("Échéances"), detail: tr("Assurance, immatriculation, pneus d'hiver…"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("car-deadlines")
                }
            }
        }
    }
}

/// A section title with its one fixed door: « Tout voir » opens the page.
private struct CarSectionHead: View {
    let title: String
    let page: MiniAppPage

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            MiniSectionTitle(title: title)
            NavigationLink(value: HomeRoute.page(page)) {
                Text(tr("Tout voir"))
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
        }
    }
}

/// A maintenance item: how much of its interval is used and when it is due.
struct ServiceStatusRow: View {
    @Environment(\.appStyle) private var style
    let status: CarMath.ServiceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(status.item.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                Spacer()
                Text(Car.remaining(status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.used >= 1 ? CristalPalette.of(style.id).strong(Car.alertHex) : Color.secondary)
            }
            ProgressView(value: min(1, status.used))
                .accessibilityLabel(status.item.name)
                .accessibilityValue(Fmt.percent(min(1, status.used)))
                .tint(status.used >= 1 ? CristalPalette.of(style.id).category(Car.alertHex) : (status.used >= 0.85 ? CristalPalette.of(style.id).category("F2A33A") : CristalPalette.of(style.id).category("3366FF")))
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
