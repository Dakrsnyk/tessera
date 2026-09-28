import SwiftUI

struct HydrationView: View {
    @Environment(AppModel.self) private var model
    @State private var notificationsDenied = false

    var body: some View {
        let state = model.content.hydration
        let count = state.glasses(on: Date())
        let goal = max(1, state.goal)
        List {
            Section {
                VStack(spacing: 18) {
                    ZStack {
                        RingView(progress: Double(count) / Double(goal), lineWidth: 14, color: .accentColor, track: Color.secondary.opacity(0.15))
                        VStack(spacing: 0) {
                            Text("\(count)")
                                .font(.system(size: 52, weight: .semibold, design: .rounded))
                                .contentTransition(.numericText())
                            Text("sur \(goal) verres")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 190, height: 190)
                    .accessibilityElement(children: .combine)

                    HStack(spacing: 16) {
                        Button {
                            withAnimation { model.updateContent { $0.hydration.add(-1, on: Date()) } }
                        } label: {
                            Image(systemName: "minus")
                                .font(.title3.weight(.bold))
                                .frame(width: 56, height: 56)
                                .background(Color.secondary.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(count == 0)
                        .accessibilityLabel(Text("Retirer un verre"))

                        Button {
                            Haptics.tap()
                            withAnimation { model.updateContent { $0.hydration.add(1, on: Date()) } }
                        } label: {
                            Label("Un verre", systemImage: "plus")
                                .font(.headline)
                                .foregroundStyle(Color.onAccent)
                                .frame(width: 150, height: 56)
                                .background(Color.accentColor, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                Stepper(value: Binding(
                    get: { state.goal },
                    set: { goal in model.updateContent { $0.hydration.goal = goal } }
                ), in: 1...20) {
                    Text("Objectif : \(state.goal) verres par jour")
                }
                Toggle("Rappels de 10 h à 20 h", isOn: Binding(
                    get: { model.settings.hydrationReminders },
                    set: { enabled in setReminders(enabled) }
                ))
            } footer: {
                Text(notificationsDenied
                    ? "Les notifications sont désactivées pour Tessera dans Réglages."
                    : "Un rappel toutes les deux heures. Tu peux aussi ajouter un verre depuis le widget.")
            }

            Section("7 derniers jours") {
                let days = (0..<7).compactMap { DateMath.calendar.date(byAdding: .day, value: -$0, to: Date()) }
                ForEach(days, id: \.self) { day in
                    HStack {
                        Text(DateMath.isSameDay(day, Date()) ? "Aujourd'hui" : Fmt.shortDay(day))
                        Spacer()
                        Text("\(state.glasses(on: day)) / \(goal)")
                            .monospacedDigit()
                            .foregroundStyle(state.glasses(on: day) >= goal ? Color.accentColor : .secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .styledList()
        .navigationTitle("Hydratation")
    }

    private func setReminders(_ enabled: Bool) {
        guard enabled else {
            model.updateSettings { $0.hydrationReminders = false }
            NotificationScheduler.setHydrationReminders(false)
            return
        }
        Task {
            let granted = await NotificationScheduler.requestAuthorization()
            notificationsDenied = !granted
            model.updateSettings { $0.hydrationReminders = granted }
            NotificationScheduler.setHydrationReminders(granted)
        }
    }
}
