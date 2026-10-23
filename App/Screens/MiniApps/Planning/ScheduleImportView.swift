import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Puts the classes read from a photo or a PDF into the timetable of the app, without ever erasing or
/// doubling what is already there. Pure (no model, no screen) so that it can be tested.
enum ScheduleImportMerge {
    /// The slots that can be saved: ticked, with a name and an end after the start, on a day of the week.
    static func importable(_ imported: [ImportedSlot]) -> [ImportedSlot] {
        imported.filter { isValid($0) }
    }

    static func isValid(_ slot: ImportedSlot) -> Bool {
        slot.isSelected
            && !slot.title.trimmed.isEmpty
            && (1...7).contains(slot.weekday)
            && slot.startMinute >= 0
            && slot.endMinute <= 24 * 60
            && slot.endMinute > slot.startMinute
    }

    /// A name compared without its case, its accents or the spaces around it (« Chimie » is « chimie »).
    static func key(_ name: String) -> String {
        name.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Adds each importable slot as a weekly class of its course (the course is made when no course
    /// has that name). A slot already in the timetable (same course, day and hours, repeating every week)
    /// is left as it is. Nothing existing is removed or changed. `added` counts the slots really added.
    static func merge(_ imported: [ImportedSlot], into state: StudentState) -> (state: StudentState, added: Int) {
        var result = state
        var added = 0
        for item in importable(imported) {
            let name = item.title.trimmed
            let courseID: UUID
            if let existing = result.courses.first(where: { key($0.name) == key(name) }) {
                courseID = existing.id
            } else {
                let colors = SpaceColors.choices
                let course = Course(name: name, colorHex: colors[result.courses.count % colors.count])
                result.courses.append(course)
                courseID = course.id
            }
            let isDuplicate = result.slots.contains {
                $0.kind == .course && $0.courseID == courseID && $0.date == nil
                    && $0.weekday == item.weekday && $0.startMinute == item.startMinute && $0.endMinute == item.endMinute
            }
            guard !isDuplicate else { continue }
            result.slots.append(ClassSlot(courseID: courseID, weekday: item.weekday, startMinute: item.startMinute, endMinute: item.endMinute,
                                          room: (item.room ?? "").trimmed))
            added += 1
        }
        return (result, added)
    }
}

/// « Importer mon horaire »: a photo or a PDF of the timetable is read on the iPhone, the classes found are
/// shown to check and correct, then added to the Planning's schedule. Four steps: the source, the reading,
/// the check, the confirmation. The photo is chosen with the system picker (no access to the photo library, no
/// camera) and nothing leaves the iPhone.
struct ScheduleImportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Stage: Equatable {
        case pick
        case reading
        case failed(unreadable: Bool)
        case review
        case done(added: Int, skipped: Int)
    }

    @State private var stage: Stage = .pick
    @State private var slots: [ImportedSlot] = []
    /// The classes marked "to check" at the reading without any precise field (a page explained poorly as a whole): they
    /// stay marked when the person corrects fields. For the others, the mark goes when the last uncertain field is corrected.
    @State private var inheritedDoubt: Set<UUID> = []
    @State private var photoItem: PhotosPickerItem?
    @State private var choosesFile = false
    @State private var readTask: Task<Void, Never>?

    private var accentHex: String { MiniApp.planning.colorHex }
    private var accent: Color { Color(hex: accentHex) }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick: pickStep
                case .reading: readingStep
                case .failed(let unreadable): failedStep(unreadable: unreadable)
                case .review: reviewStep
                case .done(let added, let skipped): doneStep(added: added, skipped: skipped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.screenGradient)
            .navigationTitle(tr("Importer mon horaire"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
            }
        }
        .tint(accent)
        .environment(\.miniAccent, accent)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            readPhoto(item)
        }
        .fileImporter(isPresented: $choosesFile, allowedContentTypes: [.pdf, .image]) { result in
            guard case let .success(url) = result else { return }
            readFile(at: url)
        }
        .onDisappear { readTask?.cancel() }
        .interactiveDismissDisabled(stage == .reading)
    }

    // MARK: Steps

    /// 1. The source: a photo (system picker) or a PDF (Files).
    private var pickStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    MiniSectionTitle(title: tr("Ton horaire"))
                    Text(tr("Choisis une photo bien nette ou un PDF de ton horaire de cours. La lecture se fait sur ton iPhone : rien n'est envoyé."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    sourceLabel(tr("Choisir une photo"), symbol: "photo.on.rectangle", isProminent: true)
                }
                .accessibilityIdentifier("schedule-import-photo")
                Button {
                    choosesFile = true
                } label: {
                    sourceLabel(tr("Choisir un PDF"), symbol: "doc.richtext", isProminent: false)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("schedule-import-pdf")
                MiniFootnote(text: tr("Tu pourras vérifier et corriger chaque cours avant de l'ajouter. Rien n'est supprimé de ton horaire actuel."))
            }
            .padding(16)
        }
    }

    private func sourceLabel(_ title: String, symbol: String, isProminent: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(isProminent ? Color.white : accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isProminent ? accent : accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 2. The reading, on the iPhone.
    private var readingStep: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(tr("Lecture de ton horaire…"))
                .font(.headline)
            Text(tr("Cela peut prendre quelques secondes."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("schedule-import-reading")
    }

    /// Nothing found, or a file that couldn't be opened: what to do next.
    private func failedStep(unreadable: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: unreadable ? "exclamationmark.triangle.fill" : "doc.text.magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(accent)
            Text(unreadable ? tr("Impossible de lire ce fichier") : tr("Aucun cours trouvé"))
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(unreadable
                 ? tr("Le fichier n'a pas pu être ouvert. Essaie avec une autre photo ou un autre PDF.")
                 : tr("Je n'ai pas trouvé de cours dans ce document. Essaie avec une photo plus nette, bien cadrée et sans reflet, ou avec le PDF."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            MiniActionButton(title: tr("Essayer avec une autre photo"), symbol: "arrow.counterclockwise", colorHex: accentHex) {
                slots = []
                stage = .pick
            }
            .accessibilityIdentifier("schedule-import-retry")
        }
        .padding(24)
    }

    /// 3. The check: the classes found by day, all ticked, each one to correct, to untick or to delete; a class missing
    /// from the reading can be added by hand.
    private var reviewStep: some View {
        let count = ScheduleImportMerge.importable(slots).count
        let doubtful = slots.filter { $0.needsCheck || !$0.uncertain.isEmpty }.count
        let hasUnticked = slots.contains { !$0.isSelected }
        let hasUncertainTicked = slots.contains { $0.isSelected && !$0.uncertain.isEmpty }
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tr("Vérifie ce qui a été lu, corrige si besoin, puis ajoute les cours à ton horaire."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if doubtful > 0 {
                        Label(tr("Les cours marqués « À vérifier » ont été lus avec un doute : regarde-les de près."),
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: MiniStyle.alertHex))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("schedule-import-doubt-note")
                    }
                    if hasUncertainTicked || hasUnticked {
                        VStack(spacing: 10) {
                            if hasUncertainTicked {
                                MiniActionButton(title: tr("Décocher les cours incertains"), symbol: "exclamationmark.triangle",
                                                 colorHex: MiniStyle.alertHex, isProminent: false) {
                                    untickUncertain()
                                }
                                .accessibilityIdentifier("schedule-import-untick-uncertain")
                            }
                            if hasUnticked {
                                MiniActionButton(title: tr("Tout cocher"), symbol: "checkmark.circle", colorHex: accentHex, isProminent: false) {
                                    tickAll()
                                }
                                .accessibilityIdentifier("schedule-import-tick-all")
                            }
                        }
                    }
                    ForEach(1...7, id: \.self) { day in
                        if slots.contains(where: { $0.weekday == day }) {
                            VStack(alignment: .leading, spacing: 10) {
                                MiniSectionTitle(title: Studies.weekdayNames[day - 1])
                                ForEach($slots) { $slot in
                                    if slot.weekday == day {
                                        slotCard($slot)
                                            .id(slot.id)
                                    }
                                }
                            }
                        }
                    }
                    MiniActionButton(title: tr("Ajouter un cours"), symbol: "plus.circle", colorHex: accentHex, isProminent: false) {
                        addBlankSlot(scrollingWith: proxy)
                    }
                    .accessibilityIdentifier("schedule-import-add-course")
                }
                .padding(16)
                .padding(.bottom, 70)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            MiniActionButton(title: tr("Ajouter à mon horaire (\(count))"), symbol: "calendar.badge.plus", colorHex: accentHex) {
                save()
            }
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("schedule-import-add")
        }
    }

    /// Unticks every class that has a field read with a doubt (they stay in the list, to be checked and ticked again).
    private func untickUncertain() {
        Haptics.tap()
        withAnimation {
            for index in slots.indices where !slots[index].uncertain.isEmpty { slots[index].isSelected = false }
        }
    }

    private func tickAll() {
        Haptics.tap()
        withAnimation {
            for index in slots.indices { slots[index].isSelected = true }
        }
    }

    /// An empty class to fill in (the same day as the last one, 8:00 to 9:00): the card is scrolled into view.
    private func addBlankSlot(scrollingWith proxy: ScrollViewProxy) {
        let blank = ImportedSlot(weekday: slots.last?.weekday ?? 1, startMinute: 8 * 60, endMinute: 9 * 60, title: "")
        Haptics.tap()
        withAnimation { slots.append(blank) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation { proxy.scrollTo(blank.id, anchor: .center) }
        }
    }

    /// One class found: tick, name, day, hours and room; a mark when the reading was in doubt; a button to delete it.
    private func slotCard(_ slot: Binding<ImportedSlot>) -> some View {
        let value = slot.wrappedValue
        let invalidTime = value.endMinute <= value.startMinute
        let uncertain = value.uncertain
        let flagged = value.needsCheck || !uncertain.isEmpty
        // A ticked class without a name cannot be added: the field is shown as one to fix, with a hint.
        let missingTitle = value.isSelected && value.title.trimmed.isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            if flagged {
                Label(tr("À vérifier"), systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: MiniStyle.alertHex))
                    .accessibilityIdentifier("schedule-import-doubt")
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    slot.isSelected.wrappedValue.toggle()
                } label: {
                    Image(systemName: value.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(value.isSelected ? accent : .secondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(tr("Inclure ce cours")))
                .accessibilityValue(Text(value.isSelected ? tr("Oui") : tr("Non")))
                TextField(tr("Titre"), text: clearing(.title, of: slot, slot.title))
                    .font(.body.weight(.semibold))
                    .uncertainHighlight(uncertain.contains(.title) || missingTitle)
                    .accessibilityIdentifier("schedule-import-title")
                Button {
                    Haptics.tap()
                    let id = value.id
                    withAnimation { slots.removeAll { $0.id == id } }
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(tr("Supprimer ce cours")))
                .accessibilityIdentifier("schedule-import-delete")
            }
            if missingTitle {
                Label(tr("Donne un nom à ce cours pour pouvoir l'ajouter."), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: MiniStyle.alertHex))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("schedule-import-title-missing")
            }
            if value.isSelected {
                // Each field read with a doubt is highlighted; changing it clears the mark (see `clearing`).
                Picker(tr("Jour"), selection: clearing(.day, of: slot, slot.weekday)) {
                    ForEach(1...7, id: \.self) { day in
                        Text(Studies.weekdayNames[day - 1]).tag(day)
                    }
                }
                .uncertainHighlight(uncertain.contains(.day))
                MinuteTimePicker(title: tr("Début"), minutes: clearing(.start, of: slot, slot.startMinute))
                    .uncertainHighlight(uncertain.contains(.start))
                MinuteTimePicker(title: tr("Fin"), minutes: clearing(.end, of: slot, slot.endMinute))
                    .uncertainHighlight(uncertain.contains(.end))
                if invalidTime {
                    Label(tr("La fin doit venir après le début."), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: MiniStyle.alertHex))
                }
                TextField(tr("Salle (facultatif)"), text: clearing(.room, of: slot, Binding(get: { slot.room.wrappedValue ?? "" },
                                                                                          set: { slot.room.wrappedValue = $0 })))
                    .font(.subheadline)
                    .uncertainHighlight(uncertain.contains(.room))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .miniCard()
        .overlay(
            RoundedRectangle(cornerRadius: MiniStyle.cardRadius, style: .continuous)
                .stroke(Color(hex: MiniStyle.alertHex).opacity(flagged ? 0.7 : 0), lineWidth: 1.5)
        )
        .opacity(value.isSelected ? 1 : 0.6)
    }

    /// A binding that, when the person changes the value, also removes `field` from the uncertain fields of the class:
    /// what was corrected by hand is no longer in doubt.
    private func clearing<Value>(_ field: SlotField, of slot: Binding<ImportedSlot>, _ binding: Binding<Value>) -> Binding<Value> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue
                slot.wrappedValue.uncertain.remove(field)
                if slot.wrappedValue.uncertain.isEmpty, !inheritedDoubt.contains(slot.wrappedValue.id) {
                    slot.wrappedValue.needsCheck = false
                }
            }
        )
    }

    /// 4. The confirmation, before the sheet closes by itself.
    private func doneStep(added: Int, skipped: Int) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(accent)
            Text(added > 0 ? Fmt.plural(added, tr("créneau ajouté"), tr("créneaux ajoutés")) : tr("Rien de nouveau à ajouter"))
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            if skipped > 0 {
                Text(skipped == 1 ? tr("1 cours était déjà dans ton horaire.") : tr("\(skipped) cours étaient déjà dans ton horaire."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            MiniActionButton(title: tr("Terminé"), symbol: "checkmark", colorHex: accentHex) { dismiss() }
                .accessibilityIdentifier("schedule-import-done")
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule-import-confirmation")
    }

    // MARK: Actions

    /// A photo chosen with the system picker: its data is read, then the image.
    private func readPhoto(_ item: PhotosPickerItem) {
        start {
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return .unreadable }
            return await slotsOrFailure(from: .image(image))
        }
    }

    /// A file chosen in Files: a PDF is read where it is, an image is opened first. The file stays reachable
    /// until the reading is over.
    private func readFile(at url: URL) {
        start {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
                return await slotsOrFailure(from: .pdf(url))
            }
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return .unreadable }
            return await slotsOrFailure(from: .image(image))
        }
    }

    private enum ReadOutcome {
        case found([ImportedSlot])
        case unreadable
        case nothingFound
    }

    private func slotsOrFailure(from source: ScheduleSource) async -> ReadOutcome {
        do {
            let found = try await ScheduleImporter.slots(from: source)
            return found.isEmpty ? .nothingFound : .found(found)
        } catch ScheduleImportError.nothingFound {
            return .nothingFound
        } catch {
            return .unreadable
        }
    }

    /// Runs a reading with the progress shown, then moves to the check or to the message.
    private func start(_ reading: @escaping () async -> ReadOutcome) {
        readTask?.cancel()
        stage = .reading
        readTask = Task { @MainActor in
            let outcome = await reading()
            guard !Task.isCancelled else { return }
            switch outcome {
            case .found(let found):
                // By day, then by hour; the order stays as is while the person edits.
                inheritedDoubt = Set(found.filter { $0.needsCheck && $0.uncertain.isEmpty }.map { $0.id })
                slots = found.sorted { ($0.weekday, $0.startMinute, $0.endMinute) < ($1.weekday, $1.startMinute, $1.endMinute) }
                stage = .review
            case .unreadable:
                stage = .failed(unreadable: true)
            case .nothingFound:
                stage = .failed(unreadable: false)
            }
        }
    }

    /// Adds the ticked classes to the schedule (courses made when missing, nothing erased, no duplicate).
    private func save() {
        let wanted = ScheduleImportMerge.importable(slots).count
        var added = 0
        model.update(\.student) { state in
            let merged = ScheduleImportMerge.merge(slots, into: state)
            state = merged.state
            added = merged.added
        }
        Haptics.success()
        stage = .done(added: added, skipped: max(0, wanted - added))
        // The confirmation is shown a moment, then the sheet closes.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if case .done = stage { dismiss() }
        }
    }
}

/// The look of a field read with a doubt: a soft alert background, a thin outline and a small warning mark in the corner.
/// The structure is the same whether the field is flagged or not (only the colours change), so that a text field keeps
/// its focus while the person types and the mark goes away.
private struct UncertainHighlight: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        let alert = Color(hex: MiniStyle.alertHex)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(shape.fill(alert.opacity(active ? 0.12 : 0)))
            .overlay(shape.stroke(alert.opacity(active ? 0.6 : 0), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(alert)
                    .padding(2)
                    .opacity(active ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .accessibilityHint(active ? tr("À vérifier") : "")
    }
}

private extension View {
    /// Highlights a field of the check screen when its reading is in doubt.
    func uncertainHighlight(_ active: Bool) -> some View {
        modifier(UncertainHighlight(active: active))
    }
}
