import SwiftUI

/// The edit mode of « Mon Quotidien », the Home screen of iOS way: long press on a card, the cards wiggle,
/// drag one to move it (the others make room), a round « + » or « − » at the top right changes its size.
/// The rules are in `DailyLayoutRules`; this file is the drawing and the gestures.

/// Everything a card can do in edit mode (set by `DailySection`).
struct DailyEditHandlers {
    var grow: () -> Void
    var shrink: () -> Void
    var moveBefore: () -> Void
    var moveAfter: () -> Void
    var remove: () -> Void
    var organize: () -> Void
    /// The long press worked (nil drag) or the finger moves (drag, in the « daily-grid » space).
    var drag: (DragGesture.Value?) -> Void
    var drop: () -> Void
}

/// The frame of every card in the « daily-grid » space (where it is laid out, never where it is drawn
/// while dragged).
struct DailyFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Lays the cards out like the rows of `DailyBrief.rows`: a wide card alone, the others two by two, each
/// row as tall as its tallest card. One flat list of cards (instead of one stack per row) keeps every
/// card the same view while it moves, so the drag goes on and the others slide with an animation.
struct DailyGridLayout: Layout {
    /// For each card, in order: across the whole width (true) or half of it.
    var wides: [Bool]
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 340
        let heights = rowHeights(width: width, subviews: subviews)
        let total = heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = DailyLayoutRules.rows(wides: wides(count: subviews.count))
        let heights = rowHeights(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (rowIndex, row) in rows.enumerated() {
            let width = cellWidth(bounds.width, count: row.count)
            var x = bounds.minX
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: width, height: heights[rowIndex]))
                x += width + spacing
            }
            y += heights[rowIndex] + spacing
        }
    }

    private func wides(count: Int) -> [Bool] {
        (0..<count).map { $0 < wides.count ? wides[$0] : true }
    }

    private func cellWidth(_ total: CGFloat, count: Int) -> CGFloat {
        count > 1 ? (total - spacing) / 2 : total
    }

    private func rowHeights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        DailyLayoutRules.rows(wides: wides(count: subviews.count)).map { row in
            let cell = cellWidth(width, count: row.count)
            return row.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }.max() ?? 0
        }
    }
}

/// A card of Mon Quotidien with its edit mode: the wiggle, the drag, the round buttons and the
/// VoiceOver actions. Outside the edit mode it is the card as it was (a long press starts the mode).
struct DailyEditableCard<Content: View>: View {
    let tile: DailyBrief.Tile
    let title: String
    let editing: Bool
    let isDragging: Bool
    let dragOffset: CGSize
    let canGrow: Bool
    let canShrink: Bool
    let canMoveBefore: Bool
    let canMoveAfter: Bool
    let handlers: DailyEditHandlers
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle = false

    var body: some View {
        ZStack {
            content()
                // Editing: the card is only a thing to move, its buttons and its link do nothing.
                .allowsHitTesting(!editing)
                .overlay { if editing { Color.clear.contentShape(Rectangle()).onTapGesture {} } }
                .overlay(alignment: .topTrailing) { sizeButton }
                .overlay(alignment: .topLeading) { removeButton }
                .rotationEffect(.degrees(shaking ? (wiggle ? 0.9 : -0.9) : 0))
                .animation(shaking ? .easeInOut(duration: 0.12 + Double(tile.id.utf8.count % 5) * 0.012).repeatForever(autoreverses: true) : nil, value: wiggle)
                .scaleEffect(isDragging ? 1.04 : 1)
                .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 14 : 0, y: isDragging ? 8 : 0)
                .offset(isDragging ? dragOffset : .zero)
        }
        // The layout frame of the card, outside the offset: where the others compare the finger to.
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: DailyFramesKey.self, value: [tile.id: proxy.frame(in: .named("daily-grid"))])
            }
        }
        .zIndex(isDragging ? 1 : 0)
        .onChange(of: shaking) { _, on in wiggle = on }
        .onAppear { wiggle = shaking }
        // Outside the edit mode only a plain long press (a tap, a swipe of the card's pages and the scroll of Home
        // work exactly as before); in the edit mode, hold then drag moves the card.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in handlers.drag(nil) },
            including: editing ? .none : .all
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("daily-grid")))
                .onChanged { value in
                    if case .second(true, let drag) = value { handlers.drag(drag) }
                }
                .onEnded { _ in handlers.drop() },
            including: editing ? .all : .none
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(tr("Retirer de Mon Quotidien"))) { handlers.remove() }
        .modifier(DailyMoveActions(canGrow: canGrow, canShrink: canShrink, canBefore: canMoveBefore, canAfter: canMoveAfter,
                                   handlers: handlers, editing: editing))
    }

    private var shaking: Bool { editing && !isDragging && !reduceMotion }

    /// « + » for a card that can be wider, « − » for one that can be narrower; none when it has one size.
    @ViewBuilder private var sizeButton: some View {
        if editing, canGrow || canShrink {
            Button {
                if canGrow { handlers.grow() } else { handlers.shrink() }
            } label: {
                pastille(canGrow ? "plus" : "minus")
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel(Text(canGrow ? tr("Agrandir \(title)") : tr("Rétrécir \(title)")))
            .accessibilityIdentifier("daily-\(canGrow ? "grow" : "shrink")-\(tile.id)")
        }
    }

    /// The small cross at the top left, like the « − » of the Home screen: takes the card off.
    @ViewBuilder private var removeButton: some View {
        if editing {
            Button(action: handlers.remove) {
                pastille("xmark", fill: Color(.systemGray))
            }
            .buttonStyle(.plain)
            .offset(x: -6, y: -6)
            .accessibilityLabel(Text(tr("Retirer \(title) de Mon Quotidien")))
            .accessibilityIdentifier("daily-remove-\(tile.id)")
        }
    }

    /// A round button 26 points wide in a 44-point touch area.
    private func pastille(_ symbol: String, fill: Color = .accentColor) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

/// The VoiceOver actions of a card: move before or after, enlarge or shrink (only those that apply), and
/// « Organiser… » outside the edit mode.
private struct DailyMoveActions: ViewModifier {
    let canGrow: Bool
    let canShrink: Bool
    let canBefore: Bool
    let canAfter: Bool
    let handlers: DailyEditHandlers
    let editing: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text(tr("Déplacer avant"))) { if canBefore { handlers.moveBefore() } }
            .accessibilityAction(named: Text(tr("Déplacer après"))) { if canAfter { handlers.moveAfter() } }
            .accessibilityAction(named: Text(tr("Agrandir"))) { if canGrow { handlers.grow() } }
            .accessibilityAction(named: Text(tr("Rétrécir"))) { if canShrink { handlers.shrink() } }
            .accessibilityAction(named: Text(tr("Organiser…"))) { if !editing { handlers.organize() } }
    }
}
