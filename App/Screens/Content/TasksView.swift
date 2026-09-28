import SwiftUI

struct TasksView: View {
    @Environment(AppModel.self) private var model
    @State private var newTitle = ""
    @FocusState private var isAdding: Bool

    var body: some View {
        let tasks = model.content.tasks
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    TextField("Nouvelle tâche", text: $newTitle)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
                .frame(minHeight: 36)
            }

            if tasks.isEmpty {
                Section {
                    Text("Tes tâches apparaîtront dans le widget, et tu pourras les cocher directement depuis l'écran d'accueil.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("À faire") {
                    let open = tasks.filter { !$0.isDone }
                    if open.isEmpty {
                        Text("Tout est fait.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(open) { task in
                        row(task)
                    }
                    .onDelete { offsets in delete(offsets, in: open) }
                    .onMove { source, destination in move(source, destination, in: open) }
                }
                let done = tasks.filter(\.isDone)
                if !done.isEmpty {
                    Section {
                        ForEach(done) { task in
                            row(task)
                        }
                        .onDelete { offsets in delete(offsets, in: done) }
                    } header: {
                        HStack {
                            Text("Terminées")
                            Spacer()
                            Button("Tout effacer") {
                                model.updateContent { $0.tasks.removeAll(where: \.isDone) }
                            }
                            .font(.footnote.weight(.semibold))
                            .textCase(nil)
                        }
                    }
                }
            }
        }
        .styledList()
        .navigationTitle("Tâches")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !tasks.isEmpty { EditButton() }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        Button {
            Haptics.tap()
            withAnimation { model.updateContent { $0.toggleTask(task.id) } }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(task.isDone ? .isSelected : [])
    }

    private func add() {
        let title = newTitle.trimmed
        guard !title.isEmpty else { return }
        model.updateContent { $0.tasks.insert(TaskItem(title: title), at: 0) }
        newTitle = ""
        isAdding = true
    }

    private func delete(_ offsets: IndexSet, in subset: [TaskItem]) {
        let ids = Set(offsets.map { subset[$0].id })
        model.updateContent { $0.tasks.removeAll { ids.contains($0.id) } }
    }

    private func move(_ source: IndexSet, _ destination: Int, in subset: [TaskItem]) {
        var reordered = subset
        reordered.move(fromOffsets: source, toOffset: destination)
        model.updateContent { content in
            let done = content.tasks.filter(\.isDone)
            content.tasks = reordered + done
        }
    }
}
