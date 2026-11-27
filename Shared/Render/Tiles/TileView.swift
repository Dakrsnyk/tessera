import AppIntents
import SwiftUI
import WidgetKit

/// Lays out a `Tile` for every widget size, with the design's theme, colors, font and Studio settings.
/// "Auto" keeps each widget's own arrangement; the other layouts rearrange the same content.
struct TileView: View {
    let tile: Tile
    let context: RenderContext

    init(tile: Tile, context: RenderContext) {
        // The parts the person hid are gone before anything is laid out.
        var shown = context.style.filtered(tile)
        // The lines of a money widget hold amounts: they are hidden too while the iPhone is locked.
        if shown.isSensitive {
            shown.rows = shown.rows.map { row in
                var copy = row
                copy.isSensitive = true
                return copy
            }
            shown.lockColumns = shown.lockColumns.map { row in
                var copy = row
                copy.isSensitive = true
                return copy
            }
        }
        self.tile = shown
        self.context = context
    }

    private var s: ResolvedStyle { context.style }
    private var sp: CGFloat { s.spacing }

    var body: some View {
        if let empty = tile.empty {
            WidgetMessage(symbol: empty.symbol, title: empty.title, message: context.isSmall ? nil : empty.message, style: s)
        } else {
            switch effectiveLayout {
            case .auto:
                if context.isLarge {
                    large
                } else if context.isMedium {
                    medium
                } else {
                    small
                }
            case .vertical: verticalLayout
            case .horizontal: horizontalLayout
            case .minimal: besideLines(minimalLayout)
            case .centered: besideLines(centeredLayout)
            case .split: splitLayout
            case .data: dataLayout
            case .list: listLayout
            case .progress: progressLayout
            case .graph: graphLayout
            case .cards: cardsLayout
            }
        }
    }

    /// The chosen layout, or the closest one that has what it needs (checked on every widget in each layout,
    /// 2026-11-26): a widget with buttons keeps them (a counter without « +1 » is useless), a widget of words (an AI
    /// summary, a note) is never left with its title alone, and two columns never squeeze a small widget.
    private var effectiveLayout: LayoutKind {
        let layout = s.options.layout
        let hasButtons = !tile.buttons.isEmpty
        switch layout {
        // One progress only: several lines (three companies) reduced to one bar read « 100 % » and meant nothing.
        case .progress: return (tile.visual.progressValue ?? (tile.rows.count == 1 ? tile.rows[0].progress : nil)) == nil ? .vertical : .progress
        // A bar alone (a set, a rest) makes no graph: half the widget stayed empty.
        case .graph:
            let drawable = (hasVisual && !isBarOnly) || !tile.rows.isEmpty
            return drawable && !(!context.isLarge && hasButtons) ? .graph : .vertical
        case .list: return tile.rows.isEmpty ? .vertical : .list
        case .split: return context.isSmall || (tile.rows.isEmpty && !hasVisual) ? .vertical : .split
        case .data: return stats.count < 2 || tile.timer != nil || (context.isSmall && hasButtons) ? .vertical : .data
        case .cards: return !hasValue || tile.timer != nil || (!context.isLarge && hasButtons) ? .vertical : .cards
        case .centered, .minimal: return !hasValue || (!context.isLarge && hasButtons) ? .vertical : layout
        case .horizontal: return context.isSmall && hasButtons ? .vertical : .horizontal
        default: return layout
        }
    }

    private var isBarOnly: Bool {
        if case .bar = tile.visual { return true }
        return false
    }

    /// The person picked a chart: it is shown where the widget would otherwise show its lines.
    private var prefersChosenChart: Bool {
        s.options.chart != .auto && hasVisual && ChartKind.options(for: tile.visual.chartFamily).contains(s.options.chart)
    }

    /// Round charts need more room than a strip.
    private var chosenChartIsRound: Bool {
        prefersChosenChart && [.ring, .pie, .gauge].contains(s.options.chart)
    }

    // MARK: Pieces

    private var showsIcon: Bool { !s.options.isHidden("icon") && s.iconStyle != .none }

    @ViewBuilder private var header: some View {
        // A link (the Nutrition scanner) only where iOS allows links; an action (« Commencer » of « Séance du jour ») in every size.
        let button = tile.headerButton.flatMap { $0.action == .scanFood && !context.allowsLinks ? nil : $0 }
        if s.showsTitle || button != nil {
            HStack(spacing: 5) {
                if s.showsTitle {
                    if showsIcon && s.options.iconPosition == .leading {
                        StyledIcon(symbol: tile.symbol, style: s)
                    }
                    WLabel(text: tile.title, style: s)
                }
                Spacer(minLength: 0)
                if s.showsTitle && showsIcon && s.options.iconPosition == .trailing {
                    StyledIcon(symbol: tile.symbol, style: s)
                }
                if let button {
                    TileActionButton(action: button.action, isEnabled: context.isInteractive) {
                        TileHeaderButtonLabel(button: button, style: s, iconOnly: context.isSmall)
                    }
                }
            }
        }
    }

    /// The icon above the title, when the person placed it on top.
    @ViewBuilder private var topIcon: some View {
        if s.showsTitle && showsIcon && s.options.iconPosition == .top {
            StyledIcon(symbol: tile.symbol, style: s, size: 15)
        }
    }

    @ViewBuilder private var headerBlock: some View {
        VStack(alignment: s.horizontalAlignment, spacing: 4 * sp) {
            topIcon
            header
        }
    }

    private var valueColor: Color {
        switch tile.trend {
        case .some(true): s.positive
        case .some(false): s.negative
        case .none: s.numberColor
        }
    }

    /// The space between a figure and its unit: a hard or long shadow of the figure would otherwise cover the unit.
    private var unitGap: CGFloat {
        switch s.options.depth {
        case .hardShadow: 3 + max(2, CGFloat(s.options.shadowOffset))
        case .longShadow: 10
        case .strong, .floating: 5
        default: 3
        }
    }

    /// Lines for the caption of a widget of words only (an AI sentence has no figure): the sentence takes the room.
    private func wordsLines(_ normal: Int) -> Int {
        hasValue ? normal : (context.isSmall ? 5 : (context.isLarge ? 8 : 3))
    }

    @ViewBuilder private func valueText(_ size: CGFloat, showsUnit: Bool = true) -> some View {
        Group {
            if let timer = tile.timer {
                Text(timerInterval: timer, countsDown: true)
                    .font(s.number(size))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(s.textAlignment)
            } else {
                // Words rather than a figure (a revision card, a session's name): up to three lines a little smaller,
                // not one line cut after two letters (« Ce »).
                let isWords = valueIsWords
                HStack(alignment: .firstTextBaseline, spacing: unitGap) {
                    Text(tile.value)
                        .font(s.number(isWords ? size * 0.72 : size))
                        .foregroundStyle(valueColor)
                        .lineLimit(isWords ? 3 : 1)
                        .minimumScaleFactor(isWords ? 0.7 : 0.45)
                    if showsUnit, let unit = tile.unit {
                        Text(unit)
                            .font(s.text(max(11, size * 0.38), .medium))
                            .foregroundStyle(s.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .styleDepth(s)
        .widgetAccentable()
        .privacySensitive(tile.isSensitive)
    }

    @ViewBuilder private func captionText(lines: Int) -> some View {
        if let caption = tile.caption {
            Text(caption)
                .font(s.text(12))
                .foregroundStyle(s.secondary)
                .lineLimit(lines)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(s.textAlignment)
                // The sign already says it: VoiceOver doesn't read the arrow's name before the figure.
                .accessibilityLabel(Text(caption.replacingOccurrences(of: "▲ ", with: "").replacingOccurrences(of: "▼ ", with: "")))
                .privacySensitive(tile.isSensitive)
        }
    }

    @ViewBuilder private var detailText: some View {
        if let detail = tile.detail, s.showsDetails {
            Text(detail)
                .font(s.text(11, .medium))
                .foregroundStyle(s.secondary)
                .lineLimit(2)
                .privacySensitive(tile.isSensitive)
        }
    }

    @ViewBuilder private var footnoteText: some View {
        if let footnote = tile.footnote {
            Text(footnote)
                .font(s.text(9))
                .foregroundStyle(s.secondary.opacity(0.8))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
    }

    /// The note at the bottom, in large; in medium too for a price that moves (« Cours de 14:05 »).
    private var showsFootnote: Bool {
        context.isLarge || (context.isMedium && LivePrices.follows(context.design.kind))
    }

    private var isRing: Bool {
        if case .ring = tile.visual { return true }
        return false
    }

    private var isSegments: Bool {
        if case .segments = tile.visual { return true }
        return false
    }

    private var isTimer: Bool {
        if case .timer = tile.visual { return true }
        return false
    }

    /// The week's schedule fills the height the widget leaves (no empty half below it); the other charts keep their own.
    private var fillsHeight: Bool { tile.visual.isSchedule }

    /// A month of dots or a habits × days grid: drawn in the height left (a strip of 30 points made them specks).
    private var growsInRoom: Bool {
        switch tile.visual {
        case .month, .grid, .week: true
        default: false
        }
    }

    /// A chart only where it can be read: in a small widget, a jagged curve without a single label says nothing, and a
    /// part bar whose lines are shown instead has them as its legend (PDG, 2026-11-27). It is simply not drawn.
    private var hasVisual: Bool {
        switch tile.visual {
        case .none: return false
        case let .line(values): return !(context.isSmall && Self.isJagged(values))
        case .segments: return !(context.isSmall && !tile.rows.isEmpty)
        default: return true
        }
    }

    /// More than half of the points turn around: a saw tooth.
    private static func isJagged(_ values: [Double]) -> Bool {
        guard values.count >= 6 else { return false }
        var turns = 0
        for index in 1..<(values.count - 1) where (values[index] - values[index - 1]) * (values[index + 1] - values[index]) < 0 {
            turns += 1
        }
        return turns * 2 > values.count - 2
    }

    /// The parts bar of a widget that also has its lines (Macros): the lines are its legend, with the amounts.
    private var segmentsWithRows: Bool {
        isSegments && !tile.rows.isEmpty && s.options.chart == .auto
    }

    private var valueIsWords: Bool {
        tile.value.count > 6 && tile.value.contains(" ") && !(tile.value.first?.isNumber ?? false)
    }

    // MARK: Room (estimates fixed by size, never measured: ViewThatFits and measuring froze the app)

    /// The height a widget really holds below its insets, by size (smallest usual iPhone, so nothing is cut there).
    private var room: CGFloat { context.isLarge ? 296 : 118 }

    private var headerCost: CGFloat {
        (s.showsTitle || tile.headerButton != nil ? 17 : 0) + (s.showsTitle && showsIcon && s.options.iconPosition == .top ? 19 : 0)
    }

    private func valueCost(_ size: CGFloat) -> CGFloat {
        guard hasValue else { return 0 }
        return size * (valueIsWords ? 0.72 * 1.2 * CGFloat(min(3, max(1, (tile.value.count + 11) / 12))) : 1.2)
    }

    private func captionCost(_ lines: Int) -> CGFloat {
        guard let caption = tile.caption else { return 0 }
        let perLine = context.isLarge ? 48 : (context.isSmall ? 20 : 24)
        return CGFloat(min(lines, max(1, (caption.count + perLine - 1) / perLine))) * 15
    }

    private var detailCost: CGFloat {
        guard let detail = tile.detail, s.showsDetails else { return 0 }
        return detail.count > 28 ? 28 : 14
    }

    private var footnoteCost: CGFloat { showsFootnote && tile.footnote != nil ? 24 : 0 }
    private var buttonsCost: CGFloat { tile.buttons.isEmpty ? 0 : 38 }

    private func rowCost(_ row: TileRow, compact: Bool) -> CGFloat {
        (compact ? 15 : 16)
            + (row.progress != nil ? (compact ? 6 : 7) : 0)
            + (!compact && s.showsDetails && row.detail != nil ? 12 : 0)
    }

    /// The first `limit` lines that fit in what is left under `used` points of the widget: never a line cut at the bottom.
    private func fitted(_ limit: Int, compact: Bool, used: CGFloat, from source: [TileRow]? = nil) -> [TileRow] {
        let gap = (compact ? 5 : 7) * sp
        var left = room - used
        var result: [TileRow] = []
        for row in (source ?? tile.rows).prefix(max(0, limit)) {
            let cost = rowCost(row, compact: compact) + (result.isEmpty ? 0 : gap)
            guard cost <= left else { break }
            left -= cost
            result.append(row)
        }
        return result
    }

    /// The height of a small chart in a widget that gives it a strip: the days under bars, the names under parts.
    private func stripHeight(_ standard: CGFloat) -> CGFloat {
        if chosenChartIsRound { return 64 }
        if isRing { return 44 }
        if isSegments { return 36 }
        if case let .bars(_, labels, _) = tile.visual, !labels.isEmpty { return max(standard, 38) }
        return standard
    }

    private var hasValue: Bool {
        !tile.value.isEmpty || tile.timer != nil
    }

    /// How far along the widget is, from its ring, its bar or its first line with a progress.
    private var progressFraction: Double? {
        tile.visual.progressValue ?? tile.rows.first(where: { $0.progress != nil })?.progress
    }

    private func rows(_ limit: Int) -> [TileRow] {
        Array(tile.rows.prefix(max(0, limit + s.rowDelta)))
    }

    private func visual(compact: Bool, namedByRows: Bool = false) -> some View {
        // The values written on a chart (end value, change, bar values) are amounts on money widgets.
        TileVisualView(visual: tile.visual, context: context, compact: compact, ringHex: tile.ringHex, namedByRows: namedByRows)
            .privacySensitive(tile.isSensitive)
            .styleDepth(s)
    }

    /// A card inside the widget, with the shape and depth of the style.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(8 * sp)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(s.panel, in: RoundedRectangle(cornerRadius: s.blockRadius(12), style: .continuous))
            .styleDepth(s)
    }

    @ViewBuilder private func buttonsRow(_ limit: Int) -> some View {
        if !tile.buttons.isEmpty {
            TileButtonsRow(buttons: Array(tile.buttons.prefix(limit)), context: context)
        }
    }

    // MARK: Auto: small

    @ViewBuilder private var small: some View {
        if isRing, case let .ring(progress) = tile.visual, s.options.chart == .auto {
            VStack(spacing: 6 * sp) {
                headerBlock
                Spacer(minLength: 0)
                ZStack {
                    RingView(progress: progress, lineWidth: 9 * CGFloat(s.options.chartThickness), color: s.chartColor(default: tile.ringHex), track: s.options.chartFill ? s.track : .clear)
                        .styleDepth(s)
                    VStack(spacing: 0) {
                        valueText(24, showsUnit: false)
                        if let unit = tile.unit, tile.timer == nil {
                            Text(unit).font(s.text(10, .medium)).foregroundStyle(s.secondary).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(width: 88, height: 88)
                if let caption = tile.caption {
                    Text(caption)
                        .font(s.text(11))
                        .foregroundStyle(s.secondary)
                        .lineLimit(2)
                        .privacySensitive(tile.isSensitive)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tile.compactRows && !tile.rows.isEmpty && !prefersChosenChart {
            VStack(alignment: .leading, spacing: 6 * sp) {
                headerBlock
                TileRowsView(rows: fitted(4 + s.rowDelta, compact: true, used: headerCost + 6 * sp), context: context, compact: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if !tile.rows.isEmpty && tile.buttons.isEmpty && !hasVisual {
            // The figure under the title, then its first lines in the room left (« Bras », then the session's
            // exercises), not a figure at the bottom under an empty middle (PDG, 2026-11-27).
            VStack(alignment: .leading, spacing: 3 * sp) {
                headerBlock
                if hasValue { valueText(tile.value.count > 7 ? 22 : 28) }
                captionText(lines: 1)
                TileRowsView(rows: fitted(2 + s.rowDelta, compact: true,
                                          used: headerCost + valueCost(tile.value.count > 7 ? 22 : 28) + captionCost(1) + 13 * sp + 4),
                             context: context, compact: true)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: s.horizontalAlignment, spacing: 3 * sp) {
                headerBlock
                Spacer(minLength: 2)
                if hasValue {
                    valueText(tile.value.count > 7 ? 26 : 34)
                }
                captionText(lines: hasValue ? (tile.buttons.isEmpty && !hasVisual ? 3 : 2) : 5)
                if !tile.buttons.isEmpty {
                    TileButtonsRow(buttons: Array(tile.buttons.prefix(2)), context: context)
                        .padding(.top, 6)
                } else if hasVisual {
                    visual(compact: true)
                        .frame(height: stripHeight(26))
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .center : .bottomLeading)
        }
    }

    // MARK: Auto: medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 4 * sp) {
            headerBlock
            mediumBody
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14 * sp) {
            VStack(alignment: .leading, spacing: 3 * sp) {
                Spacer(minLength: 2)
                if !hasValue {
                    captionText(lines: 5)
                } else {
                    valueText(tile.value.count > 8 ? 28 : 36)
                    captionText(lines: 2)
                }
                detailText
                footnoteText
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            mediumPanel
                .frame(width: tile.rows.isEmpty ? 168 : 184)
                .frame(maxHeight: .infinity)
        }
    }

    private var mediumRowLimit: Int {
        if !tile.buttons.isEmpty { return 2 }
        return tile.rows.contains { $0.detail != nil && $0.progress != nil } ? 3 : 4
    }

    /// Type-erased on purpose (2026-11-25): its type is not part of the widget's own type. The free version 572 crashed
    /// on the Store and in Créer with a stack overflow of the main thread (1 MB) while the Swift runtime built the type
    /// of this view: one more level of condition here (the rest bar above the buttons of « Prochaine série ») was one
    /// too many under the 800 frames of a page of widgets. Do not turn it back into `some View`.
    private var mediumPanel: AnyView {
        if prefersChosenChart && tile.buttons.isEmpty {
            return AnyView(visual(compact: false))
        }
        if !tile.rows.isEmpty {
            return AnyView(MediumRowsPanel(
                // As many lines as the panel holds under its title and above its buttons (and its rest bar), none cut.
                rows: fitted(mediumRowLimit + s.rowDelta, compact: false,
                             used: headerCost + 4 * sp + (tile.buttons.isEmpty ? 0 : buttonsCost + (hasVisual && isTimer ? 13 : 0))),
                buttons: Array(tile.buttons.prefix(2)), context: context,
                // The rest of « Prochaine série » stays visible above its buttons, as a thin line.
                rest: hasVisual && isTimer && !tile.buttons.isEmpty ? AnyView(visual(compact: true)) : nil
            ))
        }
        if !tile.buttons.isEmpty {
            return AnyView(VStack(spacing: 8) {
                Spacer(minLength: 0)
                if hasVisual {
                    // The rest bar is a thin line: it doesn't take the height of a chart, so the bar and
                    // the buttons of « Prochaine série » and « Repos » fit the smallest medium widget.
                    visual(compact: true)
                        .frame(height: isTimer ? 10 : 44)
                }
                TileButtonsColumn(buttons: Array(tile.buttons.prefix(3)), context: context)
            })
        }
        if hasVisual {
            return AnyView(visual(compact: false))
        }
        return AnyView(Color.clear)
    }

    // MARK: Auto: large

    private var large: some View {
        VStack(alignment: .leading, spacing: 10 * sp) {
            headerBlock
            VStack(alignment: .leading, spacing: 3 * sp) {
                if hasValue {
                    valueText(40)
                }
                captionText(lines: hasValue ? 3 : 6)
                detailText
            }
            if hasVisual {
                visual(compact: segmentsWithRows, namedByRows: segmentsWithRows)
                    .chartHeight(tile.rows.isEmpty ? 150 : (segmentsWithRows ? 14 : 86), fills: fillsHeight || tile.rows.isEmpty)
                    .clipped()
            }
            if !tile.rows.isEmpty {
                // What the chart, the figure and the buttons leave, in whole lines.
                let chartCost: CGFloat = hasVisual ? (segmentsWithRows ? 14 : 86) + 10 * sp : 0
                TileRowsView(rows: fitted((hasVisual ? 5 : 8) + s.rowDelta, compact: false,
                                          used: headerCost + 10 * sp + valueCost(40) + captionCost(hasValue ? 3 : 6) + detailCost + 10 * sp
                                              + chartCost + buttonsCost + footnoteCost),
                             context: context, compact: false)
            }
            Spacer(minLength: 0)
            if !tile.buttons.isEmpty {
                TileButtonsRow(buttons: Array(tile.buttons.prefix(3)), context: context)
            }
            footnoteText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Vertical: title, value, then the chart below

    @ViewBuilder private var verticalLayout: some View {
        if context.isMedium && !tile.buttons.isEmpty {
            verticalMediumWithButtons
        } else {
            verticalStack
        }
    }

    /// A medium widget with buttons (« Prochaine série », « Repos », a counter…): the title, the figure and
    /// one line of caption, then the buttons, as in the small widget (no chart, no detail: they don't fit
    /// the smallest iPhone, 148 pt high). Stacked as in the other sizes, the chart (42 pt) and the buttons were
    /// taller than the widget: its title and its last line were cut off (the Éditorial theme is vertical).
    /// A fixed choice, not a ViewThatFits: the app stopped responding on screens with many widgets (Build 354).
    private var verticalMediumWithButtons: some View {
        VStack(alignment: s.horizontalAlignment, spacing: 4 * sp) {
            headerBlock
            VStack(alignment: s.horizontalAlignment, spacing: 2 * sp) {
                if hasValue { valueText(tile.value.count > 7 ? 24 : 28) }
                captionText(lines: 1)
            }
            Spacer(minLength: 0)
            buttonsRow(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .top : .topLeading)
    }

    private var verticalStack: some View {
        let valueSize: CGFloat = context.isSmall ? 30 : (context.isLarge ? 46 : 34)
        // A large widget's chart gives height to its lines (the widget's own subject) instead of leaving a tall chart alone.
        let chartHeight: CGFloat = context.isSmall ? stripHeight(30) : (context.isLarge ? (tile.rows.isEmpty ? 120 : 80) : 42)
        let showsChart = hasVisual && (tile.buttons.isEmpty || !context.isSmall)
        let captionLines = wordsLines(context.isSmall || (context.isMedium && hasVisual) ? 2 : 3)
        // The lines (compact in small and medium) that fit under what is already shown, for a given chart height.
        func rowsFor(chart: CGFloat) -> [TileRow] {
            guard !tile.rows.isEmpty, context.isLarge || tile.buttons.isEmpty else { return [] }
            let used = headerCost + valueCost(tile.value.count > 7 ? valueSize * 0.8 : valueSize) + captionCost(captionLines)
                + (context.isSmall ? 0 : detailCost) + (showsChart ? chart : 0) + buttonsCost + (showsFootnote ? footnoteCost : 0) + 21 * sp
            return fitted((context.isLarge ? (hasVisual ? 4 : 7) : 4) + s.rowDelta, compact: !context.isLarge, used: used)
        }
        // A parts bar whose lines fit under it is named by them (with their amounts), as a thin bar.
        let thinRows = segmentsWithRows && showsChart ? rowsFor(chart: 14) : []
        let named = !thinRows.isEmpty
        let shownRows = named ? thinRows : rowsFor(chart: chartHeight)
        return VStack(alignment: s.horizontalAlignment, spacing: 5 * sp) {
            headerBlock
            if hasValue { valueText(tile.value.count > 7 ? valueSize * 0.8 : valueSize) }
            captionText(lines: captionLines)
            if !context.isSmall { detailText }
            if showsChart {
                visual(compact: context.isSmall || named, namedByRows: named)
                    // A large widget's chart takes the height left (bars on a third, two thirds empty below).
                    .chartHeight(named ? 14 : chartHeight, fills: fillsHeight || growsInRoom || (context.isLarge && tile.rows.isEmpty))
                    .frame(maxWidth: .infinity)
            }
            if !shownRows.isEmpty {
                TileRowsView(rows: shownRows, context: context, compact: !context.isLarge)
            }
            Spacer(minLength: 0)
            buttonsRow(context.isSmall ? 2 : 3)
            if showsFootnote { footnoteText }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .top : .topLeading)
    }

    // MARK: Horizontal: icon | value | progress

    private var horizontalLayout: some View {
        VStack(alignment: .leading, spacing: 8 * sp) {
            if s.showsTitle { WLabel(text: tile.title, style: s) }
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 10 * sp) {
                if showsIcon && !context.isSmall {
                    StyledIcon(symbol: tile.symbol, style: s, size: context.isLarge ? 20 : 16)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if hasValue { valueText(context.isSmall ? 24 : (context.isLarge ? 38 : 30)) }
                    captionText(lines: wordsLines(2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The widget's own progress only: the progress of one of its lines drew a ring that said nothing (« Ma journée »).
                if let progress = tile.visual.progressValue {
                    miniProgress(progress)
                        .frame(width: context.isSmall ? 50 : 66, height: context.isSmall ? 50 : 66)
                } else if hasVisual, let values = tile.visual.seriesValues {
                    SeriesLineChart(values: values, style: s, fillOpacity: 0, lineWidth: 2, showsEndDot: true, showsEndValue: true, showsStartValue: true)
                        .frame(width: context.isSmall ? 64 : 128, height: context.isSmall ? 42 : 58)
                        .styleDepth(s)
                }
            }
            // The lines (the widget's subject) that fit under the title, the figure and the chart.
            let figureHeight = max(valueCost(context.isSmall ? 24 : (context.isLarge ? 38 : 30)) + captionCost(wordsLines(2)),
                                   tile.visual.progressValue != nil ? 66 : (hasVisual && tile.visual.seriesValues != nil ? 58 : 0))
            let aboveRows = headerCost + 32 * sp + figureHeight + buttonsCost
            if context.isLarge {
                let drawsChart = hasVisual && progressFraction == nil && tile.visual.seriesValues == nil
                if drawsChart {
                    visual(compact: false).chartHeight(110, fills: fillsHeight)
                }
                if !tile.rows.isEmpty {
                    TileRowsView(rows: fitted(5 + s.rowDelta, compact: false, used: aboveRows + (drawsChart ? 118 : 0)), context: context, compact: false)
                }
            } else if context.isMedium && !tile.rows.isEmpty && tile.buttons.isEmpty {
                // As many lines as the room under the figure holds (a bigger iPhone shows more than one), none cut.
                TileRowsView(rows: fitted(3 + s.rowDelta, compact: true, used: aboveRows), context: context, compact: true)
            }
            Spacer(minLength: 0)
            if !context.isSmall { buttonsRow(3) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A small ring (or the chosen progress chart) next to the value.
    @ViewBuilder private func miniProgress(_ progress: Double) -> some View {
        switch s.options.chart {
        case .pie: ProgressPieChart(progress: progress, style: s, showsValue: true)
        case .gauge: GaugeArcChart(progress: progress, style: s, lineWidth: 6 * CGFloat(s.options.chartThickness), showsValue: true)
        default:
            ZStack {
                RingView(progress: progress, lineWidth: 6 * CGFloat(s.options.chartThickness), color: s.chart, track: s.options.chartFill ? s.track : .clear)
                // The ring always says its percentage: a ring alone explains nothing.
                Text(Fmt.percent(progress))
                    .font(s.text(10, .semibold).monospacedDigit())
                    .foregroundStyle(s.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
            }
            .styleDepth(s)
        }
    }

    // MARK: Minimal: one big value

    private var minimalLayout: some View {
        let size: CGFloat = context.isSmall ? 46 : (context.isLarge ? 84 : 58)
        return VStack(alignment: s.horizontalAlignment, spacing: 4 * sp) {
            if s.showsTitle { WLabel(text: tile.title, style: s) }
            Spacer(minLength: 0)
            if hasValue {
                valueText(size)
                    .minimumScaleFactor(0.4)
            } else {
                captionText(lines: 4)
            }
            if hasValue {
                captionText(lines: 2)
            }
            if context.isLarge { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .center : .bottomLeading)
    }

    /// A medium widget in Minimal or Focus: the figure on the left, the lines (the three macros, the session's
    /// exercises) or the chart on the right, instead of two thirds left empty.
    @ViewBuilder private func besideLines<Figure: View>(_ figure: Figure) -> some View {
        if !context.isSmall && (!tile.rows.isEmpty || hasVisual) {
            HStack(alignment: .center, spacing: 14 * sp) {
                figure
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(s.secondary.opacity(0.22))
                    .frame(width: 1)
                    .padding(.vertical, 6)
                Group {
                    if !tile.rows.isEmpty {
                        // The whole height is the lines' (the title sits in the figure's column): whole lines only.
                        TileRowsView(rows: fitted((context.isLarge ? 8 : 4) + s.rowDelta, compact: !context.isLarge, used: 0),
                                     context: context, compact: !context.isLarge)
                    } else {
                        // Half the width and the whole height: room for the days, the values and the names of the parts.
                        visual(compact: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        } else {
            figure
        }
    }

    // MARK: Focus: icon and value at the center

    private var centeredLayout: some View {
        // A small widget with a long caption gives its icon's line to a second caption line (fixed by the text, not measured).
        let longCaption = context.isSmall && (tile.caption?.count ?? 0) > 20
        return VStack(spacing: 5 * sp) {
            Spacer(minLength: 0)
            if showsIcon && !longCaption {
                StyledIcon(symbol: tile.symbol, style: s, size: context.isSmall ? 16 : 20)
            }
            if hasValue { valueText(context.isSmall ? 30 : (context.isLarge ? 52 : 38)) }
            if s.showsTitle { WLabel(text: tile.title, style: s) }
            captionText(lines: longCaption ? 2 : (context.isSmall ? 1 : 2))
            if context.isLarge, let progress = progressFraction {
                BarView(progress: progress, color: s.chart, track: s.track, height: 8 * CGFloat(s.options.chartThickness), radius: s.radius(4))
                    .frame(maxWidth: 200)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Two columns

    private var splitLayout: some View {
        HStack(alignment: .top, spacing: 10 * sp) {
            // The figure right under the title, not at the bottom of an empty column.
            VStack(alignment: .leading, spacing: 3 * sp) {
                headerBlock
                if hasValue { valueText(context.isSmall ? 22 : (context.isLarge ? 36 : 30)) }
                captionText(lines: hasValue ? (context.isLarge ? 4 : 3) : (context.isLarge ? 10 : 5))
                if context.isLarge { detailText }
                // A large widget has room under the figure for the widget's chart (its lines are in the other column).
                if context.isLarge && hasVisual && !tile.rows.isEmpty && !fillsHeight {
                    visual(compact: false)
                        .frame(height: isSegments ? 120 : 90)
                        .clipped()
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Rectangle()
                .fill(s.secondary.opacity(0.25))
                .frame(width: 1)
            VStack(alignment: .leading, spacing: 6 * sp) {
                if !tile.rows.isEmpty {
                    TileRowsView(rows: fitted((context.isSmall ? 3 : (context.isLarge ? 9 : 4)) + s.rowDelta, compact: !context.isLarge,
                                              used: context.isSmall ? 0 : buttonsCost),
                                 context: context, compact: !context.isLarge)
                } else if hasVisual {
                    visual(compact: context.isSmall)
                } else if let detail = tile.detail {
                    Text(detail).font(s.text(11)).foregroundStyle(s.secondary)
                }
                Spacer(minLength: 0)
                if !context.isSmall { buttonsRow(2) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Data: several statistics

    private struct Stat: Identifiable {
        let id: String
        let label: String
        let value: String
        var color: Color?
    }

    private var stats: [Stat] {
        var result: [Stat] = []
        if hasValue && tile.timer == nil {
            result.append(Stat(id: "value", label: tile.caption ?? tile.title, value: [tile.value, tile.unit].compactMap { $0 }.joined(separator: " "), color: valueColor))
        }
        for row in tile.rows {
            let value = row.value ?? row.progress.map { Fmt.percent($0) } ?? row.detail
            if let value {
                result.append(Stat(id: row.id, label: row.title, value: value, color: row.colorHex.map { Color(hex: $0) }))
            }
        }
        if result.count < 2, let detail = tile.detail {
            result.append(Stat(id: "detail", label: tr("Détail"), value: detail))
        }
        return result
    }

    private var dataLayout: some View {
        // A medium widget shows every figure that fits in two rows (the three macros, the session's exercises), not two.
        // Medium: one row of figures (four at most) under a chart, two rows without (a second row under the chart was cut off).
        let limit = max(1, (context.isSmall ? 2 : (context.isLarge ? 8 : (hasVisual ? 4 : 6))) + (context.isLarge ? s.rowDelta : 0))
        let named = isSegments && !tile.rows.isEmpty && s.options.chart == .auto
        let shown = Array(stats.prefix(limit))
        let columns = context.isSmall ? 1 : (context.isLarge ? 2 : (shown.count <= 4 ? max(1, shown.count) : 3))
        let chunks = stride(from: 0, to: shown.count, by: columns).map { Array(shown[$0..<min($0 + columns, shown.count)]) }
        // One row of figures in a medium widget has the room for larger figures.
        let oneRow = context.isMedium && chunks.count == 1 && !hasVisual
        return VStack(alignment: .leading, spacing: 8 * sp) {
            headerBlock
            // Without a chart below them, the figures sit at the bottom: no empty half under one row of figures.
            if context.isSmall || (context.isMedium && !hasVisual) { Spacer(minLength: 0) }
            if context.isSmall && stats.count > 2 {
                // Small: the main figure, then the others two by two (one row, two when dense).
                let others = Array(stats.dropFirst().prefix(s.rowDelta > 0 ? 4 : 2))
                let pairs = stride(from: 0, to: others.count, by: 2).map { Array(others[$0..<min($0 + 2, others.count)]) }
                statGrid([[stats[0]]] + pairs, value: 22, other: 15)
            } else {
                statGrid(chunks, value: context.isSmall ? 26 : (oneRow ? 26 : 22), other: context.isSmall ? 17 : (oneRow ? 20 : 18))
            }
            if !context.isSmall, hasVisual {
                visual(compact: context.isMedium, namedByRows: named)
                    .frame(minHeight: fillsHeight ? 110 : (growsInRoom ? 40 : nil),
                           maxHeight: fillsHeight || growsInRoom ? .infinity : (context.isLarge ? 110 : (isSegments && !named ? 36 : 30)))
                    .layoutPriority(fillsHeight || growsInRoom ? 1 : 0)
            }
            Spacer(minLength: 0)
            if context.isLarge { buttonsRow(3) }
            if showsFootnote { footnoteText }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statGrid(_ chunks: [[Stat]], value: CGFloat, other: CGFloat) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12 * sp, verticalSpacing: (context.isSmall ? 6 : 10) * sp) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { chunk in
                GridRow {
                    ForEach(chunk.element) { stat in
                        VStack(alignment: .leading, spacing: 1) {
                            statLabel(stat)
                            Text(stat.value)
                                .font(s.number(stat.id == "value" ? value : other))
                                .foregroundStyle(s.numberColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .styleDepth(s)
                                .privacySensitive(tile.isSensitive)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // The main figure alone on its row spans the two columns of the pairs below it.
                        .gridCellColumns(chunk.element.count == 1 && chunks.contains { $0.count > 1 } ? 2 : 1)
                    }
                }
                if chunk.offset < chunks.count - 1 {
                    Rectangle().fill(s.secondary.opacity(0.18)).frame(height: 1).gridCellUnsizedAxes(.horizontal)
                }
            }
        }
    }

    // MARK: List: the lines first

    private var listLayout: some View {
        VStack(alignment: .leading, spacing: 7 * sp) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                headerBlock
                Spacer(minLength: 4)
                // A small widget keeps its width for the title and the lines.
                if hasValue && tile.timer == nil && !context.isSmall {
                    Text([tile.value, tile.unit].compactMap { $0 }.joined(separator: " "))
                        .font(s.number(context.isSmall ? 15 : 18))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize()
                        .privacySensitive(tile.isSensitive)
                }
            }
            if context.isSmall && hasValue && tile.timer == nil {
                Text([tile.value, tile.unit].compactMap { $0 }.joined(separator: " "))
                    .font(s.number(20))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .privacySensitive(tile.isSensitive)
            }
            // Dense styles add lines, never more than the size holds (the sixth line was cut off).
            let cap = min(context.isSmall ? (hasValue ? 3 : 4) : (context.isLarge ? 10 : 4), max(1, (context.isLarge ? 10 : 4) + s.rowDelta))
            if !hasValue && tile.caption != nil {
                // A widget of words (an AI sentence): the sentence first, then the lines that fit under it.
                let lines = context.isLarge ? 4 : 2
                captionText(lines: lines)
                TileRowsView(rows: fitted(cap, compact: context.isSmall, used: headerCost + 14 * sp + captionCost(lines)),
                             context: context, compact: context.isSmall)
            } else {
                TileRowsView(rows: Array(tile.rows.prefix(cap)), context: context, compact: context.isSmall)
            }
            Spacer(minLength: 0)
            if !context.isSmall { buttonsRow(3) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Progress: a big bar

    private var progressLayout: some View {
        let progress = progressFraction ?? 0
        let height: CGFloat = (context.isSmall ? 12 : (context.isLarge ? 22 : 16)) * CGFloat(s.options.chartThickness)
        return VStack(alignment: .leading, spacing: 6 * sp) {
            headerBlock
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                if hasValue { valueText(context.isSmall ? 24 : (context.isLarge ? 40 : 32)) }
                Spacer(minLength: 4)
                Text(Fmt.percent(progress))
                    .font(s.text(context.isSmall ? 12 : 14, .bold).monospacedDigit())
                    .foregroundStyle(s.chart)
            }
            BarView(progress: progress, color: s.chart, track: s.options.chartFill ? s.track : s.track.opacity(0.4), height: height, radius: s.radius(height / 2))
                .styleDepth(s)
            captionText(lines: context.isSmall ? 1 : 2)
            if context.isLarge {
                let withProgress = tile.rows.filter { $0.progress != nil }
                // Whole lines under the figure, the bar and the caption, above the buttons.
                let used = headerCost + valueCost(40) + height + captionCost(2) + 30 * sp + 6 + buttonsCost
                if !withProgress.isEmpty {
                    TileRowsView(rows: fitted(4 + s.rowDelta, compact: false, used: used, from: withProgress), context: context, compact: false)
                        .padding(.top, 6)
                } else if !tile.rows.isEmpty {
                    TileRowsView(rows: fitted(4 + s.rowDelta, compact: false, used: used), context: context, compact: false)
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)
            }
            if !context.isSmall { buttonsRow(3) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Graph: the value and a large chart

    private var graphLayout: some View {
        // A parts bar is named by the widget's own lines (the macros with their grams) when there are some.
        let named = segmentsWithRows && !context.isSmall
        return VStack(alignment: .leading, spacing: 6 * sp) {
            headerBlock
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if hasValue { valueText(context.isSmall ? 22 : (context.isLarge ? 36 : 26)) }
                if !context.isSmall {
                    captionText(lines: hasValue ? 1 : wordsLines(1))
                }
            }
            if let progress = tile.visual.progressValue, s.options.chart == .auto {
                // A single value as a large ring.
                ZStack {
                    RingView(progress: progress, lineWidth: (context.isSmall ? 8 : 12) * CGFloat(s.options.chartThickness), color: s.chart, track: s.options.chartFill ? s.track : .clear)
                    Text(Fmt.percent(progress))
                        .font(s.number(context.isSmall ? 15 : 20))
                        .foregroundStyle(s.numberColor)
                }
                .styleDepth(s)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasVisual && !(named && context.isMedium) {
                visual(compact: context.isSmall || named, namedByRows: named)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No room for a chart and its legend in a medium widget: its own lines (with the amounts) instead of the bar.
                TileRowsView(rows: fitted((context.isLarge ? 8 : 3) + s.rowDelta, compact: !context.isLarge,
                                          used: headerCost + valueCost(context.isSmall ? 22 : (context.isLarge ? 36 : 26)) + 12 * sp
                                              + (hasValue ? 0 : captionCost(wordsLines(1)))),
                             context: context, compact: !context.isLarge)
                Spacer(minLength: 0)
            }
            if context.isLarge, hasVisual, !tile.rows.isEmpty {
                // Under the chart (which keeps the height left): the lines that fit, whole.
                TileRowsView(rows: fitted(named ? 6 + s.rowDelta : 3, compact: !named,
                                          used: headerCost + valueCost(36) + (named ? 30 : 90) + 18 * sp),
                             context: context, compact: !named)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Cards: each information on its own card

    private var cardsLayout: some View {
        // A medium widget shows up to 4 figures beside the main one (the three macros, the session's exercises).
        let others = Array(stats.filter { $0.id != "value" }.prefix(max(0, (context.isLarge ? 4 + s.rowDelta / 2 : (context.isMedium ? 4 : 1)))))
        return VStack(alignment: .leading, spacing: 6 * sp) {
            if !context.isSmall { headerBlock }
            if context.isMedium {
                HStack(spacing: 6 * sp) {
                    mainCard.frame(maxWidth: .infinity)
                    if others.count > 2 {
                        // Two rows of two beside the main card.
                        let pairs = stride(from: 0, to: others.count, by: 2).map { Array(others[$0..<min($0 + 2, others.count)]) }
                        VStack(spacing: 6 * sp) {
                            ForEach(Array(pairs.enumerated()), id: \.offset) { pair in
                                HStack(spacing: 6 * sp) {
                                    ForEach(pair.element) { statCard($0, small: true) }
                                    if pair.element.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(others) { statCard($0) }
                    }
                    if others.isEmpty && hasVisual {
                        card { visual(compact: true) }
                    }
                }
            } else if context.isSmall && tile.rows.count > 1 {
                // A small widget: the main card, then as many lines as its height holds (two with bars, three without,
                // one more when dense), in a plain list at its own height. ViewThatFits, fixedSize on a card and
                // TileRowsView here froze the rendering (runs 603 to 608).
                let withBars = tile.rows.contains { $0.progress != nil }
                let lines = Array(tile.rows.prefix((withBars ? 2 : 3) + (s.rowDelta > 0 ? 1 : 0)))
                mainCard
                VStack(alignment: .leading, spacing: 4 * sp) {
                    ForEach(lines) { row in
                        HStack(spacing: 5) {
                            if let hex = row.colorHex, !s.isAccented {
                                Circle().fill(Color(hex: hex)).frame(width: 5, height: 5)
                            }
                            Text(row.title)
                                .font(s.text(11))
                                .foregroundStyle(s.primary)
                                .lineLimit(1)
                                .layoutPriority(1)
                            Spacer(minLength: 4)
                            if let value = row.value {
                                Text(value)
                                    .font(s.text(11, .semibold).monospacedDigit())
                                    .foregroundStyle(s.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .privacySensitive(row.isSensitive)
                            }
                        }
                    }
                }
                .padding(8 * sp)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(s.panel, in: RoundedRectangle(cornerRadius: s.blockRadius(12), style: .continuous))
                .styleDepth(s)
            } else {
                mainCard
                if context.isLarge && hasVisual {
                    // The cards below name the parts of a bar: it stays thin; the chart is shorter when two rows of cards follow.
                    let named = segmentsWithRows && !others.isEmpty
                    card { visual(compact: named, namedByRows: named) }
                        .frame(minHeight: fillsHeight ? 110 : nil,
                               maxHeight: fillsHeight || growsInRoom ? .infinity : (named ? 50 : (others.count > 2 ? 85 : 110)))
                        .layoutPriority(fillsHeight || growsInRoom ? 1 : 0)
                }
                if !others.isEmpty {
                    let pairs = stride(from: 0, to: others.count, by: 2).map { Array(others[$0..<min($0 + 2, others.count)]) }
                    ForEach(Array(pairs.enumerated()), id: \.offset) { pair in
                        HStack(spacing: 6 * sp) {
                            ForEach(pair.element) { statCard($0) }
                        }
                    }
                } else if context.isSmall && hasVisual {
                    card { visual(compact: true) }
                }
            }
            if context.isLarge { buttonsRow(3) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mainCard: some View {
        card {
            VStack(alignment: .leading, spacing: 2) {
                if context.isSmall {
                    HStack(spacing: 4) {
                        if showsIcon { StyledIcon(symbol: tile.symbol, style: s, size: 10) }
                        if s.showsTitle { WLabel(text: tile.title, style: s) }
                    }
                }
                // The figure at the top of its card, under its name, not at the bottom of an empty card.
                if hasValue { valueText(context.isSmall ? 26 : (context.isLarge ? 34 : 24)) }
                captionText(lines: context.isLarge ? 2 : 1)
                Spacer(minLength: 0)
            }
        }
    }

    /// A stat's name, after a dot of its line's color: the amount keeps the style's number color (readable on its panels).
    private func statLabel(_ stat: Stat) -> some View {
        HStack(spacing: 4) {
            if let color = stat.color { Circle().fill(color).frame(width: 5, height: 5) }
            Text(s.labelText(stat.label))
                .font(s.label(10))
                .foregroundStyle(s.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    /// `small`: one of four figures in a medium widget, a line shorter and a size smaller.
    private func statCard(_ stat: Stat, small: Bool = false) -> some View {
        card {
            VStack(alignment: .leading, spacing: small ? 1 : 2) {
                HStack(spacing: 4) {
                    // The line's own color as a dot: on the style's panels the amount keeps the style's number color.
                    if let color = stat.color { Circle().fill(color).frame(width: 6, height: 6) }
                    Text(stat.label)
                        .font(s.text(10, .medium))
                        .foregroundStyle(s.secondary)
                        .lineLimit(context.isSmall || small ? 1 : 2)
                        .minimumScaleFactor(0.85)
                }
                Text(stat.value)
                    .font(s.number(context.isSmall ? 15 : (small ? 14 : 16)))
                    .foregroundStyle(s.numberColor)
                    .lineLimit(context.isLarge ? 2 : 1)
                    .minimumScaleFactor(0.5)
                    .privacySensitive(tile.isSensitive)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Rows

struct TileRowsView: View {
    let rows: [TileRow]
    let context: RenderContext
    let compact: Bool

    private var s: ResolvedStyle { context.style }

    var body: some View {
        VStack(alignment: .leading, spacing: (compact ? 5 : 7) * s.spacing) {
            ForEach(rows) { row in
                rowView(row)
            }
        }
    }

    @ViewBuilder private func rowView(_ row: TileRow) -> some View {
        if let action = row.action {
            TileActionButton(action: action, isEnabled: context.isInteractive) {
                rowContent(row)
            }
        } else {
            rowContent(row)
        }
    }

    private func rowContent(_ row: TileRow) -> some View {
        // Without colors, only opacity remains of the line's own color: the style's white is used instead.
        let rowColor = s.isAccented ? nil : row.colorHex.map { Color(hex: $0) }
        let color = rowColor ?? s.icon
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                if let done = row.isDone {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: compact ? 13 : 15, weight: .medium))
                        .foregroundStyle(done ? (rowColor ?? s.accent) : s.secondary)
                } else if let symbol = row.symbol, !s.options.isHidden("icon") {
                    Image(systemName: s.symbol(symbol))
                        .font(.system(size: (compact ? 10 : 12) * CGFloat(s.options.iconScale), weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: (compact ? 14 : 18) * CGFloat(s.options.iconScale))
                } else if row.colorHex != nil {
                    Circle().fill(color).frame(width: 7, height: 7)
                }
                RowSplit(gap: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.title)
                            .font(s.text(compact ? 12 : 13, row.isHighlighted ? .semibold : .regular))
                            .foregroundStyle(row.isDone == true ? s.secondary : s.primary)
                            .strikethrough(row.isDone == true, color: s.secondary)
                            // Short lists have room for a second line.
                            .lineLimit(rows.count <= 3 ? 2 : 1)
                            .minimumScaleFactor(0.8)
                        if let detail = row.detail, !compact, s.showsDetails {
                            Text(detail)
                                .font(s.text(10))
                                .foregroundStyle(s.secondary)
                                .lineLimit(1)
                        }
                    }
                    if let value = row.value {
                        Text(value)
                            .font(s.text(compact ? 11 : 12, .semibold).monospacedDigit())
                            .foregroundStyle(row.isHighlighted ? s.accent : s.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .privacySensitive(row.isSensitive)
                    }
                }
            }
            if let progress = row.progress {
                let height = (compact ? 3 : 4) * CGFloat(s.options.chartThickness)
                BarView(progress: progress, color: rowColor ?? s.chart, track: s.track, height: height, radius: s.radius(height / 2))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Buttons

struct TileActionButton<Label: View>: View {
    let action: TileAction
    let isEnabled: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        switch action {
        case let .completeSet(position):
            IntentButton(intent: CompleteSetIntent(expecting: position), isEnabled: isEnabled, label: label)
        case let .skipSet(position):
            IntentButton(intent: SkipSetIntent(expecting: position), isEnabled: isEnabled, label: label)
        case let .undoSet(position):
            IntentButton(intent: UndoSetIntent(expecting: position), isEnabled: isEnabled, label: label)
        case .cancelWorkout:
            IntentButton(intent: CancelWorkoutIntent(), isEnabled: isEnabled, label: label)
        case .startWorkout:
            IntentButton(intent: StartWorkoutIntent(), isEnabled: isEnabled, label: label)
        case let .logFood(id):
            IntentButton(intent: LogFoodIntent(foodID: id), isEnabled: isEnabled, label: label)
        case let .quickExpense(id):
            IntentButton(intent: QuickExpenseIntent(expenseID: id), isEnabled: isEnabled, label: label)
        case let .counter(id, delta):
            IntentButton(intent: CounterStepIntent(counterID: id, delta: delta), isEnabled: isEnabled, label: label)
        case let .toggleProjectTask(project, task):
            IntentButton(intent: ToggleProjectTaskIntent(projectID: project, taskID: task), isEnabled: isEnabled, label: label)
        case .revealCard:
            IntentButton(intent: RevealCardIntent(), isEnabled: isEnabled, label: label)
        case let .gradeCard(known):
            IntentButton(intent: GradeCardIntent(known: known), isEnabled: isEnabled, label: label)
        case let .toggleAssignment(id):
            IntentButton(intent: ToggleAssignmentIntent(assignmentID: id), isEnabled: isEnabled, label: label)
        case let .startFocus(minutes):
            IntentButton(intent: StartFocusIntent(minutes: minutes), isEnabled: isEnabled, label: label)
        case let .toggleHabit(id):
            IntentButton(intent: ToggleHabitIntent(habitID: UUID(uuidString: id) ?? UUID()), isEnabled: isEnabled, label: label)
        case .scanFood:
            if isEnabled {
                Link(destination: DeepLink.scanFood.url) { label() }
            } else {
                label()
            }
        }
    }
}

struct TileButtonLabel: View {
    let button: TileButton
    let style: ResolvedStyle
    var expands = true
    var iconOnly = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: style.symbol(button.symbol))
                .font(.system(size: 11, weight: .bold))
            if !iconOnly {
                Text(button.title)
                    .font(style.text(12, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(button.isProminent ? style.onAccent : style.primary)
        .padding(.horizontal, iconOnly ? 11 : 8)
        .frame(maxWidth: expands ? .infinity : nil, minHeight: 30)
        .accessibilityLabel(Text(button.title))
        .background {
            let shape = RoundedRectangle(cornerRadius: style.radius(15), style: .continuous)
            if button.isProminent {
                shape.textBackdrop(style.accent, isAccented: style.isAccented, isProminent: true)
            } else {
                shape.fill(style.panel)
            }
        }
    }
}

/// The compact pill at the top right of a widget.
struct TileHeaderButtonLabel: View {
    let button: TileButton
    let style: ResolvedStyle
    var iconOnly = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: style.symbol(button.symbol))
                .font(.system(size: 10, weight: .bold))
            if !iconOnly {
                Text(button.title)
                    .font(style.text(11, .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(style.onAccent)
        .padding(.horizontal, iconOnly ? 7 : 9)
        .frame(minHeight: 24)
        .background {
            RoundedRectangle(cornerRadius: style.radius(12), style: .continuous)
                .textBackdrop(style.accent, isAccented: style.isAccented, isProminent: true)
        }
        .accessibilityLabel(Text(button.title))
    }
}

struct TileButtonsRow: View {
    let buttons: [TileButton]
    let context: RenderContext

    /// Two buttons don't fit side by side with text in a small widget.
    private var isTight: Bool { context.isSmall && buttons.count > 1 }

    /// The small icon-only buttons (the fitness back arrow) come first, the main action last.
    private var ordered: [TileButton] { buttons.filter(\.isIconOnly) + buttons.filter { !$0.isIconOnly } }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { pair in
                let iconOnly = pair.element.isIconOnly || (isTight && !pair.element.isProminent)
                TileActionButton(action: pair.element.action, isEnabled: context.isInteractive) {
                    TileButtonLabel(button: pair.element, style: context.style, expands: !iconOnly, iconOnly: iconOnly)
                }
            }
        }
    }
}

/// The right side of a medium widget that has lines: the lines, then (if any) the rest bar and the buttons.
private struct MediumRowsPanel: View {
    let rows: [TileRow]
    let buttons: [TileButton]
    let context: RenderContext
    let rest: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileRowsView(rows: rows, context: context, compact: false)
            Spacer(minLength: 0)
            if !buttons.isEmpty {
                if let rest {
                    rest
                        .frame(height: 8)
                        .padding(.bottom, 5)
                }
                TileButtonsRow(buttons: buttons, context: context)
            }
        }
    }
}

/// The buttons beside the figure of a medium widget: one line per button with text, and the small
/// icon-only ones (the fitness back arrow, « Passer la série ») on the last line, before the main action.
/// One line each, « Série faite », the arrow and « Passer » were taller than the widget: its title and
/// its last line were cut off.
struct TileButtonsColumn: View {
    let buttons: [TileButton]
    let context: RenderContext

    var body: some View {
        let icons = buttons.filter(\.isIconOnly)
        let texts = buttons.filter { !$0.isIconOnly }
        VStack(spacing: 6) {
            ForEach(Array(texts.dropLast().enumerated()), id: \.offset) { pair in
                button(pair.element, expands: true)
            }
            HStack(spacing: 6) {
                ForEach(Array(icons.enumerated()), id: \.offset) { pair in
                    // Alone (no button with text), the icons share the width as before.
                    button(pair.element, expands: texts.isEmpty)
                }
                if let last = texts.last {
                    button(last, expands: true)
                }
            }
        }
    }

    private func button(_ button: TileButton, expands: Bool) -> some View {
        TileActionButton(action: button.action, isEnabled: context.isInteractive) {
            TileButtonLabel(button: button, style: context.style, expands: expands, iconOnly: button.isIconOnly)
        }
    }
}

// MARK: - Visuals

struct TileVisualView: View {
    let visual: TileVisual
    let context: RenderContext
    let compact: Bool
    var ringHex: String? = nil
    /// The widget's own lines name the parts (the three macros under their bar): no legend of its own.
    var namedByRows = false

    private var s: ResolvedStyle { context.style }
    private var thickness: CGFloat { CGFloat(s.options.chartThickness) }

    /// Names of parts: more of them where there is room (fixed by size, never measured).
    private var legendLimit: Int { compact ? 2 : (context.isMedium ? 3 : 5) }

    /// Labels under the bars. A small chart keeps them only when they are few and short (three letters).
    private func shownLabels(_ labels: [String]) -> [String] {
        guard compact else { return labels }
        // Many bars (a month of days): the days stay, `BarsChart` writes one in three under them.
        guard (labels.map(\.count).max() ?? 0) <= 12 else { return [] }
        return labels.map { String($0.prefix(3)) }
    }

    /// The widget's own bar labels (the days), when it has some.
    private var ownLabels: [String] {
        if case let .bars(_, labels, _) = visual { return shownLabels(labels) }
        return []
    }

    /// A ring: its percentage at the center when there is room, else beside it.
    @ViewBuilder private func ring(_ progress: Double) -> some View {
        if compact {
            HStack(spacing: 6) {
                RingView(progress: progress, lineWidth: 5 * thickness, color: s.chartColor(default: ringHex), track: s.options.chartFill ? s.track : .clear)
                    .aspectRatio(1, contentMode: .fit)
                Text(Fmt.percent(progress))
                    .font(s.number(13))
                    .foregroundStyle(s.numberColor)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack {
                RingView(progress: progress, lineWidth: 10 * thickness, color: s.chartColor(default: ringHex), track: s.options.chartFill ? s.track : .clear)
                Text(Fmt.percent(progress))
                    .font(s.number(18))
                    .foregroundStyle(s.numberColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var body: some View {
        let kind = s.options.chart
        if kind != .auto && ChartKind.options(for: visual.chartFamily).contains(kind) {
            chosen(kind)
        } else {
            original
        }
    }

    // MARK: The widget's own chart

    @ViewBuilder private var original: some View {
        switch visual {
        case .none:
            EmptyView()
        case let .ring(progress):
            ring(progress)
        case let .bar(progress):
            VStack {
                Spacer(minLength: 0)
                let height = (compact ? 6 : 10) * thickness
                // A bar says how far along it is: its percentage beside it.
                HStack(spacing: 6) {
                    BarView(progress: progress, color: s.chart, track: s.track, height: height, radius: s.radius(height / 2))
                    Text(Fmt.percent(progress)).font(s.text(compact ? 10 : 11, .bold).monospacedDigit()).foregroundStyle(s.chart).lineLimit(1).fixedSize()
                }
            }
        case let .bars(values, labels, highlight):
            BarsChart(values: values, labels: shownLabels(labels), highlight: highlight, style: s, showsValues: !compact)
        case let .line(values):
            // The first and the last value written on the line: a curve alone, without a day under it, says nothing.
            SeriesLineChart(values: values, style: s, fillOpacity: s.options.chartFill ? (compact ? 0.12 : 0.18) : 0,
                            lineWidth: 2 * thickness, showsEndDot: true, showsEndValue: true, showsStartValue: true)
        case let .segments(segments):
            SegmentsChart(segments: segments, showsLegend: !namedByRows, style: s, inline: compact, legendLimit: legendLimit)
        case let .week(days):
            WeekStrip(days: days, showsLabels: !compact, style: s)
        case let .month(days, offset, marked, today):
            MonthDots(days: days, offset: offset, marked: marked, today: today, style: s)
        case let .grid(names, rows, colors):
            // Fixed by size: a medium widget holds three habits (two when compact, four when dense), the large all six.
            HabitGrid(names: names, rows: rows, colors: colors, style: s,
                      maxRows: context.isLarge ? 6 : (context.isMedium ? 3 + (s.rowDelta > 0 ? 1 : s.rowDelta) : 3))
        case let .schedule(blocks, today, dates, first, last):
            ScheduleWeek(blocks: blocks, today: today, dates: dates, firstMinute: first, lastMinute: last, style: s)
        case let .symbol(name):
            Image(systemName: s.symbol(name))
                .resizable()
                .scaledToFit()
                .foregroundStyle(s.primary)
                .widgetAccentable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .sun(progress, sunrise, sunset):
            SunArc(progress: progress, sunrise: sunrise, sunset: sunset, compact: compact, style: s)
        case let .timer(start, end):
            VStack {
                Spacer(minLength: 0)
                ProgressView(timerInterval: start...max(end, start.addingTimeInterval(1)), countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(s.chart)
            }
        }
    }

    // MARK: The chart the person picked

    @ViewBuilder private func chosen(_ kind: ChartKind) -> some View {
        switch visual.chartFamily {
        case .series:
            let values = visual.seriesValues ?? []
            series(kind, values: values)
        case .progress:
            progress(kind, value: visual.progressValue ?? 0)
        case .segments:
            if case let .segments(segments) = visual {
                parts(kind, segments: segments)
            }
        case .none:
            original
        }
    }

    @ViewBuilder private func series(_ kind: ChartKind, values: [Double]) -> some View {
        // The values are written whenever the chart is not tiny: a chart without figures or labels explains nothing.
        let showsValues = !compact
        let labels = ownLabels
        switch kind {
        case .line:
            SeriesLineChart(values: values, style: s, fillOpacity: s.options.chartFill ? 0.18 : 0, lineWidth: 2 * thickness, showsEndDot: true, showsEndValue: true, showsStartValue: true)
        case .area:
            SeriesLineChart(values: values, style: s, fillOpacity: s.options.chartFill ? 0.5 : 0.25, lineWidth: 1.5 * thickness, showsEndValue: true, showsStartValue: true)
        case .bars:
            BarsChart(values: values, labels: labels, highlight: values.indices.last, style: s, showsValues: showsValues)
        case .histogram:
            BarsChart(values: values, labels: labels, highlight: values.indices.last, style: s, showsValues: showsValues, spacing: 1, corner: 0.5)
        case .dots:
            SeriesDotsChart(values: values, style: s, dotSize: (compact ? 4 : 6) * thickness)
        case .sparkline:
            SeriesLineChart(values: values, style: s, fillOpacity: 0, lineWidth: 1.4 * thickness, showsEndDot: true, showsEndValue: true, showsStartValue: true)
        case .evolution:
            SeriesLineChart(values: values, style: s, fillOpacity: s.options.chartFill ? 0.18 : 0, lineWidth: 2 * thickness, showsEndDot: true, showsChange: !compact)
        case .comparison:
            let last = values.last ?? 0
            let previous = values.dropLast()
            let average = previous.isEmpty ? last : previous.reduce(0, +) / Double(previous.count)
            ComparisonChart(current: last, reference: average, currentLabel: tr("Dernier"), referenceLabel: tr("Moyenne"), style: s)
        default:
            original
        }
    }

    @ViewBuilder private func progress(_ kind: ChartKind, value: Double) -> some View {
        let showsValues = !compact
        switch kind {
        case .ring:
            ring(value)
        case .pie:
            // Its percentage is always written, even in a strip: a pie or an arc alone explains nothing.
            ProgressPieChart(progress: value, style: s, showsValue: true)
        case .gauge:
            GaugeArcChart(progress: value, style: s, lineWidth: (compact ? 5 : 10) * thickness, showsValue: true)
        case .progress:
            if compact {
                HStack(spacing: 6) {
                    let height = 8 * thickness
                    BarView(progress: value, color: s.chart, track: s.options.chartFill ? s.track : s.track.opacity(0.4), height: height, radius: s.radius(height / 2))
                    Text(Fmt.percent(value)).font(s.text(11, .bold).monospacedDigit()).foregroundStyle(s.chart).lineLimit(1).fixedSize()
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer(minLength: 0)
                    if showsValues {
                        Text(Fmt.percent(value)).font(s.text(12, .bold).monospacedDigit()).foregroundStyle(s.chart)
                    }
                    let height = 14 * thickness
                    BarView(progress: value, color: s.chart, track: s.options.chartFill ? s.track : s.track.opacity(0.4), height: height, radius: s.radius(height / 2))
                }
            }
        case .comparison:
            ComparisonChart(current: value, reference: 1, currentLabel: tr("Actuel"), referenceLabel: tr("Objectif"), style: s, asPercent: true)
        default:
            original
        }
    }

    @ViewBuilder private func parts(_ kind: ChartKind, segments: [TileSegment]) -> some View {
        switch kind {
        case .ring:
            SegmentsRoundChart(segments: segments, style: s, hole: 0.62, showsLegend: !namedByRows, legendLimit: legendLimit)
        case .pie:
            SegmentsRoundChart(segments: segments, style: s, hole: 0, showsLegend: !namedByRows, legendLimit: legendLimit)
        case .bars:
            if compact {
                // Bars without names in a tiny strip: the colored strip with its names instead.
                SegmentsChart(segments: segments, showsLegend: !namedByRows, style: s, inline: true)
            } else {
                SegmentsBarsChart(segments: segments, style: s, showsNames: !namedByRows)
            }
        default:
            SegmentsChart(segments: segments, showsLegend: !namedByRows, style: s, inline: compact, legendLimit: legendLimit)
        }
    }
}

struct BarsChart: View {
    let values: [Double]
    let labels: [String]
    let highlight: Int?
    let style: ResolvedStyle
    var showsValues = false
    var spacing: CGFloat?
    var corner: CGFloat?

    var body: some View {
        let top = max(values.max() ?? 0, 0.000_1)
        let gap = spacing ?? (values.count > 14 ? 2 : 4) / CGFloat(style.options.chartThickness)
        let radius = corner ?? style.radius(values.count > 14 ? 1.5 : 3)
        VStack(spacing: 4) {
            GeometryReader { geo in
                // The values above the bars only when the chart is tall enough to keep real bars under them.
                let labelled = showsValues && values.count <= 10 && geo.size.height >= 56
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(values.enumerated()), id: \.offset) { pair in
                        let ratio = max(0, pair.element) / top
                        let isHighlight = pair.offset == highlight
                        VStack(spacing: 2) {
                            if labelled {
                                Text(ChartText.short(pair.element))
                                    .font(style.text(8, isHighlight ? .bold : .medium).monospacedDigit())
                                    .foregroundStyle(isHighlight ? style.primary : style.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            bar(isHighlight: isHighlight, radius: radius)
                                .frame(height: max(3, (geo.size.height - (labelled ? 12 : 0)) * CGFloat(ratio)))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            if labels.isEmpty, values.count >= 3, let first = values.first, let last = values.last, values.count > 10 || !showsValues {
                // No day names: at least the first and the last value, so the bars have two marks.
                HStack {
                    Text(ChartText.short(first))
                    Spacer(minLength: 2)
                    Text(ChartText.short(last))
                }
                .font(style.text(9).monospacedDigit())
                .foregroundStyle(style.secondary)
                .lineLimit(1)
            }
            if !labels.isEmpty {
                HStack(spacing: gap) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { pair in
                        let shown = labels.count <= 8 || pair.offset % 3 == 0 || pair.offset == highlight
                        // In an overlay: a label wider than its bar (a day among thirty) must not widen the row.
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 11, maxHeight: 11)
                            .overlay {
                                Text(shown ? pair.element : " ")
                                    .font(style.text(9, pair.offset == highlight ? .bold : .regular))
                                    .foregroundStyle(pair.offset == highlight ? style.primary : style.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder private func bar(isHighlight: Bool, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if style.options.chartFill || isHighlight {
            shape.fill(isHighlight ? style.chart : style.chart.opacity(0.35))
        } else {
            shape.strokeBorder(style.chart.opacity(0.7), lineWidth: 1)
        }
    }
}

struct LineChart: View {
    let values: [Double]
    let style: ResolvedStyle

    var body: some View {
        ZStack {
            if style.options.chartFill {
                SparklineShape(values: values, closed: true)
                    .fill(LinearGradient(colors: [style.chart.opacity(0.28), style.chart.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            }
            SparklineShape(values: values)
                .stroke(style.chart, style: StrokeStyle(lineWidth: 2 * CGFloat(style.options.chartThickness), lineCap: .round, lineJoin: .round))
        }
    }
}

struct SegmentsChart: View {
    let segments: [TileSegment]
    let showsLegend: Bool
    let style: ResolvedStyle
    /// A strip too small for the full legend: the names on one line (no percentages).
    var inline = false
    var legendLimit = 5

    var body: some View {
        let total = max(segments.reduce(0) { $0 + max(0, $1.value) }, 0.000_1)
        VStack(alignment: .leading, spacing: inline ? 5 : 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { pair in
                        Rectangle()
                            .fill(style.partColor(pair.element.colorHex, at: pair.offset))
                            .frame(width: max(2, (geo.size.width - CGFloat(segments.count) * 2) * CGFloat(max(0, pair.element.value) / total)))
                    }
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: style.radius(5 * CGFloat(style.options.chartThickness)), style: .continuous))
            }
            .frame(height: 10 * CGFloat(style.options.chartThickness))
            if showsLegend && inline {
                HStack(spacing: 6) {
                    ForEach(Array(segments.prefix(3).enumerated()), id: \.offset) { pair in
                        HStack(spacing: 3) {
                            Circle().fill(style.partColor(pair.element.colorHex, at: pair.offset)).frame(width: 6, height: 6)
                            Text(pair.element.label)
                                .font(style.text(9))
                                .foregroundStyle(style.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else if showsLegend {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(segments.prefix(legendLimit).enumerated()), id: \.offset) { pair in
                        HStack(spacing: 6) {
                            Circle().fill(style.partColor(pair.element.colorHex, at: pair.offset)).frame(width: 7, height: 7)
                            Text(pair.element.label)
                                .font(style.text(11))
                                .foregroundStyle(style.primary)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(Fmt.percent(max(0, pair.element.value) / total))
                                .font(style.text(11, .semibold).monospacedDigit())
                                .foregroundStyle(style.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct WeekStrip: View {
    let days: [Bool?]
    let showsLabels: Bool
    let style: ResolvedStyle

    var body: some View {
        let symbols = DateMath.weekdaySymbols()
        HStack(spacing: 4) {
            ForEach(Array(days.prefix(7).enumerated()), id: \.offset) { pair in
                VStack(spacing: 3) {
                    ZStack {
                        let shape = RoundedRectangle(cornerRadius: style.options.shape == .square ? 3 : 999, style: .continuous)
                        if pair.element == true {
                            shape.textBackdrop(style.chart, isAccented: style.isAccented, isProminent: true)
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(style.onAccent)
                        } else {
                            shape.fill(style.track.opacity(pair.element == nil ? 0.5 : 1))
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    if showsLabels, pair.offset < symbols.count {
                        Text(symbols[pair.offset])
                            .font(style.text(9, .medium))
                            .foregroundStyle(style.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct MonthDots: View {
    let days: Int
    let offset: Int
    let marked: Set<Int>
    let today: Int?
    let style: ResolvedStyle

    var body: some View {
        let cells = offset + days
        let rows = Int(ceil(Double(cells) / 7))
        GeometryReader { geo in
            let size = min(geo.size.width / 7, geo.size.height / CGFloat(max(rows, 1)))
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            let day = row * 7 + column - offset + 1
                            ZStack {
                                if day >= 1 && day <= days {
                                    Circle()
                                        .fill(marked.contains(day) ? style.chart : style.track)
                                        .padding(size * 0.2)
                                    if day == today {
                                        Circle()
                                            .strokeBorder(style.primary, lineWidth: 1.5)
                                            .padding(size * 0.08)
                                    }
                                }
                            }
                            .frame(width: size, height: size)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension View {
    /// A chart at `height`; the week's schedule (`fills`) is at least that tall and takes all the height left.
    @ViewBuilder func chartHeight(_ height: CGFloat, fills: Bool) -> some View {
        if fills {
            frame(minHeight: height, maxHeight: .infinity).layoutPriority(1)
        } else {
            frame(height: height)
        }
    }
}

/// The week's schedule in a large widget: a column a day, each entry a block in its color, with its
/// name when the block is tall enough.
/// A week at a glance: each day with its letter and its date, the hours down the side with a line
/// across, each entry a block with its name, its room and its start time when there is room.
struct ScheduleWeek: View {
    let blocks: [ScheduleBlock]
    let today: Int?
    var dates: [Int] = []
    var firstMinute = 8 * 60
    var lastMinute = 18 * 60
    let style: ResolvedStyle

    private let gutter: CGFloat = 20

    var body: some View {
        let symbols = DateMath.weekdaySymbols()
        let span = max(60, lastMinute - firstMinute)
        let step = span > 8 * 60 ? 120 : 60
        let hours = Array(stride(from: firstMinute, through: lastMinute, by: step))
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Color.clear.frame(width: gutter, height: 1)
                ForEach(0..<7, id: \.self) { day in
                    VStack(spacing: 0) {
                        Text(day < symbols.count ? symbols[day] : "")
                            .font(style.text(8, .medium))
                            .foregroundStyle(day == today ? style.chart : style.secondary)
                        if let date = dates[safe: day] {
                            Text("\(date)")
                                .font(style.text(11, day == today ? .bold : .semibold))
                                .foregroundStyle(day == today ? style.chart : style.primary)
                        }
                    }
                    .widgetAccentable(day == today)
                    .frame(maxWidth: .infinity)
                }
            }
            GeometryReader { proxy in
                let height = proxy.size.height
                let width = max(0, proxy.size.width - gutter - 3)
                ZStack(alignment: .topLeading) {
                    ForEach(hours, id: \.self) { minute in
                        let y = CGFloat(minute - firstMinute) / CGFloat(span) * height
                        Rectangle()
                            .fill(style.track)
                            .frame(width: width, height: 0.6)
                            .offset(x: gutter + 3, y: y)
                        Text("\(minute / 60)h")
                            .font(style.text(7, .medium))
                            .foregroundStyle(style.secondary)
                            .lineLimit(1)
                            .frame(width: gutter, alignment: .leading)
                            .offset(y: min(max(0, y - 5), max(0, height - 10)))
                    }
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(0..<7, id: \.self) { day in
                            column(day, height: height, span: span)
                        }
                    }
                    .frame(width: width, height: height)
                    .offset(x: gutter + 3)
                }
            }
        }
    }

    private func column(_ day: Int, height: CGFloat, span: Int) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: style.radius(4), style: .continuous)
                .fill(style.track.opacity(day == today ? 0.9 : 0.3))
            ForEach(Array(blocks.filter { $0.day == day }.enumerated()), id: \.offset) { item in
                let block = item.element
                let blockHeight = max(4, (block.end - block.start) * height)
                let lines = Self.lines(height: blockHeight, hasRoom: block.room != nil)
                // Without colors, a block in its color would be a solid white shape hiding its white text.
                RoundedRectangle(cornerRadius: style.blockRadius(3), style: .continuous)
                    .textBackdrop(Color(hex: block.colorHex), isAccented: style.isAccented)
                    .frame(height: blockHeight)
                    .overlay(alignment: .topLeading) {
                        if lines.title > 0 {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(block.title)
                                    .font(.system(size: 7, weight: .bold))
                                    .lineLimit(lines.title)
                                if lines.room, let room = block.room {
                                    Text(room)
                                        .font(.system(size: 6, weight: .semibold))
                                        .lineLimit(1)
                                }
                                if lines.time, let time = block.time {
                                    Text(time)
                                        .font(.system(size: 6, weight: .semibold))
                                        .opacity(0.85)
                                        .lineLimit(1)
                                }
                            }
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .padding(2)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(Self.spoken(block)))
                    .offset(y: block.start * height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
    }

    /// What a block writes, by its height in points (lines of 8 points for the name, 7 under it,
    /// padding included): its name from 14 (on two lines from 34, from 38 with its room), its room
    /// under the name from 24, its start time from 24 (from 30 under its room). Too short, it says nothing.
    static func lines(height: CGFloat, hasRoom: Bool) -> (title: Int, room: Bool, time: Bool) {
        guard height > 14 else { return (0, false, false) }
        guard hasRoom, height > 24 else { return (height > 34 ? 2 : 1, false, height > 24) }
        return (height > 38 ? 2 : 1, true, height > 30)
    }

    /// What VoiceOver says of a block: its name, its start time and its room, even when the block is
    /// too short to show them.
    static func spoken(_ block: ScheduleBlock) -> String {
        [block.title, block.time, block.room].compactMap { $0 }.joined(separator: ", ")
    }
}

struct HabitGrid: View {
    let names: [String]
    let rows: [[Bool?]]
    let colors: [String]
    let style: ResolvedStyle
    /// A medium widget holds three or four habits under its title and figure, not six (the last was cut off).
    var maxRows = 6

    var body: some View {
        let symbols = DateMath.weekdaySymbols()
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<7, id: \.self) { index in
                    Text(index < symbols.count ? symbols[index] : "")
                        .font(style.text(9, .medium))
                        .foregroundStyle(style.secondary)
                        .frame(width: 13)
                }
            }
            ForEach(Array(rows.prefix(max(1, maxRows)).enumerated()), id: \.offset) { pair in
                let color = style.isAccented ? style.chart : Color(hex: colors[safe: pair.offset] ?? "7FA33A")
                HStack(spacing: 3) {
                    Text(names[safe: pair.offset] ?? "")
                        .font(style.text(11))
                        .foregroundStyle(style.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(pair.element.prefix(7).enumerated()), id: \.offset) { day in
                        RoundedRectangle(cornerRadius: style.radius(3.5), style: .continuous)
                            .fill(day.element == true ? color : style.track.opacity(day.element == nil ? 0.45 : 1))
                            .frame(width: 13, height: 13)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SunArc: View {
    let progress: Double?
    let sunrise: String
    let sunset: String
    let compact: Bool
    let style: ResolvedStyle

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: 6, dy: 6)
                let center = CGPoint(x: rect.midX, y: rect.maxY)
                let radiusX = rect.width / 2
                let radiusY = rect.height
                ZStack {
                    Path { path in
                        for step in 0...40 {
                            let angle = Double.pi * (1 - Double(step) / 40)
                            let point = CGPoint(x: center.x + radiusX * CGFloat(cos(angle)), y: center.y - radiusY * CGFloat(sin(angle)))
                            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }
                    .stroke(style.track, style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                    Rectangle()
                        .fill(style.track)
                        .frame(height: 1)
                        .position(x: rect.midX, y: rect.maxY)
                    if let progress {
                        let angle = Double.pi * (1 - min(1, max(0, progress)))
                        Circle()
                            .fill(style.chart)
                            .frame(width: compact ? 10 : 14, height: compact ? 10 : 14)
                            .shadow(color: style.chart.opacity(0.6), radius: 6)
                            .position(x: center.x + radiusX * CGFloat(cos(angle)), y: center.y - radiusY * CGFloat(sin(angle)))
                    }
                }
            }
            if !compact {
                HStack {
                    Label(sunrise, systemImage: "sunrise.fill")
                    Spacer()
                    Label(sunset, systemImage: "sunset.fill")
                }
                .font(style.text(11, .medium))
                .foregroundStyle(style.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
    }
}

// MARK: - Lock Screen

struct TileAccessoryView: View {
    let tile: Tile
    let family: WidgetFamily
    /// False in app previews (see `TimerRing`).
    var isLive = true
    var now = Date()

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: inline
        }
    }

    @ViewBuilder private var circular: some View {
        if let timer = tile.timer {
            TimerRing(range: timer, symbol: tile.symbol, isLive: isLive, now: now)
        } else if let gauge = tile.gauge {
            Gauge(value: min(1, max(0, gauge))) {
                Image(systemName: tile.symbol)
            } currentValueLabel: {
                Text(tile.shortValue ?? tile.value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 3)
                    .privacySensitive(tile.isSensitive)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: tile.symbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text(tile.shortValue ?? tile.value)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .privacySensitive(tile.isSensitive)
                }
                .padding(4)
                .widgetAccentable()
            }
        }
    }

    /// The main action (« Série faite »…), usable right from the Lock Screen (iOS 17 interactive widgets).
    private var lockAction: TileButton? {
        // The small back arrow is never the Lock Screen's one action.
        tile.buttons.first(where: \.isProminent) ?? tile.buttons.first(where: { !$0.isIconOnly })
    }

    @ViewBuilder private var rectangular: some View {
        if !tile.lockColumns.isEmpty, tile.empty == nil {
            lockColumns
        } else {
            rectangularWithAction
        }
    }

    /// The title, then a few figures side by side, each with its bar (the macros).
    private var lockColumns: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(tile.title, systemImage: tile.symbol)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .widgetAccentable()
            HStack(alignment: .top, spacing: 8) {
                ForEach(tile.lockColumns) { column in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(column.title)
                                .font(.system(size: 11, weight: .bold))
                                .widgetAccentable()
                            Text(column.value ?? "")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .privacySensitive(column.isSensitive)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        if let progress = column.progress {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().opacity(0.3)
                                    Capsule()
                                        .frame(width: max(4, geo.size.width * min(1, max(0, progress))))
                                        .widgetAccentable()
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rectangularWithAction: some View {
        HStack(alignment: .center, spacing: 6) {
            rectangularText
            if let button = lockAction, button.action != .scanFood {
                TileActionButton(action: button.action, isEnabled: isLive) {
                    Image(systemName: button.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.22)))
                        .widgetAccentable()
                        .accessibilityLabel(Text(button.title))
                }
            }
        }
    }

    private var rectangularText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(tile.title, systemImage: tile.symbol)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .widgetAccentable()
            if let timer = tile.timer {
                Text(timerInterval: timer, countsDown: true)
                    .font(.system(.title3, design: .rounded).monospacedDigit())
            } else if tile.empty == nil && !tile.value.isEmpty {
                Text([tile.value, tile.unit].compactMap { $0 }.joined(separator: " "))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .privacySensitive(tile.isSensitive)
            }
            if let caption = tile.empty?.message ?? tile.caption {
                Text(caption)
                    .font(.caption)
                    .lineLimit(tile.empty == nil && !tile.value.isEmpty ? 1 : 3)
                    .minimumScaleFactor(0.75)
                    .privacySensitive(tile.isSensitive && tile.empty == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label(tile.inline ?? "\(tile.title) · \(tile.value)\(tile.unit.map { " " + $0 } ?? "")", systemImage: tile.symbol)
            .privacySensitive(tile.isSensitive)
    }
}

/// Circular countdown for the Lock Screen. WidgetKit animates `ProgressView(timerInterval:)`, but inside
/// the app the circular style is drawn as a spinner, so previews show a gauge set at the current time.
struct TimerRing: View {
    let range: ClosedRange<Date>
    let symbol: String
    let isLive: Bool
    var now = Date()

    var body: some View {
        if isLive {
            ProgressView(timerInterval: range, countsDown: true) {
                Image(systemName: symbol)
            } currentValueLabel: {
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
        } else {
            let total = max(1, range.upperBound.timeIntervalSince(range.lowerBound))
            let left = min(max(0, range.upperBound.timeIntervalSince(now)), total)
            Gauge(value: left / total) {
                Image(systemName: symbol)
            } currentValueLabel: {
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        }
    }
}

/// A line's name and its value side by side: when both don't fit, the value gives up its width first (smaller,
/// then cut) but the name always keeps at least half the line. Before, the value never shrank and could leave its
/// name a single letter (« D… 4 × 10 · 35 kg »).
struct RowSplit: Layout {
    var gap: CGFloat = 6

    private func finite(_ value: CGFloat) -> CGFloat { value.isFinite ? value : 0 }

    private func widths(_ width: CGFloat, _ subviews: Subviews) -> (title: CGFloat, value: CGFloat) {
        guard subviews.count > 1 else { return (width, 0) }
        let title = finite(subviews[0].sizeThatFits(.unspecified).width)
        let value = finite(subviews[1].sizeThatFits(.unspecified).width)
        let room = max(0, width - gap)
        guard room > 0 else { return (0, 0) }
        if title + value <= room { return (room - value, value) }
        let valueWidth = min(value, max(room - min(title, room * 0.5), room * 0.3))
        return (room - valueWidth, valueWidth)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.reduce(CGFloat(0)) { $0 + finite($1.sizeThatFits(.unspecified).width) } + (subviews.count > 1 ? gap : 0)
        // Measured without a limit (nil or infinite width), the line asks its natural width: an infinite answer
        // made SwiftUI measure again and again (the export froze, run 605).
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? ideal
        let (t, v) = widths(width, subviews)
        let heights = [subviews.first?.sizeThatFits(ProposedViewSize(width: t, height: proposal.height)).height ?? 0,
                       subviews.count > 1 ? subviews[1].sizeThatFits(ProposedViewSize(width: v, height: proposal.height)).height : 0]
        return CGSize(width: width, height: finite(heights.max() ?? 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (t, v) = widths(bounds.width.isFinite ? bounds.width : 0, subviews)
        subviews.first?.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: t, height: bounds.height))
        if subviews.count > 1 {
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: ProposedViewSize(width: v, height: bounds.height))
        }
    }
}
