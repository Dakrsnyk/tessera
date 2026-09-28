import SwiftUI
import WidgetKit

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    TodayPanel()
                    myWidgets
                    featured
                    categories
                    if !model.isPremium {
                        PremiumBanner { router.isPaywallPresented = true }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(Color.screenFill)
            .navigationTitle("Tessera")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        router.openExplore(search: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(Text("Rechercher un widget"))
                    Button {
                        router.openExplore()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Créer un widget"))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.longDay(Date()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(greeting)
                .font(.title2.weight(.semibold))
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }

    @ViewBuilder private var myWidgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mes widgets", actionTitle: model.designs.isEmpty ? nil : "Tout voir") {
                router.tab = .mine
            }
            if model.designs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Crée ton premier widget")
                        .font(.headline)
                    Text("Choisis un modèle, personnalise-le, puis ajoute-le à ton écran d'accueil.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        router.openExplore()
                    } label: {
                        Label("Parcourir les widgets", systemImage: "square.grid.2x2")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
                .card()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(model.recentDesigns.prefix(8)) { design in
                            Button {
                                router.openEditor(design, isNew: false)
                            } label: {
                                DesignCard(design: design, payload: model.payload(for: design), width: 150, isPremiumUser: model.isPremium)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    private var featured: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sélection", actionTitle: "Explorer") { router.openExplore() }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(TemplateCatalog.featured) { template in
                        Button {
                            router.openEditor(template.makeDesign(), isNew: true)
                        } label: {
                            TemplateCard(template: template, width: 150, isPremiumUser: model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Catégories")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(WidgetCategory.allCases) { category in
                    Button {
                        router.openExplore(category: category)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(category.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(Fmt.plural(WidgetKind.kinds(in: category).count, "widget", "widgets"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .card(padding: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Today

/// Daily check-in: tasks, habits and water, without leaving the home screen.
struct TodayPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Aujourd'hui")
            VStack(spacing: 0) {
                tasksRow
                Divider().padding(.leading, 56)
                habitsRow
                Divider().padding(.leading, 56)
                waterRow
            }
            .background(Color.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var tasksRow: some View {
        let tasks = model.content.tasks
        let done = tasks.filter(\.isDone).count
        return Button {
            router.content = .tasks
        } label: {
            TodayRow(symbol: "checklist", title: "Tâches", detail: tasks.isEmpty ? "Ajoute ta première tâche" : "\(done) sur \(tasks.count) terminées") {
                if !tasks.isEmpty {
                    RingView(progress: Double(done) / Double(max(1, tasks.count)), lineWidth: 4, color: .accentColor, track: Color.secondary.opacity(0.2))
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var habitsRow: some View {
        let habits = model.content.habits
        return HStack(spacing: 0) {
            Button {
                router.content = .habits
            } label: {
                TodayRow(symbol: "repeat", title: "Habitudes", detail: habits.isEmpty ? "Crée ta première habitude" : "\(habits.filter { $0.isDone(on: Date()) }.count) sur \(habits.count) aujourd'hui") {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            if !habits.isEmpty {
                HStack(spacing: 6) {
                    ForEach(habits.prefix(4)) { habit in
                        let done = habit.isDone(on: Date())
                        Button {
                            Haptics.tap()
                            model.updateContent { $0.toggleHabit(habit.id) }
                        } label: {
                            Image(systemName: habit.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(done ? .white : Color(hex: habit.colorHex))
                                .frame(width: 32, height: 32)
                                .background {
                                    Circle().fill(done ? Color(hex: habit.colorHex) : Color(hex: habit.colorHex).opacity(0.14))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("\(habit.name), \(done ? "fait" : "à faire")"))
                    }
                }
                .padding(.trailing, 14)
            }
        }
    }

    private var waterRow: some View {
        let state = model.content.hydration
        let count = state.glasses(on: Date())
        return HStack(spacing: 0) {
            Button {
                router.content = .hydration
            } label: {
                TodayRow(symbol: "drop.fill", title: "Eau", detail: "\(count) sur \(state.goal) verres") { EmptyView() }
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                Button {
                    model.updateContent { $0.hydration.add(-1, on: Date()) }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .accessibilityLabel(Text("Retirer un verre"))
                Button {
                    Haptics.tap()
                    model.updateContent { $0.hydration.add(1, on: Date()) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Ajouter un verre"))
            }
            .padding(.trailing, 14)
        }
    }
}

private struct TodayRow<Trailing: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct PremiumBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.premiumInk)
                    .frame(width: 48, height: 48)
                    .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tessera Premium")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tous les widgets, 12 styles, fonds photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
