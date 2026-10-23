import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// Draws SYNTHETIC timetables (invented subjects and teachers, no personal data) the way the real ones look, so that the
// real Vision can read them in ScheduleRealOCRTests. Each page is drawn from a list of `SyntheticClass`; the expected
// result is computed from the same list, so the drawing and the answer cannot drift apart.

/// One class of a synthetic timetable.
struct SyntheticClass {
    let weekday: Int
    let startMinute: Int
    let endMinute: Int
    let title: String
    let code: String
    let room: String
    let teacher: String

    var expected: ExpectedSlot {
        ExpectedSlot(weekday: weekday, startMinute: startMinute, endMinute: endMinute, title: title, room: room)
    }
}

/// What the importer should find for a class (ISO weekday, minutes since midnight).
struct ExpectedSlot {
    let weekday: Int
    let startMinute: Int
    let endMinute: Int
    let title: String
    let room: String
}

/// A drawn page and the answer.
struct RenderedSchedule {
    let name: String
    let image: UIImage
    let expected: [ExpectedSlot]
}

/// Ways to degrade a clean rendering, like a real screenshot or photo.
enum ScheduleVariant: String, CaseIterable {
    case clean = "propre"
    case blurred = "flou"
    case tilted = "incline"
    case jpeg = "jpeg"
    case dark = "sombre"
}

enum ScheduleRenderer {
    /// The layouts, in the order they are drawn.
    static let names = ["omnivox", "encadres", "semaine", "liste", "tableau"]

    static func all() -> [RenderedSchedule] { names.compactMap(make) }

    static func make(_ name: String) -> RenderedSchedule? {
        switch name {
        case "omnivox": return omnivoxGrid()
        case "encadres": return boxedBlocks()
        case "semaine": return weekView()
        case "liste": return dayList()
        case "tableau": return table()
        default: return nil
        }
    }

    static let dayNames = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]

    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    private static func at(_ hour: Int, _ minute: Int = 0) -> Int { hour * 60 + minute }

    private static let green = UIColor(red: 0.10, green: 0.62, blue: 0.22, alpha: 1)

    // MARK: (a) Omnivox-like grid

    private struct PeriodClass {
        let weekday: Int
        let firstRow: Int
        let lastRow: Int
        let title: String
        let code: String
        let room: String
        let teacher: String
    }

    /// White blocks of 1 to 3 rows on light grey empty cells, hour pairs (start / end of the period) in the margin and
    /// a « Liste des cours » above the grid.
    private static func omnivoxGrid() -> RenderedSchedule {
        let periods: [(start: Int, end: Int)] = [
            (at(8, 10), at(9, 0)), (at(9, 5), at(9, 55)), (at(10, 5), at(10, 55)), (at(11, 0), at(11, 50)),
            (at(13, 0), at(13, 50)), (at(13, 55), at(14, 45)), (at(14, 55), at(15, 45)), (at(15, 50), at(16, 40))
        ]
        let classes: [PeriodClass] = [
            PeriodClass(weekday: 1, firstRow: 0, lastRow: 1, title: "Physique mécanique", code: "203-PHY-03 gr.41070", room: "F5107", teacher: "Durand, Alix"),
            PeriodClass(weekday: 1, firstRow: 4, lastRow: 6, title: "Calcul différentiel", code: "201-CAL-03 gr.41012", room: "A2203", teacher: "Morel, Sam"),
            PeriodClass(weekday: 2, firstRow: 2, lastRow: 2, title: "Anglais langue seconde", code: "604-ANG-03 gr.41033", room: "G1012", teacher: "Lopez, Jade"),
            PeriodClass(weekday: 2, firstRow: 5, lastRow: 6, title: "Chimie des solutions", code: "202-CHI-03 gr.41045", room: "F5110", teacher: "Girard, Noé"),
            PeriodClass(weekday: 3, firstRow: 0, lastRow: 2, title: "Philosophie et rationalité", code: "340-PHI-03 gr.41051", room: "B3015", teacher: "Roy, Camille"),
            PeriodClass(weekday: 3, firstRow: 4, lastRow: 4, title: "Éducation physique", code: "109-EPS-03 gr.41060", room: "C0101", teacher: "Petit, Léo"),
            PeriodClass(weekday: 4, firstRow: 1, lastRow: 2, title: "Calcul différentiel", code: "201-CAL-03 gr.41012", room: "A2203", teacher: "Morel, Sam"),
            PeriodClass(weekday: 4, firstRow: 5, lastRow: 7, title: "Littérature et imaginaire", code: "601-LET-03 gr.41077", room: "D4008", teacher: "Faure, Inès"),
            PeriodClass(weekday: 5, firstRow: 0, lastRow: 1, title: "Physique mécanique", code: "203-PHY-03 gr.41070", room: "F5107", teacher: "Durand, Alix"),
            PeriodClass(weekday: 5, firstRow: 3, lastRow: 3, title: "Anglais langue seconde", code: "604-ANG-03 gr.41033", room: "G1012", teacher: "Lopez, Jade")
        ]
        var seen = Set<String>()
        let courses = classes.filter { seen.insert($0.code).inserted }

        let width: CGFloat = 1200
        let margin: CGFloat = 100
        let columnWidth = (width - margin - 12) / 5
        let rowHeight: CGFloat = 112
        let listTop: CGFloat = 24
        let listHeight = 52 + CGFloat(courses.count) * 30
        let headerTop = listTop + listHeight + 24
        let gridTop = headerTop + 48
        let height = gridTop + CGFloat(periods.count) * rowHeight + 30

        let image = render(width: width, height: height) { ctx in
            Pen.text("Liste des cours", at: CGRect(x: 24, y: listTop, width: 600, height: 34), font: UIFont.boldSystemFont(ofSize: 26))
            for (index, course) in courses.enumerated() {
                let rect = CGRect(x: 24, y: listTop + 52 + CGFloat(index) * 30, width: width - 48, height: 26)
                Pen.text("\(course.code)   \(course.title)", at: rect, font: UIFont.systemFont(ofSize: 18))
            }
            for day in 0..<5 {
                let x = margin + CGFloat(day) * columnWidth
                Pen.text(dayNames[day], at: CGRect(x: x, y: headerTop + 6, width: columnWidth, height: 30),
                         font: UIFont.boldSystemFont(ofSize: 21), align: .center)
                for row in 0..<periods.count {
                    let cell = CGRect(x: x + 1, y: gridTop + CGFloat(row) * rowHeight + 1, width: columnWidth - 2, height: rowHeight - 2)
                    Pen.fill(ctx, cell, UIColor(white: 0.89, alpha: 1))
                }
            }
            let small = UIFont.systemFont(ofSize: 14)
            for (row, period) in periods.enumerated() {
                let top = gridTop + CGFloat(row) * rowHeight
                Pen.text(clock(period.start), at: CGRect(x: 0, y: top + 2, width: margin - 10, height: 20), font: small,
                         color: UIColor(white: 0.25, alpha: 1), align: .right)
                Pen.text(clock(period.end), at: CGRect(x: 0, y: top + rowHeight - 24, width: margin - 10, height: 20), font: small,
                         color: UIColor(white: 0.25, alpha: 1), align: .right)
            }
            for course in classes {
                let rows = course.lastRow - course.firstRow + 1
                let x = margin + CGFloat(course.weekday - 1) * columnWidth
                let block = CGRect(x: x + 1, y: gridTop + CGFloat(course.firstRow) * rowHeight + 1,
                                   width: columnWidth - 2, height: CGFloat(rows) * rowHeight - 2)
                Pen.fill(ctx, block, .white)
                Pen.stroke(ctx, block, UIColor(white: 0.78, alpha: 1), width: 1)
                var runs: [(text: String, font: UIFont, color: UIColor)] = [
                    (course.title, UIFont.boldSystemFont(ofSize: 15), UIColor.black),
                    (course.code, small, UIColor.black),
                    ("Local \(course.room)", small, UIColor.black)
                ]
                if rows >= 2 { runs.append((course.teacher, small, UIColor.darkGray)) }
                runs.append(("Présentiel", small, green))
                Pen.stack(runs, in: block)
            }
        }
        let expected = classes.map { course in
            SyntheticClass(weekday: course.weekday, startMinute: periods[course.firstRow].start, endMinute: periods[course.lastRow].end,
                           title: course.title, code: course.code, room: course.room, teacher: course.teacher).expected
        }
        return RenderedSchedule(name: "omnivox", image: image, expected: expected)
    }

    // MARK: (b) Framed blocks (university planner)

    /// White rectangles with a thick black outline on a thin grey grid, a mark every 30 minutes in the margin, tiny
    /// centred text and a green hand-made annotation drawn over one of the blocks.
    private static func boxedBlocks() -> RenderedSchedule {
        let classes: [SyntheticClass] = [
            SyntheticClass(weekday: 1, startMinute: at(8, 30), endMinute: at(10, 30), title: "Chimie générale (T)", code: "202-C01-HU g.00001", room: "2.547", teacher: "Vidal, K"),
            SyntheticClass(weekday: 1, startMinute: at(13, 0), endMinute: at(15, 0), title: "Statistiques (L)", code: "201-S02-HU g.00002", room: "1.112", teacher: "Moreau, T"),
            SyntheticClass(weekday: 2, startMinute: at(9, 0), endMinute: at(10, 0), title: "Histoire de l'art (T)", code: "530-H03-HU g.00001", room: "3.208", teacher: "Garnier, P"),
            SyntheticClass(weekday: 2, startMinute: at(14, 0), endMinute: at(17, 0), title: "Atelier de dessin (L)", code: "510-D01-HU g.00003", room: "A.201", teacher: "Lemoine, R"),
            SyntheticClass(weekday: 3, startMinute: at(8, 0), endMinute: at(10, 0), title: "Chimie générale (L)", code: "202-C01-HU g.00004", room: "2.601", teacher: "Vidal, K"),
            SyntheticClass(weekday: 3, startMinute: at(10, 30), endMinute: at(12, 30), title: "Initiation à la linguistique (T)", code: "601-L05-HU g.00001", room: "3.115", teacher: "Perrin, E"),
            SyntheticClass(weekday: 4, startMinute: at(9, 0), endMinute: at(12, 0), title: "Statistiques (T)", code: "201-S02-HU g.00001", room: "1.112", teacher: "Moreau, T"),
            SyntheticClass(weekday: 4, startMinute: at(16, 0), endMinute: at(18, 0), title: "Théâtre (L)", code: "551-T01-HU g.00002", room: "B.010", teacher: "Colin, M"),
            SyntheticClass(weekday: 5, startMinute: at(10, 0), endMinute: at(12, 0), title: "Histoire de l'art (L)", code: "530-H03-HU g.00002", room: "3.208", teacher: "Garnier, P"),
            SyntheticClass(weekday: 5, startMinute: at(13, 30), endMinute: at(15, 30), title: "Atelier de dessin (T)", code: "510-D01-HU g.00001", room: "A.201", teacher: "Lemoine, R")
        ]
        let width: CGFloat = 1500
        let margin: CGFloat = 100
        let columnWidth = (width - margin - 10) / 5
        let unit: CGFloat = 32 // points per 30 minutes
        let firstMinute = at(8)
        let halfHours = (at(22) - firstMinute) / 30
        let top: CGFloat = 96
        let height = top + CGFloat(halfHours) * unit + 30
        let shortDays = ["Lun.", "Mar.", "Mer.", "Jeu.", "Ven."]
        func y(_ minute: Int) -> CGFloat { top + CGFloat(minute - firstMinute) / 30 * unit }

        let image = render(width: width, height: height) { ctx in
            let grid = UIColor(white: 0.82, alpha: 1)
            for day in 0..<5 {
                let x = margin + CGFloat(day) * columnWidth
                Pen.text("\(shortDays[day]) \(26 + day) août",
                         at: CGRect(x: x, y: 40, width: columnWidth, height: 28), font: UIFont.boldSystemFont(ofSize: 19), align: .center)
                Pen.line(ctx, from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: y(at(22))), color: grid, width: 1)
            }
            Pen.line(ctx, from: CGPoint(x: margin + 5 * columnWidth, y: top), to: CGPoint(x: margin + 5 * columnWidth, y: y(at(22))), color: grid, width: 1)
            for step in 0...halfHours {
                let minute = firstMinute + step * 30
                Pen.line(ctx, from: CGPoint(x: margin, y: y(minute)), to: CGPoint(x: margin + 5 * columnWidth, y: y(minute)), color: grid, width: 1)
                Pen.text(clock(minute), at: CGRect(x: 0, y: y(minute) - 9, width: margin - 12, height: 20),
                         font: UIFont.systemFont(ofSize: 14), color: UIColor(white: 0.25, alpha: 1), align: .right)
            }
            let tiny = UIFont.systemFont(ofSize: 12)
            var annotated: CGRect?
            for (index, course) in classes.enumerated() {
                let x = margin + CGFloat(course.weekday - 1) * columnWidth
                let block = CGRect(x: x + 3, y: y(course.startMinute), width: columnWidth - 6, height: y(course.endMinute) - y(course.startMinute))
                Pen.fill(ctx, block, .white)
                Pen.stroke(ctx, block, .black, width: 4)
                Pen.stack([
                    (course.title, tiny, UIColor.black),
                    (course.code, tiny, UIColor.black),
                    (course.room, tiny, UIColor.black),
                    (course.teacher, tiny, UIColor.black)
                ], in: block)
                if index == 5 { annotated = block }
            }
            // The green annotation, over the text of one block.
            if let block = annotated {
                Pen.stroke(ctx, block.insetBy(dx: 12, dy: 6), green, width: 3)
                Pen.text("à confirmer", at: CGRect(x: block.minX + 20, y: block.maxY - 30, width: block.width - 40, height: 24),
                         font: UIFont.italicSystemFont(ofSize: 18), color: green, align: .center)
            }
        }
        return RenderedSchedule(name: "encadres", image: image, expected: classes.map { $0.expected })
    }

    // MARK: (c) Calendar week view

    /// Coloured blocks with the title, the hours and the room, hour lines in the margin.
    private static func weekView() -> RenderedSchedule {
        let classes: [SyntheticClass] = [
            SyntheticClass(weekday: 1, startMinute: at(9, 0), endMinute: at(10, 30), title: "Algèbre linéaire", code: "", room: "B204", teacher: ""),
            SyntheticClass(weekday: 1, startMinute: at(13, 0), endMinute: at(15, 0), title: "Programmation Python", code: "", room: "L3", teacher: ""),
            SyntheticClass(weekday: 2, startMinute: at(8, 30), endMinute: at(10, 0), title: "Économie politique", code: "", room: "C110", teacher: ""),
            SyntheticClass(weekday: 2, startMinute: at(10, 30), endMinute: at(12, 0), title: "Biologie cellulaire", code: "", room: "D220", teacher: ""),
            SyntheticClass(weekday: 3, startMinute: at(9, 0), endMinute: at(12, 0), title: "Programmation Python", code: "", room: "L3", teacher: ""),
            SyntheticClass(weekday: 4, startMinute: at(8, 30), endMinute: at(10, 0), title: "Algèbre linéaire", code: "", room: "B204", teacher: ""),
            SyntheticClass(weekday: 4, startMinute: at(14, 0), endMinute: at(16, 0), title: "Biologie cellulaire", code: "", room: "D220", teacher: ""),
            SyntheticClass(weekday: 5, startMinute: at(10, 0), endMinute: at(11, 30), title: "Économie politique", code: "", room: "C110", teacher: "")
        ]
        let colors = [
            UIColor(red: 0.16, green: 0.40, blue: 0.80, alpha: 1), UIColor(red: 0.80, green: 0.38, blue: 0.10, alpha: 1),
            UIColor(red: 0.18, green: 0.50, blue: 0.30, alpha: 1), UIColor(red: 0.50, green: 0.25, blue: 0.62, alpha: 1)
        ]
        let titles = Array(Set(classes.map { $0.title })).sorted()
        let width: CGFloat = 1200
        let margin: CGFloat = 90
        let columnWidth = (width - margin - 10) / 5
        let top: CGFloat = 100
        let hourHeight: CGFloat = 72
        let height = top + 11 * hourHeight + 30
        let shortDays = ["Lun", "Mar", "Mer", "Jeu", "Ven"]
        func y(_ minute: Int) -> CGFloat { top + CGFloat(minute - at(8)) / 60 * hourHeight }

        let image = render(width: width, height: height) { ctx in
            let grid = UIColor(white: 0.85, alpha: 1)
            for day in 0..<5 {
                let x = margin + CGFloat(day) * columnWidth
                Pen.text("\(shortDays[day]) \(26 + day)", at: CGRect(x: x, y: 40, width: columnWidth, height: 28),
                         font: UIFont.boldSystemFont(ofSize: 20), align: .center)
                Pen.line(ctx, from: CGPoint(x: x, y: top - 10), to: CGPoint(x: x, y: y(at(19))), color: grid, width: 1)
            }
            for hour in 8...18 {
                Pen.line(ctx, from: CGPoint(x: margin - 8, y: y(at(hour))), to: CGPoint(x: width - 10, y: y(at(hour))), color: grid, width: 1)
                Pen.text("\(hour):00", at: CGRect(x: 0, y: y(at(hour)) - 9, width: margin - 14, height: 20),
                         font: UIFont.systemFont(ofSize: 15), color: UIColor(white: 0.35, alpha: 1), align: .right)
            }
            for course in classes {
                let x = margin + CGFloat(course.weekday - 1) * columnWidth
                let block = CGRect(x: x + 3, y: y(course.startMinute) + 1, width: columnWidth - 6, height: y(course.endMinute) - y(course.startMinute) - 2)
                Pen.fill(ctx, block, colors[(titles.firstIndex(of: course.title) ?? 0) % colors.count])
                Pen.stack([
                    (course.title, UIFont.boldSystemFont(ofSize: 16), UIColor.white),
                    ("\(clock(course.startMinute)) – \(clock(course.endMinute))", UIFont.systemFont(ofSize: 14), UIColor.white),
                    ("Salle \(course.room)", UIFont.systemFont(ofSize: 14), UIColor.white)
                ], in: block)
            }
        }
        return RenderedSchedule(name: "semaine", image: image, expected: classes.map { $0.expected })
    }

    // MARK: (d) Day by day list

    private static let listClasses: [SyntheticClass] = [
        SyntheticClass(weekday: 1, startMinute: at(8, 30), endMinute: at(10, 0), title: "Droit des affaires", code: "", room: "B204", teacher: ""),
        SyntheticClass(weekday: 1, startMinute: at(13, 0), endMinute: at(16, 0), title: "Comptabilité financière", code: "", room: "C110", teacher: ""),
        SyntheticClass(weekday: 2, startMinute: at(10, 0), endMinute: at(12, 0), title: "Marketing numérique", code: "", room: "D220", teacher: ""),
        SyntheticClass(weekday: 3, startMinute: at(8, 30), endMinute: at(10, 0), title: "Droit des affaires", code: "", room: "B204", teacher: ""),
        SyntheticClass(weekday: 3, startMinute: at(14, 0), endMinute: at(15, 30), title: "Gestion de projet", code: "", room: "A105", teacher: ""),
        SyntheticClass(weekday: 4, startMinute: at(9, 0), endMinute: at(12, 0), title: "Comptabilité financière", code: "", room: "C110", teacher: ""),
        SyntheticClass(weekday: 5, startMinute: at(10, 30), endMinute: at(12, 0), title: "Marketing numérique", code: "", room: "D220", teacher: ""),
        SyntheticClass(weekday: 5, startMinute: at(13, 30), endMinute: at(15, 0), title: "Gestion de projet", code: "", room: "A105", teacher: "")
    ]

    /// A heading per day, then « 08:30 – 10:00  Title » and « Salle B204 » under it.
    private static func dayList() -> RenderedSchedule {
        let classes = listClasses
        let width: CGFloat = 1000
        var height: CGFloat = 130
        for day in 1...5 {
            let count = classes.filter { $0.weekday == day }.count
            if count > 0 { height += 62 + CGFloat(count) * 76 + 14 }
        }
        let image = render(width: width, height: height) { ctx in
            Pen.text("Mon horaire de session", at: CGRect(x: 40, y: 30, width: width - 80, height: 44), font: UIFont.boldSystemFont(ofSize: 36))
            var y: CGFloat = 110
            for day in 1...5 {
                let items = classes.filter { $0.weekday == day }.sorted { $0.startMinute < $1.startMinute }
                guard !items.isEmpty else { continue }
                Pen.text(dayNames[day - 1], at: CGRect(x: 40, y: y, width: width - 80, height: 40), font: UIFont.boldSystemFont(ofSize: 30), color: green)
                y += 52
                Pen.line(ctx, from: CGPoint(x: 40, y: y - 6), to: CGPoint(x: width - 40, y: y - 6), color: UIColor(white: 0.8, alpha: 1), width: 1)
                for item in items {
                    Pen.text("\(clock(item.startMinute)) – \(clock(item.endMinute))   \(item.title)",
                             at: CGRect(x: 40, y: y, width: width - 80, height: 34), font: UIFont.systemFont(ofSize: 27))
                    Pen.text("Salle \(item.room)", at: CGRect(x: 60, y: y + 36, width: width - 100, height: 30),
                             font: UIFont.systemFont(ofSize: 22), color: UIColor(white: 0.4, alpha: 1))
                    y += 76
                }
                y += 24
            }
        }
        return RenderedSchedule(name: "liste", image: image, expected: classes.map { $0.expected })
    }

    // MARK: (e) Table « Jour | Début | Fin | Matière | Salle »

    private static func table() -> RenderedSchedule {
        let classes: [SyntheticClass] = [
            SyntheticClass(weekday: 1, startMinute: at(8, 30), endMinute: at(10, 0), title: "Anatomie humaine", code: "", room: "S101", teacher: ""),
            SyntheticClass(weekday: 1, startMinute: at(10, 15), endMinute: at(11, 45), title: "Soins de base", code: "", room: "S204", teacher: ""),
            SyntheticClass(weekday: 2, startMinute: at(9, 0), endMinute: at(12, 0), title: "Pharmacologie", code: "", room: "S101", teacher: ""),
            SyntheticClass(weekday: 3, startMinute: at(13, 0), endMinute: at(16, 0), title: "Stage clinique", code: "", room: "H12", teacher: ""),
            SyntheticClass(weekday: 4, startMinute: at(8, 30), endMinute: at(10, 0), title: "Anatomie humaine", code: "", room: "S101", teacher: ""),
            SyntheticClass(weekday: 4, startMinute: at(14, 0), endMinute: at(15, 30), title: "Éthique professionnelle", code: "", room: "S310", teacher: ""),
            SyntheticClass(weekday: 5, startMinute: at(9, 30), endMinute: at(11, 30), title: "Soins de base", code: "", room: "S204", teacher: "")
        ]
        let width: CGFloat = 1400
        let rowHeight: CGFloat = 58
        let top: CGFloat = 50
        let height = top + CGFloat(classes.count + 1) * rowHeight + 50
        let edges: [CGFloat] = [40, 280, 430, 580, 1090, 1360]
        let headers = ["Jour", "Début", "Fin", "Matière", "Salle"]
        let image = render(width: width, height: height) { ctx in
            Pen.fill(ctx, CGRect(x: edges[0], y: top, width: edges[5] - edges[0], height: rowHeight), UIColor(white: 0.86, alpha: 1))
            for row in 0...classes.count + 1 {
                let y = top + CGFloat(row) * rowHeight
                Pen.line(ctx, from: CGPoint(x: edges[0], y: y), to: CGPoint(x: edges[5], y: y), color: UIColor(white: 0.55, alpha: 1), width: 1.5)
            }
            for edge in edges {
                Pen.line(ctx, from: CGPoint(x: edge, y: top), to: CGPoint(x: edge, y: top + CGFloat(classes.count + 1) * rowHeight),
                         color: UIColor(white: 0.55, alpha: 1), width: 1.5)
            }
            let font = UIFont.systemFont(ofSize: 25)
            for (column, header) in headers.enumerated() {
                Pen.text(header, at: CGRect(x: edges[column] + 12, y: top + 14, width: edges[column + 1] - edges[column] - 24, height: 32),
                         font: UIFont.boldSystemFont(ofSize: 25))
            }
            for (index, course) in classes.enumerated() {
                let y = top + CGFloat(index + 1) * rowHeight + 14
                let cells = [dayNames[course.weekday - 1], clock(course.startMinute), clock(course.endMinute), course.title, course.room]
                for (column, cell) in cells.enumerated() {
                    Pen.text(cell, at: CGRect(x: edges[column] + 12, y: y, width: edges[column + 1] - edges[column] - 24, height: 32), font: font)
                }
            }
        }
        return RenderedSchedule(name: "tableau", image: image, expected: classes.map { $0.expected })
    }

    // MARK: Variants

    private static let ciContext = CIContext()

    static func apply(_ variant: ScheduleVariant, to image: UIImage) -> UIImage {
        switch variant {
        case .clean: return image
        case .blurred: return blurred(image)
        case .tilted: return tilted(image, degrees: 2)
        case .jpeg: return compressed(image, quality: 0.5)
        case .dark: return inverted(image)
        }
    }

    /// A light Gaussian blur (radius 1.2 px); a redraw at low resolution when Core Image is not available.
    private static func blurred(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return lowResolution(image) }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input.clampedToExtent()
        filter.radius = 1.2
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let result = ciContext.createCGImage(output, from: input.extent) else { return lowResolution(image) }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }

    private static func lowResolution(_ image: UIImage) -> UIImage {
        let size = image.size
        let small = CGSize(width: max(1, (size.width * 0.6).rounded()), height: max(1, (size.height * 0.6).rounded()))
        let reduced = redraw(size: small) { image.draw(in: CGRect(origin: .zero, size: small)) }
        return redraw(size: size) { reduced.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// The page turned around its centre, like a photo taken a little crooked.
    private static func tilted(_ image: UIImage, degrees: CGFloat) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: degrees * CGFloat.pi / 180)
            image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    private static func compressed(_ image: UIImage, quality: CGFloat) -> UIImage {
        guard let data = image.jpegData(compressionQuality: quality), let result = UIImage(data: data) else { return image }
        return result
    }

    /// All colours inverted (dark mode): white blocks turn black, light grey cells dark grey, black text white.
    private static func inverted(_ image: UIImage) -> UIImage {
        redraw(size: image.size) {
            image.draw(at: .zero)
            if let cg = UIGraphicsGetCurrentContext() {
                cg.setBlendMode(.difference)
                cg.setFillColor(UIColor.white.cgColor)
                cg.fill(CGRect(origin: .zero, size: image.size))
            }
        }
    }

    // MARK: Drawing

    private static func redraw(size: CGSize, _ draw: () -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw() }
    }

    /// A page of `width` x `height` pixels (scale 1) on a white background.
    private static func render(width: CGFloat, height: CGFloat, _ draw: (CGContext) -> Void) -> UIImage {
        let size = CGSize(width: width.rounded(.up), height: height.rounded(.up))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(context.cgContext)
        }
    }

    private enum Pen {
        /// One line of text, cut with « … » when it does not fit the width.
        static func text(_ string: String, at rect: CGRect, font: UIFont, color: UIColor = .black, align: NSTextAlignment = .left) {
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.lineBreakMode = .byTruncatingTail
            let oneLine = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(font.lineHeight) + 2)
            (string as NSString).draw(in: oneLine, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        }

        /// Lines centred in a rectangle, one under the other.
        static func stack(_ runs: [(text: String, font: UIFont, color: UIColor)], in rect: CGRect) {
            let heights: [CGFloat] = runs.map { ceil($0.font.lineHeight) + 1 }
            let total = heights.reduce(0, +)
            var y = max(rect.minY + 2, rect.midY - total / 2)
            for (index, run) in runs.enumerated() {
                text(run.text, at: CGRect(x: rect.minX + 3, y: y, width: rect.width - 6, height: heights[index]),
                     font: run.font, color: run.color, align: .center)
                y += heights[index]
            }
        }

        static func fill(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor) {
            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
        }

        static func stroke(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor, width: CGFloat) {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.stroke(rect)
        }

        static func line(_ ctx: CGContext, from: CGPoint, to: CGPoint, color: UIColor, width: CGFloat) {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.move(to: from)
            ctx.addLine(to: to)
            ctx.strokePath()
        }
    }
}
