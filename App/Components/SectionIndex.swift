import SwiftUI

// MARK: - Filing

/// Names filed under the letters of an index, like Contacts: the first letter without accent or case
/// (« Élévation » goes under E), a Japanese kana under its row (« スクワット » under さ), anything else
/// (a digit, a symbol, a kanji) under « # ».
enum SectionIndex {
    static let latin = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) }
    /// The rows of the kana syllabary, the way Japanese indexes start.
    static let kana = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]
    static let other = "#"

    /// Letters with no accent to drop that still read as a Latin letter.
    private static let ligatures = ["œ": "O", "æ": "A", "ß": "S", "ø": "O", "ł": "L", "đ": "D", "ð": "D", "þ": "T", "ı": "I"]

    /// The hiragana of each kana row (katakana are moved to the hiragana block first). Voiced kana
    /// (が, ば, ぱ) lose their mark when decomposed, so they fall in the row of their plain kana.
    private static let kanaRows: [(range: ClosedRange<UInt32>, row: String)] = [
        (0x3041...0x304A, "あ"), (0x304B...0x3054, "か"), (0x3055...0x305E, "さ"), (0x305F...0x3069, "た"),
        (0x306A...0x306E, "な"), (0x306F...0x307D, "は"), (0x307E...0x3082, "ま"), (0x3083...0x3088, "や"),
        (0x3089...0x308D, "ら"), (0x308E...0x3093, "わ"), (0x3094...0x3094, "あ"), (0x3095...0x3096, "か"),
    ]

    /// The letter a name is filed under.
    static func letter(for name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return other }
        if let letter = ligatures[String(first).lowercased()] { return letter }
        // « É » decomposes into « E » and its accent, « ベ » into « ヘ » and its mark: the base comes first.
        guard var value = String(first).decomposedStringWithCanonicalMapping.unicodeScalars.first?.value else { return other }
        switch value {
        case 0x41...0x5A: return latin[Int(value - 0x41)]
        case 0x61...0x7A: return latin[Int(value - 0x61)]
        case 0xFF21...0xFF3A: return latin[Int(value - 0xFF21)]  // full-width capitals
        case 0xFF41...0xFF5A: return latin[Int(value - 0xFF41)]  // full-width small letters
        case 0x30A1...0x30F6: value -= 0x60  // katakana → the same hiragana
        default: break
        }
        return kanaRows.first { $0.range.contains(value) }?.row ?? other
    }

    /// The letters of the index, top to bottom: the kana rows (in Japanese, or when a name is filed
    /// under one), A to Z, then « # ».
    static func letters(for used: Set<String>, locale: Locale = Fmt.locale) -> [String] {
        let showsKana = locale.language.languageCode?.identifier == "ja" || !used.isDisjoint(with: kana)
        return (showsKana ? kana : []) + latin + [other]
    }

    /// The items under their letter, in the order of the index; within a letter, sorted for the
    /// language (accents and case ignored, numbers in their natural order).
    static func sections<Item>(_ items: [Item], locale: Locale = Fmt.locale, name: (Item) -> String) -> [IndexedSection<Item>] {
        let filed = items.map { item -> (letter: String, name: String, item: Item) in
            let text = name(item)
            return (SectionIndex.letter(for: text), text, item)
        }
        let used = Set(filed.map { $0.letter })
        return letters(for: used, locale: locale).compactMap { key -> IndexedSection<Item>? in
            let names = filed.filter { $0.letter == key }.sorted {
                $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric], locale: locale) == .orderedAscending
            }
            return names.isEmpty ? nil : IndexedSection(letter: key, items: names.map { $0.item })
        }
    }
}

/// Items filed under one letter of an index.
struct IndexedSection<Item>: Identifiable {
    let letter: String
    let items: [Item]
    var id: String { letter }
}

// MARK: - Index bar

/// The index along the edge of a list, top to bottom, like the one of Contacts: touching or sliding
/// along it jumps to a letter with a light tap; letters without items are dimmed (touching one goes to
/// the next letter that has some). When the screen is too short, letters alternate with dots and the
/// slide still reaches each one. VoiceOver moves through it letter by letter (swipe up or down).
struct SectionIndexBar: View {
    let letters: [String]
    let available: Set<String>
    var colorHex = "F08A24"
    let onSelect: (String) -> Void

    /// The width the bar takes along the edge.
    static let width: CGFloat = 22
    private static let rowHeight: CGFloat = 15

    /// The letter reached by the current touch, so each letter fires once per slide.
    @State private var dragged: String?
    /// The last letter reached, read by VoiceOver.
    @State private var selected: String?
    @GestureState private var isTouching = false

    private var accent: Color { Color(hex: colorHex) }

    var body: some View {
        GeometryReader { geometry in
            let shown = visibleMarks(fitting: Int(geometry.size.height / Self.rowHeight))
            let height = CGFloat(shown.count) * Self.rowHeight
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, mark in
                    markView(mark)
                }
            }
            .frame(width: Self.width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouching) { _, touching, _ in touching = true }
                    .onChanged { value in touch(at: value.location.y, height: height) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.width)
        .onChange(of: isTouching) { _, touching in
            if !touching { dragged = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tr("Index alphabétique")))
        .accessibilityValue(Text(selected ?? ""))
        .accessibilityAdjustableAction { direction in
            adjust(direction)
        }
        .accessibilityIdentifier("section-index")
    }

    /// A letter, or a dot (nil) standing for the letters left out when they do not all fit.
    @ViewBuilder
    private func markView(_ mark: String?) -> some View {
        if let mark {
            let isActive = isTouching && mark == dragged
            Text(mark)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive ? Color.white : (available.contains(mark) ? accent : Color.secondary.opacity(0.35)))
                .frame(width: 18, height: 18)
                .background(isActive ? accent : Color.clear, in: Circle())
                .frame(width: Self.width, height: Self.rowHeight)
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
                .frame(width: Self.width, height: Self.rowHeight)
        }
    }

    /// Every letter when they fit; otherwise letters spread from the first to the last with a dot
    /// between each two.
    private func visibleMarks(fitting rows: Int) -> [String?] {
        guard rows > 0, !letters.isEmpty else { return [] }
        guard rows < letters.count, letters.count > 2 else { return letters }
        let kept = (max(3, rows % 2 == 0 ? rows - 1 : rows) + 1) / 2
        var marks: [String?] = []
        for slot in 0..<kept {
            let index = Int((Double(slot) * Double(letters.count - 1) / Double(kept - 1)).rounded())
            if slot > 0 { marks.append(nil) }
            marks.append(letters[index])
        }
        return marks
    }

    /// The finger's height along the bar, spread over every letter (dots included).
    private func touch(at y: CGFloat, height: CGFloat) {
        guard height > 0, !letters.isEmpty else { return }
        let index = min(letters.count - 1, max(0, Int(y / height * CGFloat(letters.count))))
        guard let target = reachableLetter(from: index), target != dragged else { return }
        dragged = target
        selected = target
        Haptics.tap()
        onSelect(target)
    }

    /// The letter there if it has items, else the next one that has, else the last one before it.
    private func reachableLetter(from index: Int) -> String? {
        letters[index...].first { available.contains($0) } ?? letters[..<index].last { available.contains($0) }
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        let order = letters.filter { available.contains($0) }
        guard !order.isEmpty else { return }
        let step: Int
        switch direction {
        case .increment: step = 1
        default: step = -1
        }
        let next: Int
        if let current = selected.flatMap({ order.firstIndex(of: $0) }) {
            next = min(order.count - 1, max(0, current + step))
        } else {
            next = step > 0 ? 0 : order.count - 1
        }
        selected = order[next]
        onSelect(order[next])
    }
}
