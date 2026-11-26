#if DEBUG
import SwiftUI
import UIKit
import WidgetKit

/// Test builds: the pieces of the ad films exported by the app itself, as PNG files with true transparency,
/// at any scale, hundreds per launch (`-screenshotScreen export`, `[adkit]` in a commit message).
/// The CI copies scripts/ad_export.txt to Documents/ad_export.txt in the app's container, launches the app,
/// waits for Documents/export/done.txt (one line per job: type, name, files written, then « ok », the
/// renderer used or « error: <reason> ») and takes the whole Documents/export folder.
///
/// One job per line, `<type> <name> key=value…` (`%20` for a space in a value, `#` for a comment):
/// - `widget <name> kind= family=small|medium|large|rect|circular|inline [theme=] [preset=] [palette=]
///   [accent=HEX] [recolor=HEX] [template=] [scheme=light|dark] [ink=HEX] [scale=] [render=image|snapshot]`:
///   the widget as `WidgetPreview` draws it in the app, transparent around its rounded shape.
/// - `styles <name> [page=1] [per=20] kind= [family=small|medium|large] [scale=]`: a page of the style library as
///   the Studio's Style tab shows it (one picture; a page past the end writes no file and says so).
/// - `setupwidgets <name> setup= [wall=] [scale=]`: every widget of a Store setup as the setup draws it
///   (`<name>-<index>.png`, then the Lock Screen ones), and `<name>.json` (index, kind, family, place).
/// - `home <name> setup= [wall=]`, `lock <name> setup= [wall=]`, `wall <name> wall=`: the Store's screens
///   at 402 × 874 pt. `icons <name> setup=`: each app icon of the setup, one file each. `home` and
///   `setupwidgets` also take `rows= [theme=] [accent=]`: other widgets on the setup (see `storeSetup`).
/// - `live <name> [state=rest|paused|ready] [rest=|from= to=] [paused=] [routine= exercise= set= sets= load=
///   done= total= restTotal=] [bg=real|night|clear] [scheme=] [w=] [radius=] [scale=]`: the workout's Live
///   Activity (`WorkoutActivityView`, the view of the widget extension), one picture per second of rest
///   from `from` to `to`.
/// - `demo <name> exercise= [view=<index or name>] [fps=] [w= h=] [scale=] [bg=clear|card|fill] [scheme=] [accent=]`:
///   the exercise demonstration drawn by `DemoRenderer` at exact times (frame / fps), and `<name>.json`.
/// Any job also takes `courses=forest|forestSage|ink|mono|peach|rose|indigo|steel|ocean|sand`: the demo courses in the tones of a
/// Home Screen or of a widget style (StudentState.adCourseColors).
@MainActor
enum AdExport {
    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var folder: URL { documents.appendingPathComponent("export", isDirectory: true) }

    /// Every job of Documents/ad_export.txt, one after the other: a job that fails is written down and skipped.
    static func run() async {
        let files = FileManager.default
        try? files.createDirectory(at: folder, withIntermediateDirectories: true)
        try? files.removeItem(at: folder.appendingPathComponent("done.txt"))
        let text = (try? String(contentsOf: documents.appendingPathComponent("ad_export.txt"), encoding: .utf8)) ?? ""
        let rows = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        // `only a b c`: this run renders these pieces alone, so that a request for three new widgets does not render
        // the two hundred others again (an hour of CI). The last such line wins; `only all` renders everything.
        let only = rows.last { $0.hasPrefix("only ") }
            .map { Set($0.dropFirst(5).split(separator: " ").map(String.init)) }
            .flatMap { $0.contains("all") ? nil : $0 }
        let jobs = rows.filter { !$0.hasPrefix("only ") }
            .map(AdJob.init)
            .filter { only?.contains($0.name) ?? true }
        // The demo data, the app style and the first layout settle before the first picture.
        try? await Task.sleep(for: .seconds(3))
        var lines: [String] = []
        if jobs.isEmpty {
            lines.append("none\t-\t0\terror: Documents/ad_export.txt is missing or empty")
        }
        for job in jobs {
            // The job about to start, so that a job that never ends (a layout that loops) is named in the CI report.
            try? (lines + ["\(job.type)\t\(job.name)\t0\tstarted, not finished"]).joined(separator: "\n")
                .write(to: folder.appendingPathComponent("progress.txt"), atomically: true, encoding: .utf8)
            let line: String
            do {
                let outcome = try await perform(job)
                line = "\(job.type)\t\(job.name)\t\(outcome.files)\t\(outcome.note.isEmpty ? "ok" : outcome.note)"
            } catch let failure as AdFailure {
                line = "\(job.type)\t\(job.name)\t0\terror: \(failure.reason)"
            } catch {
                line = "\(job.type)\t\(job.name)\t0\terror: \(error.localizedDescription)"
            }
            lines.append(line)
            // What is done so far, should the CI stop waiting before the end.
            try? lines.joined(separator: "\n").write(to: folder.appendingPathComponent("progress.txt"), atomically: true, encoding: .utf8)
            try? await Task.sleep(for: .milliseconds(20))
        }
        try? (lines.joined(separator: "\n") + "\n").write(to: folder.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
    }

    private static func perform(_ job: AdJob) async throws -> AdOutcome {
        // `courses=forest`: the demo courses drawn in other colors for this job only (StudentState.adCourseColors).
        if let name = job.string("courses") {
            guard let colors = StudentState.adCourseColors(named: name) else { throw AdFailure("unknown course colors « \(name) »") }
            StudentState.adCourseColors = colors
        }
        defer { StudentState.adCourseColors = nil }
        switch job.type {
        case "widget": return try await widget(job)
        case "styles": return try await styles(job)
        case "setupwidgets": return try await setupWidgets(job)
        case "home": return try await screen(SetupHomeScreen(setup: storeSetup(job)), job)
        case "lock": return try await screen(SetupLockScreen(setup: storeSetup(job)), job)
        case "wall":
            guard let raw = job.string("wall"), let wallpaper = SetupWallpaper(rawValue: raw) else {
                throw AdFailure("unknown wallpaper « \(job.string("wall") ?? "") »")
            }
            return try await screen(SetupWallpaperView(wallpaper: wallpaper), job)
        case "icons": return try icons(job)
        case "live": return try await live(job)
        case "demo": return try await demo(job)
        default: throw AdFailure("unknown type « \(job.type) »")
        }
    }

    // MARK: - Widgets

    private static func family(_ name: String) -> WidgetFamily? {
        switch name {
        case "small": .systemSmall
        case "medium": .systemMedium
        case "large": .systemLarge
        case "rect": .accessoryRectangular
        case "circular": .accessoryCircular
        case "inline": .accessoryInline
        default: nil
        }
    }

    private static func familyName(_ family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: "small"
        case .systemMedium: "medium"
        case .systemLarge: "large"
        case .accessoryRectangular: "rect"
        case .accessoryCircular: "circular"
        case .accessoryInline: "inline"
        default: "other"
        }
    }

    /// When a job gives no scale: about 680 px for a small widget, 1 092 px for a medium one, 288 px for a round one.
    private static func defaultScale(_ family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemMedium, .systemLarge, .systemExtraLarge: 3
        default: 4
        }
    }

    private static func isHex(_ value: String) -> Bool {
        value.count == 6 && UInt32(value, radix: 16) != nil
    }

    /// A dark ink (for a light wallpaper) or a light one.
    private static func isDarkInk(_ hex: String) -> Bool {
        let value = UInt32(hex, radix: 16) ?? 0xFFFFFF
        let red = Double((value >> 16) & 0xFF), green = Double((value >> 8) & 0xFF), blue = Double(value & 0xFF)
        return (0.299 * red + 0.587 * green + 0.114 * blue) / 255 < 0.5
    }

    /// The design of a `widget` job, built the way the app builds one: a style (ThemeID), then a complete
    /// theme (StylePreset), a palette, a main color, as in the Studio.
    private static func design(_ job: AdJob) throws -> WidgetDesign {
        guard let raw = job.string("kind"), let kind = WidgetKind(rawValue: raw) else {
            throw AdFailure("unknown kind « \(job.string("kind") ?? "") »")
        }
        var design: WidgetDesign
        if let id = job.string("template") {
            guard let template = TemplateCatalog.template(id), template.kind == kind else {
                throw AdFailure("no template « \(id) » for \(kind.rawValue)")
            }
            design = template.makeDesign(now: MK.now)
        } else {
            design = WidgetDesign(kind: kind)
        }
        // A combined widget: `parts=nextSet+trainingStreak` (the kinds side by side, `kind` = the first one).
        if let spec = job.string("parts") {
            guard let parts = ComboPart.adParts(spec), parts[0].kind == kind else {
                throw AdFailure("parts « \(spec) » make no combined widget starting with \(kind.rawValue)")
            }
            design.options.parts = parts
        }
        if let raw = job.string("theme") {
            guard let theme = ThemeID(rawValue: raw) else { throw AdFailure("unknown theme « \(raw) »") }
            design.themeID = theme
        }
        if let hex = job.string("accent") {
            guard isHex(hex) else { throw AdFailure("accent « \(hex) » is not a 6-digit hex color") }
            design.accentHex = hex.uppercased()
        }
        if let id = job.string("preset") {
            guard let preset = StylePreset.preset(id) else { throw AdFailure("unknown preset « \(id) »") }
            design = preset.applied(to: design)
        }
        if let id = job.string("palette") {
            guard let palette = ColorPalette.palette(id) else { throw AdFailure("unknown palette « \(id) »") }
            design = palette.applied(to: design)
        }
        if let hex = job.string("recolor") {
            guard isHex(hex) else { throw AdFailure("recolor « \(hex) » is not a 6-digit hex color") }
            design = design.recolored(to: hex.uppercased())
        }
        return design
    }

    private static func widget(_ job: AdJob) async throws -> AdOutcome {
        let familyText = job.string("family") ?? "small"
        guard let widgetFamily = family(familyText) else { throw AdFailure("unknown family « \(familyText) »") }
        let widgetDesign = try design(job)
        guard widgetDesign.families.contains(widgetFamily) else {
            throw AdFailure("\(widgetDesign.kind.rawValue) has no \(familyText) size")
        }
        let size = WidgetMetrics.size(widgetFamily)
        let ink = job.string("ink").flatMap { isHex($0) ? $0 : nil }
        var payload = MK.payload(widgetDesign)
        // done=N (ads, 2026-11-20): the first N open tasks of the sample checked, the widget as it is just after a tap.
        if let done = job.args["done"].flatMap(Int.init), done > 0 {
            for index in payload.content.tasks.indices.filter({ !payload.content.tasks[$0].isDone }).prefix(done) {
                payload.content.tasks[index].isDone = true
                payload.content.tasks[index].completedAt = MK.now
            }
            // done=N also hands in the first N open assignments (Assignments widget): the widget just after a tap.
            for id in StudentMath.openAssignments(payload.domains.student).prefix(done).map(\.id) {
                payload.domains.student.toggleAssignment(id)
            }
        }
        // todo=N (ads, 2026-11-20): the last N habits done today unchecked, the Habits widget as it is just before a tap.
        if let todo = job.args["todo"].flatMap(Int.init), todo > 0 {
            for index in payload.content.habits.indices.filter({ payload.content.habits[$0].isDone(on: MK.now) }).suffix(todo) {
                payload.content.habits[index].toggle(on: MK.now)
            }
        }
        // spent=N (ads, 2026-11-20): the quick expense N of the sample (1 = the first) noted now, as QuickExpenseIntent does:
        // the Finances widgets just after a tap.
        if let spent = job.args["spent"].flatMap(Int.init), spent > 0, payload.domains.budget.quickExpenses.indices.contains(spent - 1) {
            let quick = payload.domains.budget.quickExpenses[spent - 1]
            payload.domains.budget.add(Expense(amount: quick.amount, categoryID: quick.categoryID, note: quick.name, date: MK.now))
        }
        // meal=photo (ads, 2026-11-22): the dish of the photo scan demo (`NutritionScreenshotStage.demoRecap`) logged now,
        // as « Add to log » of the recap does: the Nutrition widgets just after the scan.
        if job.string("meal") == "photo" {
            _ = NutritionScreenshotStage.demoRecap(photo: true).commit(into: &payload.domains.nutrition, meal: MealType.current(at: MK.now), at: MK.now)
        }
        // service=done (ads, 2026-11-22): the most advanced car service marked done now, as « Fait aujourd'hui » does in the Car mini-app.
        if job.string("service") == "done", let first = CarMath.serviceStatus(payload.domains.car, at: MK.now).first,
           let km = CarMath.odometer(payload.domains.car) {
            payload.domains.car.markServiceDone(first.item.id, km: km, at: MK.now)
        }
        // trip=ahead|ongoing (ads, 2026-11-20): the Travel sample before the departure or under way, whatever the kind.
        if let phase = job.string("trip") {
            payload.domains.travel = SampleData.travel(now: MK.now, ongoing: phase == "ongoing")
        }
        let view = WidgetPreview(
            design: widgetDesign, family: widgetFamily, payload: payload, width: size.width, date: MK.now,
            lockInk: ink.map { Color(hex: $0) } ?? .white, lockInkIsDark: ink.map { isDarkInk($0) } ?? false
        )
        .environment(\.colorScheme, widgetFamily.isAccessory ? .dark : job.scheme)
        // Lock Screen widgets have gauges and bars UIKit may draw: a real snapshot unless the job says otherwise.
        let usesSnapshot = job.string("render").map { $0 == "snapshot" } ?? widgetFamily.isAccessory
        let (drawn, renderer) = await picture(view, width: size.width, height: size.height, scale: job.scale(defaultScale(widgetFamily)), snapshot: usesSnapshot)
        try save(drawn, "\(job.name).png")
        return AdOutcome(files: 1, note: renderer)
    }

    // MARK: - Style board

    /// `styles <name> page=N per=20 kind= family=small|medium|large scale=`: page N of `StyleCatalog.all` as one picture,
    /// like the Studio's Style tab (2 columns, preview, name, summary, lock). A page past the end writes no file.
    private static func styles(_ job: AdJob) async throws -> AdOutcome {
        guard let raw = job.string("kind"), let kind = WidgetKind(rawValue: raw) else {
            throw AdFailure("unknown kind « \(job.string("kind") ?? "") »")
        }
        let familyText = job.string("family") ?? "small"
        guard let widgetFamily = family(familyText),
              let format = WidgetFormat.allCases.first(where: { $0.family == widgetFamily }) else {
            throw AdFailure("unknown family « \(familyText) »")
        }
        // `ids=a,b,c`: only these styles (a check board), in that order; else every style, by pages.
        let chosen = (job.string("ids") ?? "").split(separator: ",").compactMap { StyleCatalog.look(String($0)) }
        let source = chosen.isEmpty ? StyleCatalog.all : chosen
        let per = max(1, job.int("per", 20)), page = max(1, job.int("page", 1))
        let pages = (source.count + per - 1) / per
        guard page <= pages else { return AdOutcome(files: 0, note: "no page \(page): \(pages) pages of \(per) styles") }
        let looks = Array(source.dropFirst((page - 1) * per).prefix(per))
        // `cols=1` for medium widgets at their real width.
        let cols = max(1, job.int("cols", 2))
        let boardWidth: CGFloat = cols == 1 ? 370 : 402, margin: CGFloat = 16, gap: CGFloat = 10
        let columnWidth = (boardWidth - 2 * margin - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let rows = stride(from: 0, to: looks.count, by: cols).map { Array(looks[$0..<min($0 + cols, looks.count)]) }
        let board = VStack(alignment: .leading, spacing: 14) {
            Text("\(raw) · \(familyText) · page \(page)/\(pages)")
                .font(.headline)
            ForEach(rows.indices, id: \.self) { row in
                HStack(alignment: .top, spacing: gap) {
                    ForEach(rows[row]) { look in
                        let design = look.applied(to: WidgetDesign(kind: kind, format: format))
                        StudioPreviewTile(
                            design: design, family: widgetFamily, payload: MK.payload(design),
                            title: look.name, subtitle: chosen.isEmpty ? look.summary : look.id, isSelected: false,
                            showsLock: look.isPremium, width: columnWidth - 6
                        )
                        .frame(width: columnWidth)
                    }
                    if rows[row].count < cols { Color.clear.frame(width: columnWidth, height: 1) }
                }
            }
        }
        .padding(margin)
        .frame(width: boardWidth, alignment: .topLeading)
        .background(Color(uiColor: .systemGroupedBackground))
        .environment(\.colorScheme, .light)
        let (drawn, renderer) = await picture(board, width: boardWidth, height: nil, scale: job.scale(2), snapshot: true)
        try save(drawn, "\(job.name).png")
        return AdOutcome(files: 1, note: renderer)
    }

    // MARK: - Store setups

    /// A Store setup, on another wallpaper when `wall=` says so, with other widget rows when `rows=` says so:
    /// `rows=macros.medium|nextSet.medium|budgetLeft.small+priorities.small` (rows split by `|`, widgets of a
    /// row by `+`, each `kind.family`), in `theme=` and `accent=`, else the style of the setup's first widget.
    /// The film's hero Home Screen: real widgets on a real setup, drawn by the Store's own Home Screen.
    private static func storeSetup(_ job: AdJob) throws -> HomeSetup {
        guard let id = job.string("setup"), let base = HomeSetupCatalog.setup(id) ?? HomeSetupCatalog.adOnly.first(where: { $0.id == id }) else {
            throw AdFailure("unknown setup « \(job.string("setup") ?? "") »")
        }
        var wallpaper = base.wallpaper
        if let raw = job.string("wall") {
            guard let chosen = SetupWallpaper(rawValue: raw) else { throw AdFailure("unknown wallpaper « \(raw) »") }
            wallpaper = chosen
        }
        var rows = base.rows
        if let spec = job.string("rows") {
            let first = base.rows.flatMap(\.widgets).first
            var theme = first?.theme ?? .minimal
            if let raw = job.string("theme") {
                guard let chosen = ThemeID(rawValue: raw) else { throw AdFailure("unknown theme « \(raw) »") }
                theme = chosen
            }
            let accent = job.string("accent").flatMap { isHex($0) ? $0.uppercased() : nil } ?? first?.accent ?? "FF7A59"
            rows = try spec.split(separator: "|").map { row -> SetupRow in
                let widgets = try row.split(separator: "+").map { item -> SetupWidget in
                    let parts = item.split(separator: ".").map(String.init)
                    guard parts.count == 2, let kind = WidgetKind(rawValue: parts[0]), let size = family(parts[1]),
                          kind.families.contains(size) else {
                        throw AdFailure("bad widget « \(item) » in rows (kind.small|medium|large)")
                    }
                    return SetupWidget(kind: kind, family: size, theme: theme, accent: accent)
                }
                return .widgets(widgets)
            }
        }
        if job.string("wall") == nil && job.string("rows") == nil { return base }
        return HomeSetup(
            id: base.id, name: base.name, tagline: base.tagline, tags: base.tags, wallpaper: wallpaper,
            icons: base.icons, rows: rows, dock: base.dock, lock: base.lock
        )
    }

    /// A whole screen of the Store (402 × 874 pt, 1 206 × 2 622 px at scale 3).
    /// With `render=snapshot`, a real snapshot first: the rest bar of « Prochaine série » is a ProgressView,
    /// which ImageRenderer leaves as a yellow box.
    private static func screen<V: View>(_ view: V, _ job: AdJob) async throws -> AdOutcome {
        if job.string("render") == "snapshot" {
            let (drawn, renderer) = await picture(view, width: SetupScreen.size.width, height: SetupScreen.size.height, scale: job.scale(3), snapshot: true)
            try save(drawn, "\(job.name).png")
            return AdOutcome(files: 1, note: renderer)
        }
        try autoreleasepool {
            let rendered = image(view, width: SetupScreen.size.width, height: SetupScreen.size.height, scale: job.scale(3), opaque: true)
            try save(rendered, "\(job.name).png")
        }
        return AdOutcome(files: 1)
    }

    /// Each widget of a setup, drawn as `SetupHomeScreen` and `SetupLockScreen` draw it (without the
    /// shadow the Home Screen adds under it: black 8 % on a light wallpaper, 20 % otherwise, radius 8, y 3).
    private static func setupWidgets(_ job: AdJob) async throws -> AdOutcome {
        let setup = try storeSetup(job)
        var placed: [(widget: SetupWidget, place: String)] = setup.rows.flatMap(\.widgets).map { (widget: $0, place: "home") }
        placed += setup.lock.widgets.map { (widget: $0, place: "lock") }
        if let inline = setup.lock.inline { placed.append((widget: inline, place: "lock-inline")) }
        let scheme: ColorScheme = setup.wallpaper.isLight ? .light : .dark
        var entries: [[String: Any]] = []
        var failures: [String] = []
        for (index, item) in placed.enumerated() {
            let widget = item.widget
            let widgetDesign = widget.makeDesign()
            let size = WidgetMetrics.size(widget.family)
            let isLock = item.place != "home"
            let scale = job.args["scale"] == nil ? defaultScale(widget.family) : job.scale(3)
            let view = WidgetPreview(
                design: widgetDesign, family: widget.family,
                payload: SamplePayload.make(for: widgetDesign, now: SetupScreen.now),
                width: size.width, date: SetupScreen.now,
                lockInk: isLock ? setup.ink : .white, lockInkIsDark: isLock && setup.wallpaper.isLight
            )
            .environment(\.colorScheme, scheme)
            let file = "\(job.name)-\(index).png"
            let usesSnapshot = widget.family.isAccessory || job.string("render") == "snapshot"
            let (drawn, renderer) = await picture(view, width: size.width, height: size.height, scale: scale, snapshot: usesSnapshot)
            do {
                try save(drawn, file)
            } catch {
                failures.append(file)
                continue
            }
            entries.append([
                "index": index, "file": file, "kind": widget.kind.rawValue, "family": familyName(widget.family),
                "place": item.place, "theme": widget.theme.rawValue, "accent": widget.accent,
                "template": widget.template ?? "", "scale": Double(scale), "renderer": renderer,
                "width": Double(size.width * scale), "height": Double(size.height * scale),
            ])
        }
        try writeJSON([
            "setup": setup.id, "wallpaper": setup.wallpaper.rawValue, "widgets": entries,
            "shadow": "Home Screen widgets: black \(setup.wallpaper.isLight ? 8 : 20) %, radius 8 pt, y 3 pt (not in the PNG)",
        ], "\(job.name).json")
        return AdOutcome(files: entries.count + 1, note: failures.isEmpty ? "ok" : "not drawn: \(failures.joined(separator: ", "))")
    }

    /// The app icons of a setup (rows and dock), one file each, drawn by `SetupAppIcon`: the Home Screen
    /// view itself can't leave its widgets out, so the icons come alone, with their places in the JSON.
    private static func icons(_ job: AdJob) throws -> AdOutcome {
        let setup = try storeSetup(job)
        var apps: [(app: SetupApp, place: String)] = []
        for (index, row) in setup.rows.enumerated() {
            switch row {
            case let .widgetAndApps(_, rowApps, _): apps += rowApps.map { (app: $0, place: "row-\(index)") }
            case let .apps(rowApps): apps += rowApps.map { (app: $0, place: "row-\(index)") }
            case .widgets: break
            }
        }
        apps += setup.dock.map { (app: $0, place: "dock") }
        let side: CGFloat = 62
        // Room around the icon for its own shadow.
        let margin: CGFloat = 6
        let scale = job.scale(4)
        var entries: [[String: Any]] = []
        for (index, item) in apps.enumerated() {
            let file = "\(job.name)-\(index).png"
            try autoreleasepool {
                let view = SetupAppIcon(app: item.app, style: setup.icons, size: side)
                    .padding(margin)
                    .environment(\.colorScheme, setup.wallpaper.isLight ? .light : .dark)
                try save(image(view, width: side + margin * 2, height: side + margin * 2, scale: scale), file)
            }
            entries.append(["index": index, "file": file, "name": item.app.name, "symbol": item.app.symbol, "place": item.place])
        }
        try writeJSON(["setup": setup.id, "iconSize": Double(side), "margin": Double(margin), "scale": Double(scale), "icons": entries], "\(job.name).json")
        return AdOutcome(files: apps.count + 1, note: "icons one by one (SetupHomeScreen can't hide its widgets)")
    }

    // MARK: - Live Activity

    private static func liveBackground(_ name: String) throws -> AnyShapeStyle {
        switch name {
        // The tint the Lock Screen gives the activity (WorkoutLiveActivityWidget: activityBackgroundTint).
        case "real":
            return AnyShapeStyle(WorkoutActivityView.background)
        // The night gradient of the preview in the app (LockScreenCreator, MarketingLiveActivity).
        case "night":
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: "1C2566"), Color(hex: "4A1628")], startPoint: .topLeading, endPoint: .bottomTrailing))
        case "clear":
            return AnyShapeStyle(Color.clear)
        default:
            throw AdFailure("unknown background « \(name) » (real, night, clear)")
        }
    }

    private static func live(_ job: AdJob) async throws -> AdOutcome {
        let state = job.string("state") ?? (job.args["paused"] != nil ? "paused" : (job.args["rest"] != nil || job.args["from"] != nil ? "rest" : "ready"))
        // The seconds of rest left in each picture (nil: no rest running).
        var rests: [Double?]
        switch state {
        case "rest":
            if let from = job.args["from"].flatMap(Double.init) {
                let to = job.number("to", 0)
                guard from >= to, to >= 0, from - to <= 600 else { throw AdFailure("from= must be ≥ to= ≥ 0, 600 s apart at most") }
                rests = stride(from: from, through: to, by: -1).map { Optional($0) }
            } else {
                rests = [job.number("rest", 84)]
            }
        case "paused", "ready":
            rests = [nil]
        default:
            throw AdFailure("unknown state « \(state) » (rest, paused, ready)")
        }
        let background = try liveBackground(job.string("bg") ?? "real")
        let scheme: ColorScheme = job.args["scheme"] == "light" ? .light : .dark
        let attributes = WorkoutActivityAttributes(routineName: job.string("routine") ?? tr("Haut du corps"))
        let restTotal = max(1, job.number("restTotal", 120))
        let now = MK.now
        let width = CGFloat(job.number("w", 372))
        let radius = CGFloat(job.number("radius", 24))
        let scale = job.scale(3)
        var frames: [[String: Any]] = []
        var renderers: Set<String> = []
        for (index, rest) in rests.enumerated() {
            let content = WorkoutActivityAttributes.ContentState(
                exercise: job.string("exercise") ?? tr("Développé couché"),
                setNumber: job.int("set", 3),
                sets: job.int("sets", 4),
                load: job.string("load") ?? tr("\(8) × \(60) kg"),
                doneSets: job.int("done", 2),
                totalSets: job.int("total", 14),
                restStart: rest.map { now.addingTimeInterval($0 - restTotal) },
                restEnd: rest.map { now.addingTimeInterval($0) },
                restPaused: state == "paused" ? job.number("paused", 45) : nil
            )
            // style=ruby (any AppStyleID name): the activity in that app style, as a Premium user who chose it sees it.
            let styleOverride = try job.string("style").map { name -> AppStyle in
                guard let id = AppStyleID(named: name) else { throw AdFailure("unknown app style « \(name) »") }
                return AppStyle.style(id)
            }
            let view = WorkoutActivityView(attributes: attributes, state: content, isLive: false, now: now, styleOverride: styleOverride)
                .frame(width: width)
                .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .environment(\.colorScheme, scheme)
            let file = rests.count > 1 ? "\(job.name)-" + String(format: "%03d", index) + ".png" : "\(job.name).png"
            // The bar of sets done is a ProgressView, which ImageRenderer can't draw: a real snapshot first.
            let usesSnapshot = job.string("render").map { $0 == "snapshot" } ?? true
            let (drawn, renderer) = await picture(view, width: width, height: nil, scale: scale, snapshot: usesSnapshot)
            try save(drawn, file)
            renderers.insert(renderer)
            frames.append(["index": index, "file": file, "rest": rest ?? -1])
        }
        if rests.count > 1 {
            try writeJSON(["fps": 1, "state": state, "background": job.string("bg") ?? "real", "frames": frames], "\(job.name).json")
        }
        return AdOutcome(files: rests.count + (rests.count > 1 ? 1 : 0), note: renderers.sorted().joined(separator: "+"))
    }

    // MARK: - Exercise demonstrations

    /// The angle: an index (0, 1…) or the name the app shows under the figure (« Profil », « 3/4 », « Face »…).
    private static func demoView(_ value: String?, _ animation: DemoModel) throws -> Int {
        guard let value else { return 0 }
        if let index = animation.views.firstIndex(where: { $0.name.lowercased() == value.lowercased() }) { return index }
        if let index = Int(value), animation.views.indices.contains(index) { return index }
        throw AdFailure("\(animation.id) has no view « \(value) » (\(animation.views.map(\.name).joined(separator: ", ")))")
    }

    @ViewBuilder
    private static func demoBackground(_ kind: String, _ palette: DemoPalette) -> some View {
        switch kind {
        // The rounded card of the exercise sheet (ExerciseDemoView).
        case "card": RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.background)
        case "fill": Rectangle().fill(palette.background)
        default: Color.clear
        }
    }

    /// One picture of a demonstration: the figure at phase p, as the exercise sheet's Canvas draws it.
    private static func demoFrame(_ animation: DemoModel, p: Double, view viewIndex: Int, width: CGFloat, height: CGFloat,
                                  scale: CGFloat, background: String, palette: DemoPalette, file: String) throws {
        try autoreleasepool {
            let canvas = Canvas { context, size in
                DemoRenderer.draw(animation, p: p, view: viewIndex, in: &context, size: size, palette: palette)
            }
            .frame(width: width, height: height)
            .background { demoBackground(background, palette) }
            try save(image(canvas, width: width, height: height, scale: scale), file)
        }
    }

    private static func demo(_ job: AdJob) async throws -> AdOutcome {
        guard let id = job.string("exercise"), let animation = ExerciseDemos.demo(for: id) else {
            throw AdFailure("no demonstration for « \(job.string("exercise") ?? "") »")
        }
        let fps = min(120, max(1, job.number("fps", 60)))
        let viewIndex = try demoView(job.string("view"), animation)
        let width = CGFloat(job.number("w", 402))
        let height = CGFloat(job.number("h", 236))
        let scale = job.scale(3)
        let backgroundKind = job.string("bg") ?? "clear"
        let palette = DemoPalette(scheme: job.scheme, accentHex: job.string("accent") ?? MiniApp.fitness.colorHex)
        // One loop of the movement: frame i shows the figure at i / fps seconds (no clock involved).
        let count = max(1, Int((animation.duration * fps).rounded()))
        guard count <= 3000 else { throw AdFailure("\(count) frames: lower fps") }
        var frames: [[String: Any]] = []
        for frame in 0..<count {
            let seconds = Double(frame) / fps
            let phase = animation.phase(at: seconds)
            let file = "\(job.name)-" + String(format: "%04d", frame) + ".png"
            try demoFrame(animation, p: phase.p, view: viewIndex, width: width, height: height, scale: scale,
                          background: backgroundKind, palette: palette, file: file)
            frames.append([
                "index": frame, "file": file, "t": seconds, "p": phase.p,
                "label": phase.label ?? -1, "phase": phase.label.map { animation.labels[$0] } ?? "",
            ])
            if frame % 24 == 23 { try? await Task.sleep(for: .milliseconds(5)) }
        }
        try writeJSON([
            "exercise": id, "view": animation.views[viewIndex].name, "fps": fps, "duration": animation.duration,
            "frames": count, "loop": animation.loop, "labels": animation.labels, "scheme": job.scheme == .dark ? "dark" : "light",
            "background": backgroundKind, "width": Double(width * scale), "height": Double(height * scale), "frame": frames,
        ], "\(job.name).json")
        return AdOutcome(files: count + 1)
    }

    // MARK: - Drawing and writing

    /// A SwiftUI view drawn by ImageRenderer (as HomeSetupSheet saves its wallpaper), `scale` pixels per point,
    /// transparent where nothing is drawn. Without a height, the view takes its own.
    private static func image<V: View>(_ view: V, width: CGFloat, height: CGFloat?, scale: CGFloat, opaque: Bool = false) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = scale
        renderer.isOpaque = opaque
        return renderer.uiImage
    }

    /// A real snapshot of the view, drawn by UIKit in a window behind the app (what the screen would show),
    /// for views with parts UIKit draws (a linear ProgressView), which ImageRenderer leaves as a placeholder.
    private static func snapshot<V: View>(_ view: V, width: CGFloat, height: CGFloat?, scale: CGFloat) async -> UIImage? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        let fitted = host.sizeThatFits(in: CGSize(width: width, height: height ?? .greatestFiniteMagnitude))
        let size = CGSize(width: width, height: ceil(height ?? fitted.height))
        guard size.height > 0, size.height < 4000 else { return nil }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.frame = CGRect(origin: .zero, size: size)
        window.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        try? await Task.sleep(for: .milliseconds(350))
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        var didDraw = false
        let shot = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            didDraw = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        return didDraw && !isBlank(shot) ? shot : nil
    }

    /// The snapshot when asked and it worked, else ImageRenderer; and which one drew it.
    private static func picture<V: View>(_ view: V, width: CGFloat, height: CGFloat?, scale: CGFloat, snapshot: Bool) async -> (UIImage?, String) {
        if snapshot, let shot = await Self.snapshot(view, width: width, height: height, scale: scale) {
            return (shot, "snapshot")
        }
        return (image(view, width: width, height: height, scale: scale), snapshot ? "image (snapshot failed)" : "image")
    }

    /// True when nothing is drawn in a picture (a snapshot taken before the view reached the screen).
    private static func isBlank(_ rendered: UIImage) -> Bool {
        guard let cgImage = rendered.cgImage else { return true }
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let isDrawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard isDrawn else { return true }
        return stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 0 }
    }

    private static func save(_ rendered: UIImage?, _ file: String) throws {
        guard let data = rendered?.pngData() else { throw AdFailure("nothing drawn for \(file)") }
        try data.write(to: folder.appendingPathComponent(file))
    }

    private static func writeJSON(_ object: [String: Any], _ file: String) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: folder.appendingPathComponent(file))
    }
}

/// One line of Documents/ad_export.txt: `<type> <name> key=value…`.
struct AdJob {
    let type: String
    let name: String
    let args: [String: String]

    init(_ line: String) {
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        type = tokens.first ?? ""
        // The name becomes a file name: no folder, no space.
        let raw = tokens.count > 1 ? tokens[1] : "unnamed"
        name = raw.replacingOccurrences(of: "/", with: "-")
        var args: [String: String] = [:]
        for token in tokens.dropFirst(2) {
            let pair = token.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { args[pair[0]] = pair[1].removingPercentEncoding ?? pair[1] }
        }
        self.args = args
    }

    func string(_ key: String) -> String? {
        guard let value = args[key], !value.isEmpty else { return nil }
        return value
    }

    func number(_ key: String, _ fallback: Double) -> Double { args[key].flatMap(Double.init) ?? fallback }
    func int(_ key: String, _ fallback: Int) -> Int { args[key].flatMap(Int.init) ?? fallback }
    var scheme: ColorScheme { args["scheme"] == "dark" ? .dark : .light }

    /// Pixels per point, 1 to 8.
    func scale(_ fallback: CGFloat) -> CGFloat {
        CGFloat(min(8, max(1, number("scale", Double(fallback)))))
    }
}

/// What a job wrote: the files, and a word on how (the renderer used, what was left out).
struct AdOutcome {
    var files: Int
    var note: String = ""
}

extension ComboPart {
    /// Ads: the parts of a combined widget from its kinds (`nextSet+trainingStreak`), each one small, with the demo
    /// content the Store combos use. Nil when they don't fill a medium or a large widget.
    static func adParts(_ spec: String) -> [ComboPart]? {
        let kinds = spec.split(separator: "+").compactMap { WidgetKind(rawValue: String($0)) }
        guard kinds.count >= 2 else { return nil }
        let parts = kinds.map { kind in
            let base = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
            return ComboPart(kind: kind, options: base.options, name: kind.title, size: .small)
        }
        return ComboLayout.format(parts) == nil ? nil : parts
    }
}

/// Why a job wrote nothing (written in done.txt).
struct AdFailure: Error {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }
}
#endif
