import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

// Direction 5 « Hybride » of « Photos et citations »: the pieces the page and the workshop (the editor) are made of.

/// The chapters of the workshop: what is written, how it is laid out, how it looks (a photo widget has no « Style »).
enum PhotoChapter: String, CaseIterable, Identifiable {
    case content, layout, style
    var id: String { rawValue }

    var title: String {
        switch self {
        case .content: tr("Contenu")
        case .layout: tr("Disposition")
        case .style: tr("Style")
        }
    }

    static func chapters(for kind: WidgetKind) -> [PhotoChapter] {
        kind == .quote ? [.content, .layout, .style] : [.content, .layout]
    }
}

/// What « Un par jour » says about a widget on a date, for the page and the workshop.
enum PhotoDailyText {
    /// « Jour 12 sur 365 ».
    static func day(_ position: DailyRotation.Position) -> String {
        tr("Jour \(position.day) sur \(position.total)")
    }

    /// What a widget shows on a date: the start of its text, or « photo 5 sur 7 ».
    static func shown(_ design: WidgetDesign, _ position: DailyRotation.Position) -> String {
        if design.kind == .quote, let text = design.options.quote?.texts?[safe: position.index] { return text }
        return tr("photo \(position.index + 1) sur \(position.total)")
    }
}

// MARK: Page

/// One widget of the gallery: the widget as it is placed, its name and what it is, and the « … » menu with the
/// actions « Mes widgets » has for it.
struct PhotoWidgetTile: View {
    let design: WidgetDesign
    let isFavorite: Bool
    let edit: () -> Void
    let duplicate: () -> Void
    let makeVariant: () -> Void
    let toggleFavorite: () -> Void
    let place: () -> Void
    let delete: () -> Void

    var body: some View {
        let format = design.format ?? .small
        VStack(alignment: .leading, spacing: 6) {
            Button(action: edit) {
                WidgetPreview(design: design, family: format.family, payload: WidgetPayload())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(design.name))
            .accessibilityIdentifier("photos-widget")
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(design.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(design.kind.title) · \(format.title)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let position = design.dailyPosition(on: Date()) {
                        Text("\(tr("Un par jour")) · \(PhotoDailyText.day(position))")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Menu {
                    Button(action: edit) { Label(tr("Modifier"), systemImage: "slider.horizontal.3") }
                    Button(action: duplicate) { Label(tr("Dupliquer"), systemImage: "plus.square.on.square") }
                    Button(action: makeVariant) { Label(tr("Créer une variante"), systemImage: "wand.and.stars") }
                    Button(action: toggleFavorite) {
                        Label(isFavorite ? tr("Retirer des favoris") : tr("Favori"), systemImage: isFavorite ? "heart.slash" : "heart")
                    }
                    Button(action: place) { Label(tr("Ajouter à l'écran"), systemImage: "apps.iphone.badge.plus") }
                    Divider()
                    Button(role: .destructive, action: delete) { Label(tr("Supprimer"), systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Actions du widget")))
                .accessibilityIdentifier("photos-widget-menu")
            }
        }
    }
}

// MARK: Workshop

/// The four automatic layouts of a photo widget (one to four photos), the one the widget has now ringed.
struct PhotoLayoutChoices: View {
    let family: WidgetFamily
    let count: Int
    let strong: Color

    var body: some View {
        let current = min(PhotoLayout.capacity, max(1, count))
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(1...PhotoLayout.capacity, id: \.self) { n in
                let isOn = n == current
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            ForEach(Array(PhotoLayout.cells(count: n, family: family).enumerated()), id: \.offset) { _, cell in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isOn ? strong.opacity(0.45) : Color.secondary.opacity(0.35))
                                    .frame(width: max(1, cell.width * geo.size.width - 2), height: max(1, cell.height * geo.size.height - 2))
                                    .offset(x: cell.minX * geo.size.width + 1, y: cell.minY * geo.size.height + 1)
                            }
                        }
                    }
                    .frame(width: 62, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isOn ? strong : Color.secondary.opacity(0.4), lineWidth: isOn ? 2 : 1.5)
                    }
                    Text(Fmt.plural(n, tr("photo"), tr("photos")))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isOn ? strong : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// « Un par jour »: the order (in the list's order, or shuffled once), the first day, and what the widget shows
/// today and tomorrow. It changes at midnight.
struct PhotoDailyBlock: View {
    @Binding var design: WidgetDesign
    let strong: Color

    private var rotation: Binding<DailyRotation> {
        Binding(get: { design.options.daily ?? DailyRotation(startDay: Date()) }, set: { design.options.daily = $0 })
    }

    private var startDay: Binding<Date> {
        Binding(
            get: { rotation.wrappedValue.startDay },
            set: { day in
                var value = rotation.wrappedValue
                value.startDay = DateMath.startOfDay(day)
                rotation.wrappedValue = value
            }
        )
    }

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 12) {
            Picker(tr("Ordre"), selection: rotation.order) {
                ForEach(DailyOrder.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("photos-daily-order")
            DatePicker(tr("Premier jour"), selection: startDay, displayedComponents: .date)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Change à minuit"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                if let position = design.dailyPosition(on: now) {
                    Text("\(tr("Aujourd'hui")) : \(PhotoDailyText.day(position))")
                        .font(.headline)
                        .monospacedDigit()
                    if !rotation.wrappedValue.hasStarted(on: now) {
                        Text(tr("Commence le \(Fmt.longDay(rotation.wrappedValue.startDay))"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let next = design.dailyPosition(on: DateMath.nextMidnight(after: now)) {
                        Text("\(tr("Demain")) : \(PhotoDailyText.shown(design, next))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cristalPanel(radius: 14)
            .accessibilityIdentifier("photos-daily-today")
        }
        .tint(strong)
    }
}

/// The background colors of the Studio (its free accents and its flat backgrounds), for the quote's « Fond ».
/// The Studio's Premium ones carry a lock; touching one without Premium is the caller's to answer.
struct QuoteBackgroundSwatches: View {
    let selectedHex: String
    let isPremium: Bool
    let strong: Color
    let pick: (AccentSwatch, Bool) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(Palette.freeAccents + Palette.backgrounds) { swatch in
                let isLocked = !isPremium && Palette.backgrounds.contains(swatch)
                let isOn = selectedHex.uppercased() == swatch.hex.uppercased()
                Button {
                    pick(swatch, isLocked)
                } label: {
                    Circle()
                        .fill(Color(hex: swatch.hex))
                        .frame(width: 34, height: 34)
                        .overlay { Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1) }
                        .overlay {
                            if isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.premiumInk)
                                    .padding(4)
                                    .background(Color.premiumFill, in: Circle())
                            }
                        }
                        .padding(3)
                        .overlay { Circle().strokeBorder(isOn ? strong : .clear, lineWidth: 2.5) }
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(swatch.name))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

// MARK: « Mes textes »

/// « Mes textes »: paste or open a text file, cut it into texts (one per line or per paragraph), see how many
/// there are, say which day the first one is shown. The app names and sorts nothing.
struct QuoteTextsImportView: View {
    /// The texts and the day the first one is shown.
    let onImport: ([String], Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var style
    @State private var fromFile = false
    @State private var raw = ""
    @State private var split: TextImport.Split = .line
    @State private var startsToday = true
    @State private var chosenDay = Date()
    @State private var picksFile = false
    @State private var fileName: String?
    @State private var fileFailed = false
    /// The texts found, worked out when the source or the split changes (not at every redraw: a file can be long).
    @State private var parsedTexts: TextImport.Result?

    private var strong: Color { style.cristal.strong(MiniApp.photos.colorHex) }
    private var startDay: Date { startsToday ? DateMath.startOfDay(Date()) : DateMath.startOfDay(chosenDay) }

    var body: some View {
        let parsed = parsedTexts ?? TextImport.parse("", by: split)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker(tr("Source"), selection: $fromFile) {
                        Text(tr("Coller")).tag(false)
                        Text(tr("Fichier")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("texts-source")
                    if fromFile { fileSection } else { pasteSection }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("Un texte par")).font(.subheadline.weight(.semibold))
                        Picker(tr("Un texte par"), selection: $split) {
                            ForEach(TextImport.Split.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("texts-split")
                    }
                    preview(parsed)
                    startSection(count: parsed.texts.count)
                    Button {
                        onImport(parsed.texts, startDay)
                        dismiss()
                    } label: {
                        Text(tr("Importer \(Fmt.plural(parsed.texts.count, tr("texte"), tr("textes")))"))
                            .font(.headline)
                            .foregroundStyle(style.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(strong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .opacity(parsed.texts.isEmpty ? 0.4 : 1)
                    }
                    .buttonStyle(.pressable)
                    .disabled(parsed.texts.isEmpty)
                    .accessibilityIdentifier("texts-import")
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .cristalScreen()
            .navigationTitle(tr("Mes textes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
            }
            .fileImporter(isPresented: $picksFile, allowedContentTypes: [.plainText, .text]) { result in
                guard case let .success(url) = result else { return }
                read(url)
            }
            .onChange(of: raw, initial: true) { _, text in parsedTexts = TextImport.parse(text, by: split) }
            .onChange(of: split) { _, by in parsedTexts = TextImport.parse(raw, by: by) }
        }
    }

    private var pasteSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $raw)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 170)
                .padding(8)
                .cristalPanel(radius: 14)
                .accessibilityIdentifier("texts-editor")
            if raw.isEmpty {
                Text(tr("Colle tes textes ici, un par ligne ou par paragraphe."))
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                picksFile = true
            } label: {
                Label(tr("Choisir un fichier texte"), systemImage: "doc.text")
                    .font(.headline)
                    .foregroundStyle(strong)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(strong.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("texts-file")
            if let fileName {
                Label(fileName, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if fileFailed {
                Label(tr("Ce fichier n'a pas pu être lu (texte simple, 2 Mo au plus)."), systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func preview(_ parsed: TextImport.Result) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parsed.texts.isEmpty
                 ? tr("Aucun texte trouvé")
                 : Fmt.plural(parsed.texts.count, tr("texte trouvé"), tr("textes trouvés")))
                .font(.headline)
            ForEach(Array(parsed.texts.prefix(3).enumerated()), id: \.offset) { index, text in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 22, alignment: .leading)
                    Text(text)
                        .font(.subheadline)
                        .lineLimit(2)
                }
            }
            if parsed.cut > 0 {
                Text(Fmt.plural(parsed.cut, tr("texte coupé à 280 caractères"), tr("textes coupés à 280 caractères")))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if parsed.left > 0 {
                Text(tr("\(parsed.left) textes en trop ont été laissés : un widget en garde 2 000 au plus."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristalPanel(radius: 16)
        .accessibilityIdentifier("texts-preview")
    }

    private func startSection(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Commencer")).font(.subheadline.weight(.semibold))
            Picker(tr("Commencer"), selection: $startsToday) {
                Text(tr("Aujourd'hui")).tag(true)
                Text(tr("Choisir le jour")).tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("texts-start")
            if !startsToday {
                DatePicker(tr("Premier texte le"), selection: $chosenDay, displayedComponents: .date)
                    .font(.subheadline)
            }
            if count > 0, let position = DailyRotation(order: .inOrder, startDay: startDay).position(count: count, on: Date()) {
                let started = DateMath.daysBetween(startDay, Date()) >= 0
                Text(started
                     ? tr("Aujourd'hui, \(Fmt.longDay(Date())) : texte \(position.day) sur \(position.total).")
                     : tr("Le premier texte s'affiche le \(Fmt.longDay(startDay))."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(strong)
    }

    /// Reads a text file (UTF-8, else Latin-1), refusing one over 2 Mo.
    private func read(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > TextImport.maxFileBytes {
            fileFailed = true
            return
        }
        guard let data = try? Data(contentsOf: url), data.count <= TextImport.maxFileBytes,
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            fileFailed = true
            return
        }
        raw = text
        fileName = url.lastPathComponent
        fileFailed = false
    }
}
