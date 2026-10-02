import SwiftUI

struct HabitsView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Habit?
    @State private var showsPaywall = false

    var body: some View {
        let habits = model.content.habits
        List {
            if habits.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("Aucune habitude pour l'instant"))
                            .font(.headline)
                        Text(tr("Crée une habitude, puis valide-la chaque jour d'une touche sur ton widget."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Section {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit) {
                            Haptics.tap()
                            model.updateContent { $0.toggleHabit(habit.id) }
                        } onEdit: {
                            editing = habit
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { habits[$0].id }
                        ids.forEach(NotificationScheduler.cancelHabitReminder)
                        model.updateContent { content in content.habits.removeAll { ids.contains($0.id) } }
                    }
                    .onMove { source, destination in
                        model.updateContent { $0.habits.move(fromOffsets: source, toOffset: destination) }
                    }
                } footer: {
                    if !model.isPremium {
                        Text(tr("\(min(habits.count, AppModel.freeHabitLimit)) sur \(AppModel.freeHabitLimit) habitudes en version gratuite."))
                    }
                }
            }

            Section {
                Button {
                    if model.canAddHabit {
                        editing = Habit(name: "", symbol: HabitEditor.symbols[0], colorHex: Palette.freeAccents[0].hex)
                    } else {
                        showsPaywall = true
                    }
                } label: {
                    Label(tr("Nouvelle habitude"), systemImage: "plus.circle.fill")
                }
            }
        }
        .styledList()
        .navigationTitle(tr("Habitudes"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if habits.count > 1 { EditButton() }
            }
        }
        .sheet(item: $editing) { habit in
            HabitEditor(habit: habit, isNew: !habits.contains { $0.id == habit.id })
        }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let color = Color(hex: habit.colorHex)
        let done = habit.isDone(on: Date())
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: habit.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(done ? .white : color)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(done ? color : color.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(done ? tr("Marquer \(habit.name) comme non fait") : tr("Valider \(habit.name)")))

            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name).foregroundStyle(.primary)
                        let streak = habit.streak()
                        Text(streak > 0 ? tr("Série de \(streak) jour\(streak > 1 ? "s" : "")") : tr("Pas encore de série"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(DateMath.week(containing: Date()), id: \.self) { day in
                            Circle()
                                .fill(habit.isDone(on: day) ? color : Color.secondary.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct HabitEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var habit: Habit
    @State private var hasReminder: Bool
    @State private var reminderTime: Date
    @State private var notificationsDenied = false
    let isNew: Bool

    static let symbols = [
        "figure.run", "figure.walk", "dumbbell.fill", "figure.yoga", "brain.head.profile", "book.fill",
        "pencil", "drop.fill", "leaf.fill", "bed.double.fill", "fork.knife", "cup.and.saucer.fill",
        "music.note", "paintbrush.fill", "globe", "heart.fill", "sun.max.fill", "moon.fill",
        "phone.down.fill", "dollarsign.circle.fill",
    ]

    init(habit: Habit, isNew: Bool) {
        _habit = State(initialValue: habit)
        _hasReminder = State(initialValue: habit.reminderHour != nil)
        _reminderTime = State(initialValue: habit.reminderDate
            ?? DateMath.calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date())
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("Nom")) {
                    TextField(tr("Méditer, lire, courir…"), text: $habit.name)
                }
                Section(tr("Icône")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { symbol in
                            Button {
                                habit.symbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(habit.symbol == symbol ? .white : Color(hex: habit.colorHex))
                                    .frame(width: 46, height: 46)
                                    .background(Circle().fill(habit.symbol == symbol ? Color(hex: habit.colorHex) : Color(hex: habit.colorHex).opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section(tr("Couleur")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
                        ForEach(Palette.freeAccents) { swatch in
                            ColorDot(hex: swatch.hex, isSelected: habit.colorHex == swatch.hex, size: 26) {
                                habit.colorHex = swatch.hex
                            }
                            .accessibilityLabel(Text(swatch.name))
                        }
                    }
                }
                Section {
                    Toggle(tr("Rappel quotidien"), isOn: $hasReminder)
                    if hasReminder {
                        DatePicker(tr("Heure"), selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Fmt.locale)
                    }
                } footer: {
                    if notificationsDenied {
                        Text(tr("Les notifications sont désactivées pour Tessera dans Réglages."))
                    }
                }
                if !isNew {
                    Section {
                        Button(tr("Supprimer l'habitude"), role: .destructive) {
                            NotificationScheduler.cancelHabitReminder(habit.id)
                            model.updateContent { content in content.habits.removeAll { $0.id == habit.id } }
                            dismiss()
                        }
                    }
                }
            }
            .styledList()
            .navigationTitle(isNew ? tr("Nouvelle habitude") : tr("Habitude"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Enregistrer"), action: save)
                        .disabled(habit.name.trimmed.isEmpty)
                }
            }
            .onChange(of: hasReminder) { _, enabled in
                guard enabled else { return }
                Task {
                    let granted = await NotificationScheduler.requestAuthorization()
                    notificationsDenied = !granted
                    if !granted { hasReminder = false }
                }
            }
        }
    }

    private func save() {
        var saved = habit
        saved.name = saved.name.trimmed
        if hasReminder {
            let parts = DateMath.calendar.dateComponents([.hour, .minute], from: reminderTime)
            saved.reminderHour = parts.hour
            saved.reminderMinute = parts.minute
        } else {
            saved.reminderHour = nil
            saved.reminderMinute = nil
        }
        model.updateContent { content in
            if let index = content.habits.firstIndex(where: { $0.id == saved.id }) {
                content.habits[index] = saved
            } else {
                content.habits.append(saved)
            }
        }
        NotificationScheduler.syncHabitReminder(saved)
        dismiss()
    }
}
