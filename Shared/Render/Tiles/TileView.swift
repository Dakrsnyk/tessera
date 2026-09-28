import AppIntents
import SwiftUI
import WidgetKit

/// Lays out a `Tile` for every widget size, with the design's theme, colors and font.
struct TileView: View {
    let tile: Tile
    let context: RenderContext

    private var s: ResolvedStyle { context.style }

    var body: some View {
        if let empty = tile.empty {
            WidgetMessage(symbol: empty.symbol, title: empty.title, message: context.isSmall ? nil : empty.message, style: s)
        } else if context.isLarge {
            large
        } else if context.isMedium {
            medium
        } else {
            small
        }
    }

    // MARK: Pieces

    @ViewBuilder private var header: some View {
        if s.showsTitle {
            HStack(spacing: 5) {
                Image(systemName: tile.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(s.accent)
                WLabel(text: tile.title, style: s)
                Spacer(minLength: 0)
            }
        }
    }

    private var valueColor: Color {
        switch tile.trend {
        case .some(true): s.positive
        case .some(false): s.negative
        case .none: s.primary
        }
    }

    @ViewBuilder private func valueText(_ size: CGFloat, showsUnit: Bool = true) -> some View {
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

    // MARK: Small

    @ViewBuilder private var small: some View {
        if isRing, case let .ring(progress) = tile.visual {
            VStack(spacing: 6) {
                header
                Spacer(minLength: 0)
                ZStack {
                    RingView(progress: progress, lineWidth: 9, color: s.accent, track: s.track)
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
        } else if tile.compactRows && !tile.rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                header
                TileRowsView(rows: Array(tile.rows.prefix(4)), context: context, compact: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: s.horizontalAlignment, spacing: 3) {
                header
                Spacer(minLength: 2)
                if hasValue {
                    valueText(tile.value.count > 7 ? 26 : 34)
                }
                captionText(lines: hasValue ? (tile.buttons.isEmpty && !hasVisual ? 3 : 2) : 5)
                if !tile.buttons.isEmpty {
                    TileButtonsRow(buttons: Array(tile.buttons.prefix(2)), context: context)
                        .padding(.top, 6)
                } else if hasVisual {
                    TileVisualView(visual: tile.visual, context: context, compact: true)
                        .frame(height: 26)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .center : .bottomLeading)
        }
    }

    private var hasValue: Bool {
        !tile.value.isEmpty || tile.timer != nil
    }

    // MARK: Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            mediumBody
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
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

    @ViewBuilder private var mediumPanel: some View {
        if !tile.rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TileRowsView(rows: Array(tile.rows.prefix(tile.buttons.isEmpty ? 4 : 2)), context: context, compact: false)
                Spacer(minLength: 0)
                if !tile.buttons.isEmpty {
                    TileButtonsRow(buttons: Array(tile.buttons.prefix(2)), context: context)
                }
            }
        } else if !tile.buttons.isEmpty {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                if hasVisual {
                    TileVisualView(visual: tile.visual, context: context, compact: true)
                        .frame(height: 44)
                }
                TileButtonsColumn(buttons: Array(tile.buttons.prefix(3)), context: context)
            }
        } else if hasVisual {
            TileVisualView(visual: tile.visual, context: context, compact: false)
        } else {
            Color.clear
        }
    }

    // MARK: Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            VStack(alignment: .leading, spacing: 3) {
                if hasValue {
                    valueText(40)
                }
                captionText(lines: hasValue ? 3 : 6)
                detailText
            }
            if hasVisual {
                TileVisualView(visual: tile.visual, context: context, compact: !tile.rows.isEmpty && isSegments)
                    .frame(height: tile.rows.isEmpty ? 150 : (isSegments ? 14 : 86))
                    .clipped()
            }
            if !tile.rows.isEmpty {
                TileRowsView(rows: Array(tile.rows.prefix(hasVisual ? 5 : 8)), context: context, compact: false)
            }
            Spacer(minLength: 0)
            if !tile.buttons.isEmpty {
                TileButtonsRow(buttons: Array(tile.buttons.prefix(3)), context: context)
            }
            footnoteText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Rows

struct TileRowsView: View {
    let rows: [TileRow]
    let context: RenderContext
    let compact: Bool

    private var s: ResolvedStyle { context.style }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
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
        let color = row.colorHex.map { Color(hex: $0) } ?? s.accent
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                if let done = row.isDone {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: compact ? 13 : 15, weight: .medium))
                        .foregroundStyle(done ? color : s.secondary)
                } else if let symbol = row.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 10 : 12, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: compact ? 14 : 18)
                } else if row.colorHex != nil {
                    Circle().fill(color).frame(width: 7, height: 7)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.title)
                        .font(s.text(compact ? 12 : 13, row.isHighlighted ? .semibold : .regular))
                        .foregroundStyle(row.isDone == true ? s.secondary : s.primary)
                        .strikethrough(row.isDone == true, color: s.secondary)
                        // Short lists in small widgets have room for a second line.
                        .lineLimit(compact && rows.count <= 3 ? 2 : 1)
                        .minimumScaleFactor(0.8)
                    if let detail = row.detail, !compact {
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
                BarView(progress: progress, color: color, track: s.track, height: compact ? 3 : 4)
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
        }
    }
}

struct TileButtonLabel: View {
    let button: TileButton
    let style: ResolvedStyle
    var expands = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: button.symbol)
                .font(.system(size: 11, weight: .bold))
            Text(button.title)
                .font(style.text(12, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(button.isProminent ? style.onAccent : style.primary)
        .padding(.horizontal, 8)
        .frame(maxWidth: expands ? .infinity : nil, minHeight: 30)
        .background(button.isProminent ? style.accent : style.panel, in: Capsule())
    }
}

struct TileButtonsRow: View {
    let buttons: [TileButton]
    let context: RenderContext

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { pair in
                TileActionButton(action: pair.element.action, isEnabled: context.isInteractive) {
                    TileButtonLabel(button: pair.element, style: context.style)
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

    var body: some View {
        switch visual {
        case .none:
            EmptyView()
        case let .ring(progress):
            RingView(progress: progress, lineWidth: compact ? 5 : 10, color: s.accent, track: s.track)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .bar(progress):
            VStack {
                Spacer(minLength: 0)
                BarView(progress: progress, color: s.accent, track: s.track, height: compact ? 6 : 10)
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
        case let .symbol(name):
            Image(systemName: name)
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
                    .tint(s.accent)
            }
        }
    }
}

struct BarsChart: View {
    let values: [Double]
    let labels: [String]
    let highlight: Int?
    let style: ResolvedStyle

    var body: some View {
        let top = max(values.max() ?? 0, 0.000_1)
        VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: values.count > 14 ? 2 : 4) {
                    ForEach(Array(values.enumerated()), id: \.offset) { pair in
                        let ratio = max(0, pair.element) / top
                        RoundedRectangle(cornerRadius: values.count > 14 ? 1.5 : 3, style: .continuous)
                            .fill(pair.offset == highlight ? style.accent : style.accent.opacity(0.35))
                            .frame(height: max(3, geo.size.height * CGFloat(ratio)))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            if !labels.isEmpty {
                HStack(spacing: values.count > 14 ? 2 : 4) {
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
}

struct LineChart: View {
    let values: [Double]
    let style: ResolvedStyle

    var body: some View {
        ZStack {
            SparklineShape(values: values, closed: true)
                .fill(LinearGradient(colors: [style.accent.opacity(0.28), style.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            SparklineShape(values: values)
                .stroke(style.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
                .clipShape(Capsule())
            }
            .frame(height: 10)
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
                        Circle().fill(pair.element == true ? style.accent : style.track.opacity(pair.element == nil ? 0.5 : 1))
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
                                        .fill(marked.contains(day) ? style.accent : style.track)
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

struct HabitGrid: View {
    let names: [String]
    let rows: [[Bool?]]
    let colors: [String]
    let style: ResolvedStyle

    var body: some View {
        let symbols = DateMath.weekdaySymbols()
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<7, id: \.self) { index in
                    Text(index < symbols.count ? symbols[index] : "")
                        .font(style.text(9, .medium))
                        .foregroundStyle(style.secondary)
                        .frame(width: 16)
                }
            }
            ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { pair in
                let color = Color(hex: colors[safe: pair.offset] ?? "7FA33A")
                HStack(spacing: 4) {
                    Text(names[safe: pair.offset] ?? "")
                        .font(style.text(11))
                        .foregroundStyle(style.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(pair.element.prefix(7).enumerated()), id: \.offset) { day in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day.element == true ? color : style.track.opacity(day.element == nil ? 0.45 : 1))
                            .frame(width: 16, height: 16)
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
                            .fill(style.accent)
                            .frame(width: compact ? 10 : 14, height: compact ? 10 : 14)
                            .shadow(color: style.accent.opacity(0.6), radius: 6)
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
                    .minimumScaleFactor(0.5)
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

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(tile.title, systemImage: tile.symbol)
                .font(.headline)
                .lineLimit(1)
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
