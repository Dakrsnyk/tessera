import Charts
import SwiftUI

// MARK: - Program

/// The trip day by day: flights, check-ins and check-outs, activities; everything editable.
struct TravelProgramPage: View {
    let tripID: UUID
    @Environment(AppModel.self) private var model
    @State private var sheet: TravelSheet?

    var body: some View {
        let state = model.travel
        Group {
            if let trip = state.trips.first(where: { $0.id == tripID }) {
                let days = TravelMath.program(state, for: trip)
                MiniAppScroll {
                    HStack(spacing: 8) {
                        addButton("Vol", symbol: "airplane") { sheet = .flight(Flight(number: "", from: "", to: "", departure: trip.start)) }
                        addButton("Hébergement", symbol: "bed.double.fill") { sheet = .stay(Stay(name: "", checkIn: trip.start, checkOut: trip.end)) }
                        addButton("Activité", symbol: "mappin.and.ellipse") { sheet = .activity(TripActivity(title: "", date: max(trip.start, Date()))) }
                    }
                    if days.isEmpty {
                        Text("Rien au programme pour l'instant. Ajoute tes vols, ton hébergement et ce que tu veux faire : tout se range ici jour par jour.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .card(padding: 14)
                    }
                    ForEach(days) { day in
                        dayCard(day, trip: trip, state: state)
                    }
                }
                .navigationTitle("Programme")
            } else {
                ContentUnavailableView("Voyage introuvable", systemImage: "airplane")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { $0.editor }
    }

    private func addButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.headline)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color(hex: Travel.accentHex))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color(hex: Travel.accentHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Ajouter : \(title)"))
    }

    private func dayCard(_ day: TravelMath.ProgramDay, trip: Trip, state: TravelState) -> some View {
        let number = DateMath.daysBetween(trip.start, day.day) + 1
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.longDay(day.day).capitalizedFirst).font(.headline)
                Spacer()
                if number >= 1 {
                    Text("Jour \(number)").font(.caption.weight(.semibold)).foregroundStyle(Color(hex: Travel.accentHex))
                }
            }
            MiniRowsCard {
                ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { MiniDivider() }
                    Button { edit(item, state: state) } label: {
                        MiniRow(symbol: item.symbol, colorHex: hex(item.kind), title: item.title, detail: item.detail,
                                value: Fmt.time(item.date, uses24Hour: true), showsChevron: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func hex(_ kind: TravelMath.ProgramItem.Kind) -> String {
        switch kind {
        case .flight: Travel.accentHex
        case .checkIn, .checkOut: "8C6CFF"
        case .activity: "F08A24"
        }
    }

    private func edit(_ item: TravelMath.ProgramItem, state: TravelState) {
        let parts = item.id.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return }
        switch parts[0] {
        case "flight": if let flight = state.flights.first(where: { $0.id == id }) { sheet = .flight(flight) }
        case "in", "out": if let stay = state.stays.first(where: { $0.id == id }) { sheet = .stay(stay) }
        default: if let activity = state.activities.first(where: { $0.id == id }) { sheet = .activity(activity) }
        }
    }
}

// MARK: - Budget

struct TravelBudgetPage: View {
    let tripID: UUID
    @Environment(AppModel.self) private var model
    @State private var sheet: TravelSheet?
    @State private var budgetText = ""

    private var currency: String { model.settings.currencyCode }

    private struct KindShare: Identifiable {
        let kind: TripExpenseKind
        let amount: Double
        var id: String { kind.rawValue }
    }

    var body: some View {
        let state = model.travel
        Group {
            if let trip = state.trips.first(where: { $0.id == tripID }) {
                let spending = TravelMath.spending(state, for: trip, home: currency, rates: model.fx)
                let expenses = state.expenses.filter { $0.tripID == trip.id }.sorted { $0.date > $1.date }
                MiniAppScroll {
                    summary(trip: trip, spending: spending)
                    MiniActionButton(title: "Ajouter une dépense", symbol: "plus", colorHex: Travel.accentHex) {
                        sheet = .expense(TripExpense(tripID: trip.id, amount: 0, currencyCode: TravelMath.isOngoing(trip, at: Date()) ? trip.currencyCode : currency))
                    }
                    .accessibilityIdentifier("trip-expense-new")
                    if !spending.byKind.isEmpty {
                        byKind(spending)
                    }
                    if !expenses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            MiniSectionTitle(title: "Dépenses", detail: "\(expenses.count)")
                            MiniRowsCard {
                                ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                                    if index > 0 { MiniDivider() }
                                    Button { sheet = .expense(expense) } label: {
                                        MiniRow(symbol: expense.kind.symbol, colorHex: expense.kind.colorHex,
                                                title: expense.label.isEmpty ? expense.kind.title : expense.label, detail: Fmt.shortDay(expense.date),
                                                value: Fmt.money(expense.amount, currency: expense.currencyCode), showsChevron: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Budget · \(trip.destination)")
            } else {
                ContentUnavailableView("Voyage introuvable", systemImage: "airplane")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { $0.editor }
    }

    private func summary(trip: Trip, spending: TravelMath.Spending) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dépensé").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(TF.money(spending.total, currency)).font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit()
            if let budget = trip.budget, budget > 0 {
                ProgressView(value: min(1, spending.total / budget)).tint(spending.total > budget ? Color(hex: "E5484D") : Color(hex: Travel.accentHex))
                Text(spending.total > budget ? "Dépassé de \(TF.money(spending.total - budget, currency)) sur \(TF.money(budget, currency))" : "Il reste \(TF.money(budget - spending.total, currency)) sur \(TF.money(budget, currency))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let days = TravelMath.tripDay(trip, at: Date())
                if TravelMath.isOngoing(trip, at: Date()), budget > spending.total {
                    Text("Soit \(TF.money((budget - spending.total) / Double(max(1, days.total - days.day + 1)), currency)) par jour jusqu'au retour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Budget du voyage").font(.subheadline)
                Spacer()
                TextField("Montant", text: $budgetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onSubmit { saveBudget() }
                    .accessibilityIdentifier("trip-budget")
                Text(currency).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            if !spending.unconverted.isEmpty {
                Text("Non converti (taux indisponible) : \(spending.unconverted.map { Fmt.money($0.value, currency: $0.key) }.sorted().joined(separator: ", ")).")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if trip.currencyCode != currency {
                Text("Montants en \(trip.currencyCode) convertis au taux de référence de la BCE.").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onAppear { budgetText = trip.budget.map { TF.int($0) } ?? "" }
        .onChange(of: budgetText) { _, _ in saveBudget() }
    }

    private func saveBudget() {
        let value = Double(budgetText.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) })
        let id = tripID
        model.update(\.travel) { state in
            guard let index = state.trips.firstIndex(where: { $0.id == id }) else { return }
            state.trips[index].budget = (value ?? 0) > 0 ? value : nil
        }
    }

    private func byKind(_ spending: TravelMath.Spending) -> some View {
        let shares = spending.byKind.map { KindShare(kind: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Par type")
            HStack(spacing: 16) {
                Chart(shares) { share in
                    SectorMark(angle: .value("Montant", share.amount), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Color(hex: share.kind.colorHex))
                }
                .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(shares) { share in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: share.kind.colorHex)).frame(width: 8, height: 8)
                            Text(share.kind.title).font(.caption)
                            Spacer()
                            Text(TF.money(share.amount, currency)).font(.caption.weight(.semibold)).monospacedDigit()
                        }
                    }
                }
            }
            .card(padding: 14)
        }
    }
}

// MARK: - Checklist

struct TravelChecklistPage: View {
    let tripID: UUID
    @Environment(AppModel.self) private var model
    @State private var newItem = ""

    var body: some View {
        let state = model.travel
        let items = state.checklist.filter { $0.tripID == tripID }
        let trip = state.trips.first { $0.id == tripID }
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color(hex: Travel.accentHex))
                    TextField("Ajouter (maillot, cadeaux…)", text: $newItem)
                        .submitLabel(.done)
                        .onSubmit(add)
                        .accessibilityIdentifier("checklist-add")
                }
            }
            if !items.isEmpty {
                Section {
                    ForEach(items) { item in
                        Button {
                            Haptics.tap()
                            model.update(\.travel) { $0.toggleChecklist(item.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isDone ? Color(hex: "1E9E75") : Color.secondary)
                                Text(item.title)
                                    .strikethrough(item.isDone)
                                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                            }
                        }
                        .accessibilityIdentifier("checklist-item")
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { items[$0].id }
                        model.update(\.travel) { $0.checklist.removeAll { ids.contains($0.id) } }
                    }
                } header: {
                    Text("\(items.filter(\.isDone).count) sur \(items.count) prêts")
                }
            }
            Section {
                Button {
                    let abroad = trip.map { $0.currencyCode != model.settings.currencyCode || TravelMath.offsetHours($0.timeZone, at: $0.start) != 0 } ?? true
                    model.update(\.travel) { $0.addEssentials(to: tripID, abroad: abroad) }
                } label: {
                    Label("Ajouter l'essentiel à emporter", systemImage: "sparkles")
                }
                .accessibilityIdentifier("checklist-essentials")
            } footer: {
                Text("Ajoute les incontournables (passeport, chargeur, assurance…) sans doublon ; retire ceux qui ne te servent pas en glissant.")
            }
        }
        .styledList()
        .tint(Color(hex: Travel.accentHex))
        .navigationTitle("À ne pas oublier")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let title = newItem.trimmed
        guard !title.isEmpty else { return }
        let id = tripID
        model.update(\.travel) { $0.checklist.append(ChecklistItem(tripID: id, title: title)) }
        newItem = ""
    }
}
