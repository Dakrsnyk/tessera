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

    /// 3. The check: the classes found by day, all ticked, each one to correct or to untick.
    private var reviewStep: some View {
        let count = ScheduleImportMerge.importable(slots).count
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("Vérifie ce qui a été lu, corrige si besoin, puis ajoute les cours à ton horaire."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(1...7, id: \.self) { day in
                    if slots.contains(where: { $0.weekday == day }) {
                        VStack(alignment: .leading, spacing: 10) {
                            MiniSectionTitle(title: Studies.weekdayNames[day - 1])
                            ForEach($slots) { $slot in
                                if slot.weekday == day {
                                    slotCard($slot)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 70)
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

    /// One class found: tick, name, day, hours and room.
    private func slotCard(_ slot: Binding<ImportedSlot>) -> some View {
        let value = slot.wrappedValue
        let invalidTime = value.endMinute <= value.startMinute
        return VStack(alignment: .leading, spacing: 8) {
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
                TextField(tr("Titre"), text: slot.title)
                    .font(.body.weight(.semibold))
            }
            if value.isSelected {
                Picker(tr("Jour"), selection: slot.weekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(Studies.weekdayNames[day - 1]).tag(day)
                    }
                }
                MinuteTimePicker(title: tr("Début"), minutes: slot.startMinute)
                MinuteTimePicker(title: tr("Fin"), minutes: slot.endMinute)
                if invalidTime {
                    Label(tr("La fin doit venir après le début."), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: MiniStyle.alertHex))
                }
                TextField(tr("Salle (facultatif)"), text: Binding(get: { slot.room.wrappedValue ?? "" }, set: { slot.room.wrappedValue = $0 }))
                    .font(.subheadline)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .miniCard()
        .opacity(value.isSelected ? 1 : 0.6)
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
