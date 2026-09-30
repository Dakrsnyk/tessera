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
    static let alertHex = "E5484D"

    static func remaining(_ status: CarMath.ServiceStatus) -> String {
        var parts: [String] = []
        if let km = status.kmLeft { parts.append(km >= 0 ? "dans \(Fmt.number(Int(km))) km" : "dépassé de \(Fmt.number(Int(-km))) km") }
        if let days = status.daysLeft { parts.append(days >= 0 ? "d'ici \(days) j" : "en retard de \(-days) j") }
        return parts.isEmpty ? "Pas encore de repère" : parts.joined(separator: " ou ")
    }
}

/// The Auto mini-app: the odometer, the range left, the consumption and the cost; what maintenance
/// comes and the deadlines; then fuel, mileage, maintenance, deadlines and costs in detail.
struct CarAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: CarSheet?

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Car.accentHex }

    var body: some View {
        let now = Date()
        let state = model.car
        MiniAppScroll {
            if state.fills.isEmpty && state.readings.isEmpty && state.services.isEmpty && state.deadlines.isEmpty {
                start
            } else {
                hero(state: state, now: now)
            }
            HStack(spacing: 10) {
                MiniActionButton(title: "Plein", symbol: "fuelpump.fill", colorHex: Car.fuelHex) { sheet = .fuel(nil) }
                    .accessibilityIdentifier("car-add-fuel")
                MiniActionButton(title: "Kilométrage", symbol: "speedometer", colorHex: accentHex, isProminent: false) { sheet = .odometer }
                    .accessibilityIdentifier("car-add-odometer")
            }
            stats(state: state, now: now)
            maintenance(state: state, now: now)
            deadlines(state: state, now: now)
            more(state: state, now: now)
        }
        .navigationTitle(state.name.isEmpty ? "Auto" : state.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel(Text("Voiture et réservoir"))
                    .accessibilityIdentifier("car-settings")
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "car.fill").font(.system(size: 28)).foregroundStyle(Color(hex: accentHex))
            Text("Ta voiture, sans surprise").font(.title3.weight(.bold))
            Text("Note tes pleins et ton kilométrage : consommation, autonomie, coût réel par mois, entretiens et échéances se suivent tout seuls.")
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
                    Text("Compteur").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(CarMath.odometer(state).map { "\(Fmt.number(Int($0))) km" } ?? "–")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                if let month = CarMath.kmThisMonth(state, at: now) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Ce mois-ci").font(.caption).foregroundStyle(.secondary)
                        Text("\(Fmt.number(Int(month))) km").font(.headline).monospacedDigit()
                    }
                }
            }
            if let range {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Autonomie estimée", systemImage: "fuelpump.fill").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("≈ \(Fmt.number(Int(range.km))) km").font(.headline).monospacedDigit()
                    }
                    ProgressView(value: range.share)
                        .tint(range.share < 0.2 ? Color(hex: Car.alertHex) : Color(hex: Car.fuelHex))
                    Text("Environ \(TF.int(range.liters)) L dans le réservoir, d'après ta consommation depuis le plein du \(Fmt.shortDay(range.since.date)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(hex: Car.fuelHex).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if state.tankLiters == nil && CarMath.consumption(state) != nil {
                Button { sheet = .settings } label: {
                    Label("Indique la taille du réservoir pour voir l'autonomie", systemImage: "fuelpump")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: Car.fuelHex))
                }
                .buttonStyle(.plain)
            }
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("car-hero")
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
                        MiniStat(title: "Consommation", value: TF.decimal(consumption, 1), unit: "L/100",
                                 detail: CarMath.fuelCostPerKm(state).map { "\(TF.money($0 * 100, currency, decimals: 2)) / 100 km" })
                    }
                    .buttonStyle(.plain)
                }
                if cost.total > 0 {
                    NavigationLink(value: HomeRoute.page(.carCosts)) {
                        MiniStat(title: "Coût réel", value: TF.money(cost.total, currency), detail: "par mois, tout compris")
                    }
                    .buttonStyle(.plain)
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
                MiniSectionTitle(title: "Entretien")
                NavigationLink(value: HomeRoute.page(.carMaintenance)) {
                    VStack(spacing: 12) {
                        ForEach(statuses.prefix(2), id: \.item.id) { status in
                            ServiceStatusRow(status: status)
                        }
                    }
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("car-maintenance")
            }
        }
    }

    @ViewBuilder
    private func deadlines(state: CarState, now: Date) -> some View {
        let upcoming = CarMath.upcomingDeadlines(state, at: now)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "Échéances")
                NavigationLink(value: HomeRoute.page(.carDeadlines)) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.prefix(2).enumerated()), id: \.element.id) { index, deadline in
                            if index > 0 { MiniDivider() }
                            let days = DateMath.daysBetween(now, deadline.date)
                            MiniRow(symbol: deadline.symbol, colorHex: days <= 14 ? Car.alertHex : accentHex, title: deadline.title,
                                    detail: Fmt.format(deadline.date, template: "dMMMMyyyy"), value: days == 0 ? "aujourd'hui" : "J-\(days)", showsChevron: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("car-deadlines")
            }
        }
    }

    // MARK: More

    private func more(state: CarState, now: Date) -> some View {
        MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.carFuel)) {
                MiniRow(symbol: "fuelpump.fill", colorHex: Car.fuelHex, title: "Carburant", detail: "Pleins, prix et consommation",
                        value: state.fills.isEmpty ? nil : "\(state.fills.count)")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("car-fuel")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.carMileage)) {
                MiniRow(symbol: "speedometer", colorHex: accentHex, title: "Kilométrage", detail: "Kilomètres par mois")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("car-mileage")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.carMaintenance)) {
                MiniRow(symbol: "wrench.and.screwdriver.fill", colorHex: "3366FF", title: "Entretien", detail: "Vidange, pneus, freins…",
                        value: state.services.isEmpty ? nil : "\(state.services.count)")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.carDeadlines)) {
                MiniRow(symbol: "calendar.badge.exclamationmark", colorHex: Car.alertHex, title: "Échéances", detail: "Assurance, immatriculation, pneus d'hiver…")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.carCosts)) {
                MiniRow(symbol: "creditcard.fill", colorHex: "2F8F7A", title: "Coûts", detail: "Ce que la voiture coûte vraiment chaque mois")
            }
            .buttonStyle(.plain)
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
        SheetForm(title: "Ma voiture", canSave: true, onSave: save) {
            Section {
                TextField("Nom de la voiture", text: $name)
                NumberRow(title: "Réservoir", value: $tank, unit: "L")
                    .accessibilityIdentifier("car-tank")
            } footer: {
                Text("La taille du réservoir (dans le manuel ou sur le site du constructeur) sert à estimer l'autonomie après un plein complet.")
            }
        }
        .onAppear {
            name = model.car.name
            tank = model.car.tankLiters ?? 0
        }
    }

    private func save() {
        let liters = tank
        model.setCarName(name.trimmed.isEmpty ? "Ma voiture" : name.trimmed)
        model.update(\.car) { $0.tankLiters = liters > 0 ? liters : nil }
    }
}
