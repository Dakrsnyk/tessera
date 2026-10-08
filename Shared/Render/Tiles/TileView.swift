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
        self.tile = context.style.filtered(tile)
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
            case .minimal: minimalLayout
            case .centered: centeredLayout
            case .split: splitLayout
            case .data: dataLayout
            case .list: listLayout
            case .progress: progressLayout
            case .graph: graphLayout
            case .cards: cardsLayout
            }
        }
    }

    /// The chosen layout, or the closest one that has what it needs.
    private var effectiveLayout: LayoutKind {
        switch s.options.layout {
        case .progress: progressFraction == nil ? .vertical : .progress
        case .graph: hasVisual || !tile.rows.isEmpty ? .graph : .vertical
        case .list: tile.rows.isEmpty ? .vertical : .list
        // Two columns of lines don't fit in a small widget: its chart can, its lines can't.
        case .split: context.isSmall && !(hasVisual && tile.rows.isEmpty) ? .vertical : .split
        case let layout: layout
        }
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
        let button = context.allowsLinks ? tile.headerButton : nil
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
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(tile.value)
                        .font(s.number(size))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
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
    }

    @ViewBuilder private func captionText(lines: Int) -> some View {
        if let caption = tile.caption {
            Text(caption)
                .font(s.text(12))
                .foregroundStyle(s.secondary)
                .lineLimit(lines)
                .multilineTextAlignment(s.textAlignment)
        }
    }

    @ViewBuilder private var detailText: some View {
        if let detail = tile.detail, s.showsDetails {
            Text(detail)
                .font(s.text(11, .medium))
                .foregroundStyle(s.secondary)
                .lineLimit(2)
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

    private var isRing: Bool {
        if case .ring = tile.visual { return true }
        return false
    }

    private var isSegments: Bool {
        if case .segments = tile.visual { return true }
        return false
    }

    private var hasVisual: Bool {
        if case .none = tile.visual { return false }
        return true
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

    private func visual(compact: Bool) -> some View {
        TileVisualView(visual: tile.visual, context: context, compact: compact)
            .styleDepth(s)
    }

    /// A card inside the widget, with the shape and depth of the style.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(8 * sp)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(s.panel, in: RoundedRectangle(cornerRadius: s.radius(12), style: .continuous))
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
                    RingView(progress: progress, lineWidth: 9 * CGFloat(s.options.chartThickness), color: s.chart, track: s.options.chartFill ? s.track : .clear)
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
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tile.compactRows && !tile.rows.isEmpty && !prefersChosenChart {
            VStack(alignment: .leading, spacing: 6 * sp) {
                headerBlock
                TileRowsView(rows: rows(4), context: context, compact: true)
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
                        .frame(height: chosenChartIsRound ? 64 : (isRing ? 44 : 26))
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

    @ViewBuilder private var mediumPanel: some View {
        if prefersChosenChart && tile.buttons.isEmpty {
            visual(compact: false)
        } else if !tile.rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TileRowsView(rows: rows(mediumRowLimit), context: context, compact: false)
                Spacer(minLength: 0)
                if !tile.buttons.isEmpty {
                    TileButtonsRow(buttons: Array(tile.buttons.prefix(2)), context: context)
                }
            }
        } else if !tile.buttons.isEmpty {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                if hasVisual {
                    visual(compact: true)
                        .frame(height: 44)
                }
                TileButtonsColumn(buttons: Array(tile.buttons.prefix(3)), context: context)
            }
        } else if hasVisual {
            visual(compact: false)
        } else {
            Color.clear
        }
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
                visual(compact: !tile.rows.isEmpty && isSegments && s.options.chart == .auto)
                    .frame(height: tile.rows.isEmpty ? 150 : (isSegments && s.options.chart == .auto ? 14 : 86))
                    .clipped()
            }
            if !tile.rows.isEmpty {
                TileRowsView(rows: rows(hasVisual ? 5 : 8), context: context, compact: false)
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

    private var verticalLayout: some View {
        let valueSize: CGFloat = context.isSmall ? 30 : (context.isLarge ? 46 : 34)
        let chartHeight: CGFloat = context.isSmall ? 30 : (context.isLarge ? 120 : 42)
        return VStack(alignment: s.horizontalAlignment, spacing: 5 * sp) {
            headerBlock
            if hasValue { valueText(tile.value.count > 7 ? valueSize * 0.8 : valueSize) }
            captionText(lines: context.isSmall ? 2 : 3)
            if !context.isSmall { detailText }
            if hasVisual && (tile.buttons.isEmpty || !context.isSmall) {
                visual(compact: context.isSmall)
                    .frame(height: chartHeight)
                    .frame(maxWidth: .infinity)
            }
            if context.isLarge && !tile.rows.isEmpty {
                TileRowsView(rows: rows(hasVisual ? 4 : 7), context: context, compact: false)
            } else if context.isMedium && !hasVisual && !tile.rows.isEmpty {
                TileRowsView(rows: rows(2), context: context, compact: true)
            }
            Spacer(minLength: 0)
            buttonsRow(context.isSmall ? 2 : 3)
            if context.isLarge { footnoteText }
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
                    captionText(lines: context.isSmall ? 2 : 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let progress = progressFraction {
                    miniProgress(progress)
                        .frame(width: context.isSmall ? 46 : 60, height: context.isSmall ? 46 : 60)
                } else if let values = tile.visual.seriesValues {
                    SeriesLineChart(values: values, style: s, fillOpacity: 0, lineWidth: 2, showsEndDot: true)
                        .frame(width: context.isSmall ? 50 : 96, height: context.isSmall ? 30 : 44)
                        .styleDepth(s)
                }
            }
            if context.isLarge {
                if hasVisual && progressFraction == nil && tile.visual.seriesValues == nil {
                    visual(compact: false).frame(height: 110)
                }
                if !tile.rows.isEmpty {
                    TileRowsView(rows: rows(5), context: context, compact: false)
                }
            } else if context.isMedium && !tile.rows.isEmpty && tile.buttons.isEmpty {
                TileRowsView(rows: rows(1), context: context, compact: true)
            }
            Spacer(minLength: 0)
            if !context.isSmall { buttonsRow(3) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A small ring (or the chosen progress chart) next to the value.
    @ViewBuilder private func miniProgress(_ progress: Double) -> some View {
        switch s.options.chart {
        case .pie: ProgressPieChart(progress: progress, style: s)
        case .gauge: GaugeArcChart(progress: progress, style: s, lineWidth: 6 * CGFloat(s.options.chartThickness))
        default:
            ZStack {
                RingView(progress: progress, lineWidth: 6 * CGFloat(s.options.chartThickness), color: s.chart, track: s.options.chartFill ? s.track : .clear)
                if s.options.chartValues {
                    Text(Fmt.percent(progress)).font(s.text(10, .semibold).monospacedDigit()).foregroundStyle(s.primary)
                }
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
            if hasValue && !context.isSmall {
                captionText(lines: 1)
            }
            if context.isLarge { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .center : .bottomLeading)
    }

    // MARK: Focus: icon and value at the center

    private var centeredLayout: some View {
        VStack(spacing: 5 * sp) {
            Spacer(minLength: 0)
            if showsIcon {
                StyledIcon(symbol: tile.symbol, style: s, size: context.isSmall ? 16 : 20)
            }
            if hasValue { valueText(context.isSmall ? 30 : (context.isLarge ? 52 : 38)) }
            if s.showsTitle { WLabel(text: tile.title, style: s) }
            if !context.isSmall {
                captionText(lines: 2)
            }
            if context.isLarge, let progress = progressFraction {
                BarView(progress: progress, color: s.chart, track: s.track, height: 8 * CGFloat(s.options.chartThickness), radius: s.radius(4))
                    .frame(maxWidth: 200)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Two columns

    private var splitLayout: some View {
        HStack(alignment: .top, spacing: 10 * sp) {
            VStack(alignment: .leading, spacing: 3 * sp) {
                headerBlock
                Spacer(minLength: 0)
                if hasValue { valueText(context.isSmall ? 22 : (context.isLarge ? 36 : 30)) }
                captionText(lines: context.isLarge ? 4 : 2)
                if context.isLarge { detailText }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Rectangle()
                .fill(s.secondary.opacity(0.25))
                .frame(width: 1)
            VStack(alignment: .leading, spacing: 6 * sp) {
                if !tile.rows.isEmpty {
                    TileRowsView(rows: rows(context.isSmall ? 3 : (context.isLarge ? 9 : 4)), context: context, compact: !context.isLarge)
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
        let columns = context.isSmall ? 1 : (context.isLarge ? 2 : 3)
        let limit = max(1, (context.isSmall ? 2 : (context.isLarge ? 8 : 3)) + (context.isSmall ? 0 : s.rowDelta))
        let shown = Array(stats.prefix(limit))
        let chunks = stride(from: 0, to: shown.count, by: columns).map { Array(shown[$0..<min($0 + columns, shown.count)]) }
        return VStack(alignment: .leading, spacing: 8 * sp) {
            headerBlock
            if context.isSmall { Spacer(minLength: 0) }
            Grid(alignment: .leading, horizontalSpacing: 12 * sp, verticalSpacing: 10 * sp) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { chunk in
                    GridRow {
                        ForEach(chunk.element) { stat in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.labelText(stat.label))
                                    .font(s.label(9))
                                    .tracking(s.labelTracking * 0.6)
                                    .foregroundStyle(s.secondary)
                                    .lineLimit(1)
                                Text(stat.value)
                                    .font(s.number(stat.id == "value" ? (context.isSmall ? 26 : 22) : (context.isSmall ? 17 : 18)))
                                    .foregroundStyle(stat.color ?? s.numberColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .styleDepth(s)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if chunk.offset < chunks.count - 1 {
                        Rectangle().fill(s.secondary.opacity(0.18)).frame(height: 1).gridCellUnsizedAxes(.horizontal)
                    }
                }
            }
            if !context.isSmall, hasVisual {
                visual(compact: context.isMedium)
                    .frame(maxHeight: context.isLarge ? 110 : 30)
            }
            Spacer(minLength: 0)
            if context.isLarge { buttonsRow(3) }
            if context.isLarge { footnoteText }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                }
            }
            TileRowsView(rows: rows(context.isSmall ? 4 : (context.isLarge ? 10 : 4)), context: context, compact: context.isSmall)
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
                if !withProgress.isEmpty {
                    TileRowsView(rows: Array(withProgress.prefix(4 + s.rowDelta)), context: context, compact: false)
                        .padding(.top, 6)
                } else if !tile.rows.isEmpty {
                    TileRowsView(rows: rows(4), context: context, compact: false)
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
        VStack(alignment: .leading, spacing: 6 * sp) {
            headerBlock
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if hasValue { valueText(context.isSmall ? 22 : (context.isLarge ? 36 : 26)) }
                if !context.isSmall {
                    captionText(lines: 1)
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
            } else if hasVisual {
                visual(compact: context.isSmall)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TileRowsView(rows: rows(context.isLarge ? 8 : 3), context: context, compact: !context.isLarge)
                Spacer(minLength: 0)
            }
            if context.isLarge, hasVisual, !tile.rows.isEmpty {
                TileRowsView(rows: rows(3), context: context, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Cards: each information on its own card

    private var cardsLayout: some View {
        let others = Array(stats.filter { $0.id != "value" }.prefix(max(0, (context.isLarge ? 4 : (context.isMedium ? 2 : 1)) + (context.isSmall ? 0 : s.rowDelta / 2))))
        return VStack(alignment: .leading, spacing: 6 * sp) {
            if !context.isSmall { headerBlock }
            if context.isMedium {
                HStack(spacing: 6 * sp) {
                    mainCard.frame(maxWidth: .infinity)
                    ForEach(others) { statCard($0) }
                    if others.isEmpty && hasVisual {
                        card { visual(compact: true) }
                    }
                }
            } else {
                mainCard
                if context.isLarge && hasVisual {
                    card { visual(compact: false) }
                        .frame(maxHeight: 110)
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
                Spacer(minLength: 0)
                if hasValue { valueText(context.isSmall ? 26 : (context.isLarge ? 34 : 24)) }
                captionText(lines: 1)
            }
        }
    }

    private func statCard(_ stat: Stat) -> some View {
        card {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.label)
                    .font(s.text(10, .medium))
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(stat.value)
                    .font(s.number(context.isSmall ? 15 : 16))
                    .foregroundStyle(stat.color ?? s.numberColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
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
        let rowColor = row.colorHex.map { Color(hex: $0) }
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
                Spacer(minLength: 4)
                if let value = row.value {
                    Text(value)
                        .font(s.text(compact ? 11 : 12, .semibold).monospacedDigit())
                        .foregroundStyle(row.isHighlighted ? s.accent : s.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .layoutPriority(1)
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
        case .completeSet:
            IntentButton(intent: CompleteSetIntent(), isEnabled: isEnabled, label: label)
        case .skipRest:
            IntentButton(intent: SkipRestIntent(), isEnabled: isEnabled, label: label)
        case let .logFood(id):
            IntentButton(intent: LogFoodIntent(foodID: id), isEnabled: isEnabled, label: label)
        case let .quickExpense(id):
            IntentButton(intent: QuickExpenseIntent(expenseID: id), isEnabled: isEnabled, label: label)
        case let .counter(id, delta):
            IntentButton(intent: CounterStepIntent(counterID: id, delta: delta), isEnabled: isEnabled, label: label)
        case let .togglePriority(id):
            IntentButton(intent: TogglePriorityIntent(priorityID: id), isEnabled: isEnabled, label: label)
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
        case .addWater:
            IntentButton(intent: AddWaterIntent(glasses: 1), isEnabled: isEnabled, label: label)
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
        .background(button.isProminent ? style.accent : style.panel, in: RoundedRectangle(cornerRadius: style.radius(15), style: .continuous))
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
        .background(style.accent, in: RoundedRectangle(cornerRadius: style.radius(12), style: .continuous))
        .accessibilityLabel(Text(button.title))
    }
}

struct TileButtonsRow: View {
    let buttons: [TileButton]
    let context: RenderContext

    /// Two buttons don't fit side by side with text in a small widget.
    private var isTight: Bool { context.isSmall && buttons.count > 1 }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { pair in
                let iconOnly = isTight && !pair.element.isProminent
                TileActionButton(action: pair.element.action, isEnabled: context.isInteractive) {
                    TileButtonLabel(button: pair.element, style: context.style, expands: !iconOnly, iconOnly: iconOnly)
                }
            }
        }
    }
}

struct TileButtonsColumn: View {
    let buttons: [TileButton]
    let context: RenderContext

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { pair in
                TileActionButton(action: pair.element.action, isEnabled: context.isInteractive) {
                    TileButtonLabel(button: pair.element, style: context.style)
                }
            }
        }
    }
}

// MARK: - Visuals

struct TileVisualView: View {
    let visual: TileVisual
    let context: RenderContext
    let compact: Bool

    private var s: ResolvedStyle { context.style }
    private var thickness: CGFloat { CGFloat(s.options.chartThickness) }

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
            ZStack {
                RingView(progress: progress, lineWidth: (compact ? 5 : 10) * thickness, color: s.chart, track: s.options.chartFill ? s.track : .clear)
                if s.options.chartValues && !compact {
                    Text(Fmt.percent(progress)).font(s.number(18)).foregroundStyle(s.numberColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .bar(progress):
            VStack {
                Spacer(minLength: 0)
                let height = (compact ? 6 : 10) * thickness
                BarView(progress: progress, color: s.chart, track: s.track, height: height, radius: s.radius(height / 2))
            }
        case let .bars(values, labels, highlight):
            BarsChart(values: values, labels: compact ? [] : labels, highlight: highlight, style: s)
        case let .line(values):
            LineChart(values: values, style: s)
        case let .segments(segments):
            SegmentsChart(segments: segments, showsLegend: !compact, style: s)
        case let .week(days):
            WeekStrip(days: days, showsLabels: !compact, style: s)
        case let .month(days, offset, marked, today):
            MonthDots(days: days, offset: offset, marked: marked, today: today, style: s)
        case let .grid(names, rows, colors):
            HabitGrid(names: names, rows: rows, colors: colors, style: s)
        case let .schedule(blocks, today):
            ScheduleWeek(blocks: blocks, today: today, style: s)
        case let .symbol(name):
            Image(systemName: s.symbol(name))
                .resizable()
                .scaledToFit()
                .foregroundStyle(s.primary)
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
        let showsValues = s.options.chartValues && !compact
        switch kind {
        case .line:
            SeriesLineChart(values: values, style: s, fillOpacity: s.options.chartFill ? 0.18 : 0, lineWidth: 2 * thickness, showsEndDot: showsValues, showsEndValue: showsValues)
        case .area:
            SeriesLineChart(values: values, style: s, fillOpacity: s.options.chartFill ? 0.5 : 0.25, lineWidth: 1.5 * thickness, showsEndValue: showsValues)
        case .bars:
            BarsChart(values: values, labels: [], highlight: values.indices.last, style: s, showsValues: showsValues)
        case .histogram:
            BarsChart(values: values, labels: [], highlight: values.indices.last, style: s, showsValues: showsValues, spacing: 1, corner: 0.5)
        case .dots:
            SeriesDotsChart(values: values, style: s, dotSize: (compact ? 4 : 6) * thickness)
        case .sparkline:
            SeriesLineChart(values: values, style: s, fillOpacity: 0, lineWidth: 1.4 * thickness, showsEndDot: true, showsEndValue: showsValues)
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
        let showsValues = s.options.chartValues && !compact
        switch kind {
        case .ring:
            ZStack {
                RingView(progress: value, lineWidth: (compact ? 5 : 10) * thickness, color: s.chart, track: s.options.chartFill ? s.track : .clear)
                if showsValues {
                    Text(Fmt.percent(value)).font(s.number(18)).foregroundStyle(s.numberColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .pie:
            ProgressPieChart(progress: value, style: s, showsValue: showsValues)
        case .gauge:
            GaugeArcChart(progress: value, style: s, lineWidth: (compact ? 5 : 10) * thickness, showsValue: showsValues)
        case .progress:
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                if showsValues {
                    Text(Fmt.percent(value)).font(s.text(12, .bold).monospacedDigit()).foregroundStyle(s.chart)
                }
                let height = (compact ? 8 : 14) * thickness
                BarView(progress: value, color: s.chart, track: s.options.chartFill ? s.track : s.track.opacity(0.4), height: height, radius: s.radius(height / 2))
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
            SegmentsRoundChart(segments: segments, style: s, hole: 0.62, showsLegend: !compact)
        case .pie:
            SegmentsRoundChart(segments: segments, style: s, hole: 0, showsLegend: !compact)
        case .bars:
            SegmentsBarsChart(segments: segments, style: s)
        default:
            SegmentsChart(segments: segments, showsLegend: !compact, style: s)
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
        let labelled = showsValues && values.count <= 10
        VStack(spacing: 4) {
            GeometryReader { geo in
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
            if !labels.isEmpty {
                HStack(spacing: gap) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { pair in
                        let shown = labels.count <= 8 || pair.offset % 3 == 0 || pair.offset == highlight
                        Text(shown ? pair.element : " ")
                            .font(style.text(9, pair.offset == highlight ? .bold : .regular))
                            .foregroundStyle(pair.offset == highlight ? style.primary : style.secondary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(maxWidth: .infinity)
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

    var body: some View {
        let total = max(segments.reduce(0) { $0 + max(0, $1.value) }, 0.000_1)
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { pair in
                        Rectangle()
                            .fill(Color(hex: pair.element.colorHex))
                            .frame(width: max(2, (geo.size.width - CGFloat(segments.count) * 2) * CGFloat(max(0, pair.element.value) / total)))
                    }
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: style.radius(5 * CGFloat(style.options.chartThickness)), style: .continuous))
            }
            .frame(height: 10 * CGFloat(style.options.chartThickness))
            if showsLegend {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(segments.prefix(5).enumerated()), id: \.offset) { pair in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: pair.element.colorHex)).frame(width: 7, height: 7)
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
                        RoundedRectangle(cornerRadius: style.options.shape == .square ? 3 : 999, style: .continuous)
                            .fill(pair.element == true ? style.chart : style.track.opacity(pair.element == nil ? 0.5 : 1))
                        if pair.element == true {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(style.onAccent)
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

/// The week's schedule in a large widget: a column a day, each entry a block in its color, with its
/// name when the block is tall enough.
struct ScheduleWeek: View {
    let blocks: [ScheduleBlock]
    let today: Int?
    let style: ResolvedStyle

    var body: some View {
        let symbols = DateMath.weekdaySymbols()
        HStack(alignment: .top, spacing: 3) {
            ForEach(0..<7, id: \.self) { day in
                VStack(spacing: 3) {
                    Text(day < symbols.count ? symbols[day] : "")
                        .font(style.text(9, day == today ? .bold : .medium))
                        .foregroundStyle(day == today ? style.chart : style.secondary)
                    GeometryReader { proxy in
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: style.radius(4), style: .continuous)
                                .fill(style.track.opacity(day == today ? 1 : 0.5))
                            ForEach(Array(blocks.filter { $0.day == day }.enumerated()), id: \.offset) { item in
                                let block = item.element
                                let height = max(4, (block.end - block.start) * proxy.size.height)
                                RoundedRectangle(cornerRadius: style.radius(3), style: .continuous)
                                    .fill(Color(hex: block.colorHex))
                                    .frame(height: height)
                                    .overlay(alignment: .topLeading) {
                                        if height > 18 {
                                            Text(block.title)
                                                .font(.system(size: 7, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(height > 30 ? 2 : 1)
                                                .minimumScaleFactor(0.7)
                                                .padding(2)
                                        }
                                    }
                                    .offset(y: block.start * proxy.size.height)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct HabitGrid: View {
    let names: [String]
    let rows: [[Bool?]]
    let colors: [String]
    let style: ResolvedStyle

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
            ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { pair in
                let color = Color(hex: colors[safe: pair.offset] ?? "7FA33A")
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
                }
                .padding(4)
                .widgetAccentable()
            }
        }
    }

    /// The main action (« Série faite »…), usable right from the Lock Screen (iOS 17 interactive widgets).
    private var lockAction: TileButton? {
        tile.buttons.first(where: \.isProminent) ?? tile.buttons.first
    }

    private var rectangular: some View {
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
            }
            if let caption = tile.empty?.message ?? tile.caption {
                Text(caption)
                    .font(.caption)
                    .lineLimit(tile.empty == nil && !tile.value.isEmpty ? 1 : 3)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label(tile.inline ?? "\(tile.title) · \(tile.value)\(tile.unit.map { " " + $0 } ?? "")", systemImage: tile.symbol)
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
