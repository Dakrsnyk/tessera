import Foundation
import CoreGraphics

/// What the whole page says it is, from its words: a work schedule ("Horaire de travail", "Shifts", "Employé", "Dienstplan",
/// "シフト") or a list of appointments ("Rendez-vous", "Appointments", "Dentiste", "Termin", "予約"). The readings of shifts and
/// of dated appointments only start when the page carries such a mark: a timetable of classes reads exactly as before.
struct DocumentCues: Equatable {
    var work = false
    var appointments = false

    init(work: Bool = false, appointments: Bool = false) {
        self.work = work
        self.appointments = appointments
    }

    /// Only the words that leave no doubt mark the whole page: « Turno: Mañana », « Staff room », « Réunion », « Termine »
    /// are common in timetables of classes, so they only mark their own row (see `ScheduleEvents.rowCue`).
    init(lines: [RecognizedLine]) {
        for line in lines {
            if !work, ScheduleEvents.hasWorkCue(line.text, page: true) { work = true }
            if !appointments, ScheduleEvents.hasAppointmentCue(line.text, page: true) { appointments = true }
        }
    }
}

/// Entries that are not weekly classes: dated appointments ("Mardi 24 novembre 2026, 14 h 30, Dr Roy, Clinique du Parc",
/// "2026-11-24 14:30 Dentiste", "Nov 24, 2:30 PM - Dentist"), shifts of a work schedule, and the rows of an agenda under a
/// dated heading. Pure logic; the words are compared folded (lowercase, no accents).
///
/// What a row of an appointment holds is cut at its commas, dashes and bars: a piece that names a person ("Dr Roy",
/// "Me Tremblay", "J. Dupont", "山田先生") is the `detail`, a piece that names a place ("Clinique du Parc", "120 rue
/// Principale", "Salle B-204") is the room, the first other piece is the title, and the next ones are notes added to the
/// detail. Nothing is invented: a date that cannot be read stays empty and marked, an hour that cannot be read is
/// proposed unticked with its fields marked.
enum ScheduleEvents {

    // MARK: Words

    static let workWords: Set<String> = [
        "quart", "quarts", "shift", "shifts", "employe", "employes", "employee", "employees", "staff", "roster", "rota",
        "turno", "turnos", "turni", "schicht", "schichten", "schichtplan", "dienstplan", "mitarbeiter", "escala", "plantao",
        "plantoes", "dipendente", "dipendenti", "empleado", "empleados", "funcionario", "funcionarios"
    ]

    static let workPhrases: [String] = [
        "horaire de travail", "planning de travail", "planning du personnel", "work schedule", "staff schedule",
        "horario de trabajo", "horario laboral", "orario di lavoro", "horario de trabalho", "escala de trabalho"
    ]

    static let workMarks: [String] = ["シフト", "勤務"]

    /// Work words also common in a timetable of classes ("Turno: Mañana", "Staff room", "turni"): they mark their row only.
    static let rowOnlyWorkWords: Set<String> = [
        "turno", "turnos", "turni", "staff", "escala", "rota", "quart", "quarts", "plantao", "plantoes"
    ]

    /// Appointment words also common in a timetable of classes ("Réunion", "Entretien", "Termine", "Physiothérapie"): they
    /// mark their row only.
    static let rowOnlyAppointmentWords: Set<String> = [
        "termin", "termine", "reunion", "reunions", "meeting", "meetings", "entrevue", "entretien", "interview", "besprechung",
        "riunione", "reuniao", "physiotherapie", "physiotherapy", "physio", "fisioterapia", "doctor", "vaccination", "vaccin"
    ]

    /// Words that name an appointment without any doubt: they reclassify a row of a timetable that has no date.
    static let explicitAppointmentWords: Set<String> = ["rdv", "appointment", "appointments", "appt"]

    static let appointmentWords: Set<String> = [
        "rdv", "appointment", "appointments", "appt", "cita", "citas", "termin", "termine", "arzttermin", "appuntamento",
        "appuntamenti", "agendamento", "agendamentos", "dentiste", "dentist", "dentista", "zahnarzt", "zahnarztin", "medecin",
        "doctor", "docteur", "docteure", "arzt", "arztin", "medico", "medica", "avocat", "avocate", "lawyer", "attorney",
        "anwalt", "anwaltin", "avvocato", "abogado", "abogada", "advogado", "advogada", "notaire", "notary", "notar", "notaio",
        "notario", "reunion", "reunions", "meeting", "meetings", "entrevue", "entretien", "interview", "besprechung",
        "riunione", "reuniao", "physiotherapie", "physiotherapy", "physio", "fisioterapia", "optometriste", "ophtalmologiste",
        "orthodontiste", "veterinaire", "vaccin", "vaccination", "impfung", "coiffeur", "coiffeuse", "hairdresser", "friseur",
        "parrucchiere", "peluqueria", "cabeleireiro"
    ]

    static let appointmentPhrases: [String] = ["rendez vous", "prise de sang"]

    static let appointmentMarks: [String] = ["予約", "診察", "面談", "歯医者", "歯科", "病院", "会議", "打ち合わせ", "打合せ"]

    /// A day without work in a schedule of shifts ("Mer Congé", "Thu Off", "Sa frei").
    static let offWords: Set<String> = [
        "conge", "conges", "repos", "off", "ferie", "vacances", "absent", "absente", "malade", "riposo", "folga", "descanso",
        "frei", "urlaub", "libre", "free", "rest", "holiday", "vacation", "feriado", "festivo", "休み", "休", "公休"
    ]

    /// Titles of a professional the person meets (not of a teacher): a dated row with one of them is an appointment.
    static let professionalMarkers: Set<String> = [
        "dr", "dre", "dra", "docteur", "docteure", "doctor", "dott", "dottssa", "dottoressa", "maitre", "avv"
    ]

    /// Titles that start the name of a person.
    static let personMarkers: Set<String> = professionalMarkers.union([
        "mme", "mr", "mrs", "ms", "mlle", "prof", "professeur", "professeure", "pr", "sr", "sra", "srta", "herr", "frau",
        "sig", "sigra", "signor", "signora", "senhor", "senhora"
    ])

    static let personMarks: [String] = ["先生", "様", "さん", "医師"]

    /// Words of a class: a dated row with one of them is a class, not an appointment ("CM Analyse - Dr Martin").
    static let courseMarkers: Set<String> = [
        "cm", "td", "tp", "cours", "course", "lecture", "class", "classe", "lab", "labo", "seminar", "seminaire", "tutorial",
        "vorlesung", "lezione", "clase", "examen", "exam"
    ]

    /// A piece that starts with one of these is a place.
    static let placeWords: Set<String> = [
        "clinique", "clinic", "clinica", "klinik", "cabinet", "centre", "center", "centro", "hopital", "hospital", "ospedale",
        "krankenhaus", "pharmacie", "pharmacy", "farmacia", "apotheke", "bureau", "office", "oficina", "ufficio", "escritorio",
        "praxis", "studio", "banque", "bank", "banco", "banca", "mairie", "tribunal", "palais", "courthouse", "salle", "room",
        "local", "sala", "aula", "raum", "clsc", "ecole", "school", "escuela", "schule", "scuola", "escola", "bibliotheque",
        "library", "magasin", "store", "succursale", "branch", "pavillon", "edifice", "building", "batiment"
    ]

    /// Strong place words: they cut a piece in two when they come after its first word ("Dentiste Clinique du Parc").
    static let strongPlaceWords: Set<String> = [
        "clinique", "clinic", "clinica", "klinik", "cabinet", "hopital", "hospital", "pharmacie", "praxis"
    ]

    /// Words of an address: with a number in the piece, the piece is a place ("120 rue Principale", "12 Main St").
    static let streetWords: Set<String> = [
        "rue", "avenue", "av", "ave", "boulevard", "boul", "bd", "blvd", "chemin", "route", "rte", "place", "allee",
        "impasse", "street", "st", "road", "rd", "lane", "ln", "way", "calle", "avenida", "paseo", "rua", "travessa",
        "strasse", "str", "weg", "platz", "gasse", "via", "viale", "piazza", "corso", "suite", "bureau", "local"
    ]

    /// Small words that may start a piece ("à 14 h", "chez Dr Roy", "ore 14:30"): taken off its start.
    static let leadConnectors: Set<String> = [
        "a", "at", "on", "ore", "alle", "um", "as", "chez", "avec", "with", "con", "mit", "com", "bei", "presso"
    ]

    /// Small words that say nothing alone: a piece made only of them is dropped, and they are taken off the end of a title
    /// ("Rendez-vous avec" -> "Rendez-vous").
    static let connectors: Set<String> = leadConnectors.union([
        "au", "aux", "le", "la", "les", "the", "el", "de", "du", "des", "y", "et", "and", "und", "e", "en", "in", "of", "for",
        "pour", "para", "per", "fur", "uhr", "h", "hrs", "heure", "heures"
    ])

    // MARK: Cues

    private static func padded(_ text: String) -> String {
        " " + ScheduleParser.words(of: text).joined(separator: " ") + " "
    }

    /// `page`: whether the word marks the whole page (the words common in timetables of classes do not).
    static func hasWorkCue(_ text: String, page: Bool = false) -> Bool {
        if workMarks.contains(where: { text.contains($0) }) { return true }
        let words = ScheduleParser.words(of: text)
        if words.contains(where: { workWords.contains($0) && !(page && rowOnlyWorkWords.contains($0)) }) { return true }
        let line = padded(text)
        return workPhrases.contains { line.contains(" \($0) ") }
    }

    static func hasAppointmentCue(_ text: String, page: Bool = false) -> Bool {
        if appointmentMarks.contains(where: { text.contains($0) }) { return true }
        let words = ScheduleParser.words(of: text)
        if words.contains(where: { appointmentWords.contains($0) && !(page && rowOnlyAppointmentWords.contains($0)) }) { return true }
        let line = padded(text)
        return appointmentPhrases.contains { line.contains(" \($0) ") }
    }

    /// "Me Tremblay", "Maître Roy" (a lawyer in French): "Me" alone is a word of many languages, so a capital must follow.
    static let lawyerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|[\s,;(])(?:Me|Maître|Maitre)\.?\s+\p{Lu}"#, options: [])

    /// "rdv", "rendez-vous", "appointment", "予約": an appointment whatever the page says.
    static func hasExplicitAppointment(_ text: String) -> Bool {
        if text.contains("予約") { return true }
        if ScheduleParser.words(of: text).contains(where: { explicitAppointmentWords.contains($0) }) { return true }
        return padded(text).contains(" rendez vous ")
    }

    static func hasProfessionalPerson(_ text: String) -> Bool {
        if text.contains("医師") { return true }
        if ScheduleParser.words(of: text).contains(where: { professionalMarkers.contains($0) }) { return true }
        guard let regex = lawyerRegex else { return false }
        return regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    static func hasCourseMarker(_ text: String) -> Bool {
        if ScheduleParser.courseCode(in: text) != nil { return true }
        return ScheduleParser.words(of: text).contains { courseMarkers.contains($0) }
    }

    /// Whether a row is an entry of its own kind (an appointment or a shift), from its own words.
    struct RowCue {
        var appointment = false
        var work = false
        var professional = false
        var any: Bool { appointment || work || professional }
    }

    /// A professional ("Dr Roy", "Me Tremblay") makes a dated row an appointment only with the place of one (a clinic, an
    /// office, an address) and no word of a class: "Analyse - Dr Martin, Salle B-204" on a dated list stays a class.
    static func rowCue(_ text: String) -> RowCue {
        RowCue(appointment: hasAppointmentCue(text), work: hasWorkCue(text),
               professional: hasProfessionalPerson(text) && !hasCourseMarker(text) && hasAppointmentPlace(text))
    }

    /// Places of an appointment: the place words without those of a school (a room, a library, a building of a campus).
    static let appointmentPlaceWords: Set<String> = placeWords.subtracting([
        "salle", "room", "local", "sala", "aula", "raum", "ecole", "school", "escuela", "schule", "scuola", "escola",
        "bibliotheque", "library", "pavillon", "edifice", "building", "batiment"
    ])

    /// "Clinique du Parc", "Cabinet Gagnon", "120 rue Principale", "12 Main St" somewhere in the text.
    static func hasAppointmentPlace(_ text: String) -> Bool {
        for piece in pieces(text) {
            let list = ScheduleParser.words(of: piece)
            if list.contains(where: { appointmentPlaceWords.contains($0) }) { return true }
            let street = list.contains { streetWords.contains($0) && !["local", "bureau", "suite"].contains($0) }
            if street, piece.contains(where: { $0.isNumber }) { return true }
        }
        return false
    }

    /// "Congé", "Off", "Repos", "Day off": a day without work.
    static func isOff(_ text: String) -> Bool {
        let list = ScheduleParser.words(of: text)
        guard !list.isEmpty, list.count <= 3 else { return false }
        return list.contains { offWords.contains($0) } && list.allSatisfy { offWords.contains($0) || ["day", "jour", "de", "tag", "giorno", "dia"].contains($0) }
    }

    /// "2:30 PM" or "9 am" somewhere in the text: an English page, where "03/04" is March 4.
    static func hasMeridiem(_ text: String) -> Bool {
        text.range(of: #"(?i)\d\s?(?:[ap]\.?m\.?)(?![a-z])"#, options: .regularExpression) != nil
    }

    /// An hour written but not readable ("??h30", "1?:00", "25h"): the entry is proposed with its hours to fill in.
    static func hasBrokenTime(_ text: String) -> Bool {
        text.range(of: #"(?<![\p{L}\d])[\d?]{1,2}\s?[hH:]\s?[\d?]{0,2}(?![\p{L}\d])"#, options: .regularExpression) != nil
            && text.contains(where: { $0 == "?" || $0.isNumber })
    }

    /// An hour of a 12-hour clock written without AM or PM ("2:30", "4 h 15"): the parser reads 14:30, which may be wrong.
    static func isAmbiguousHour(_ time: ScheduleParser.TimeFound, in text: String) -> Bool {
        let ns = text as NSString
        guard time.range.location != NSNotFound, time.range.location + time.range.length <= ns.length else { return false }
        let written = ns.substring(with: time.range)
        if written.range(of: #"(?i)[ap]\.?m"#, options: .regularExpression) != nil { return false }
        guard let first = written.split(whereSeparator: { !$0.isNumber }).first, let hour = Int(first) else { return false }
        return (1...7).contains(hour)
    }

    // MARK: Pieces of a row

    /// The text cut at its commas, semicolons, dashes, bars and dots between words. A piece in Japanese is also cut at its spaces.
    static func pieces(_ text: String) -> [String] {
        var parts = [text]
        for separator in [",", ";", " - ", " | ", " · ", " • ", " / ", "、"] {
            parts = parts.flatMap { $0.components(separatedBy: separator) }
        }
        var result: [String] = []
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if ScheduleScoring.hasCJK(trimmed), trimmed.contains(" ") {
                result.append(contentsOf: trimmed.split(separator: " ").map { String($0) })
            } else {
                result.append(trimmed)
            }
        }
        return result
    }

    /// A piece without the small words that start it ("chez Dr Roy" -> "Dr Roy", "à 14 h" -> "14 h") nor those that end it
    /// ("Rendez-vous avec" -> "Rendez-vous").
    static func withoutConnectors(_ piece: String) -> String {
        var tokens = piece.split(separator: " ").map { String($0) }
        while tokens.count > 1, let first = tokens.first, leadConnectors.contains(ScheduleParser.normalizedToken(first)) {
            tokens.removeFirst()
        }
        while tokens.count > 1, let last = tokens.last, connectors.contains(ScheduleParser.normalizedToken(last)) {
            tokens.removeLast()
        }
        return tokens.joined(separator: " ")
    }

    /// "Dr Roy", "Me Tremblay (avocat)", "Mme Gagnon", "J. Dupont", "Dupont J.", "山田先生".
    static func isPerson(_ piece: String) -> Bool {
        if personMarks.contains(where: { piece.contains($0) }) { return true }
        let tokens = piece.split(separator: " ").map { String($0) }
        if tokens.count >= 2, let first = tokens.first {
            let key = ScheduleParser.normalizedToken(first)
            if personMarkers.contains(key) { return true }
            // "M. Dupont": the dot makes it a title; "Me Roy": a capital must follow.
            if first == "M.", tokens[1].first?.isUppercase == true { return true }
            if ["me", "maitre"].contains(key), tokens[1].first?.isUppercase == true { return true }
        }
        return ScheduleParser.isPersonName(piece)
    }

    /// "Clinique du Parc", "120 rue Principale", "12 Main St", "Salle B-204", "Bureau 300".
    static func isPlace(_ piece: String) -> Bool {
        let list = ScheduleParser.words(of: piece)
        guard let first = list.first else { return false }
        if placeWords.contains(first) { return true }
        if piece.contains(where: { $0.isNumber }), list.contains(where: { streetWords.contains($0) }) { return true }
        return ScheduleParser.extractRoom(from: piece).room != nil
    }

    /// A piece that holds a title then a person or a strong place without a separator ("Dentiste Dr Roy",
    /// "Dentiste Clinique du Parc"): cut before the person or the place.
    static func split(_ piece: String) -> [String] {
        let tokens = piece.split(separator: " ").map { String($0) }
        guard tokens.count >= 3 else { return [piece] }
        for index in 1..<(tokens.count - 1) {
            let key = ScheduleParser.normalizedToken(tokens[index])
            let next = tokens[index + 1]
            let person = (personMarkers.contains(key) || (tokens[index] == "M." || key == "me")) && next.first?.isUppercase == true
            if person || strongPlaceWords.contains(key) {
                return [tokens[..<index].joined(separator: " "), tokens[index...].joined(separator: " ")]
            }
        }
        return [piece]
    }

    /// Title, person (and notes), place of what is left of a row once its date and its hours are out.
    static func describe(_ text: String) -> (title: String, detail: String?, room: String?) {
        var titles: [String] = []
        var people: [String] = []
        var places: [String] = []
        for raw in pieces(text) {
            for part in split(withoutConnectors(withoutDayNames(raw))) {
                let piece = withoutConnectors(part)
                let list = ScheduleParser.words(of: piece)
                guard !list.isEmpty, !list.allSatisfy({ connectors.contains($0) }) else { continue }
                // A day name left alone ("Di.", "Tue"): the day is already the entry's.
                if list.count == 1, ScheduleParser.strongDays[list[0]] != nil || ScheduleParser.weakDays[list[0]] != nil { continue }
                let clean = ScheduleParser.cleanTitle(piece)
                guard !clean.isEmpty else { continue }
                if isPerson(piece) {
                    people.append(ScheduleParser.cleanDetail(piece))
                } else if isPlace(piece) {
                    places.append(clean)
                } else if !ScheduleParser.isUnreadableTitle(clean) {
                    titles.append(clean)
                }
            }
        }
        let notes = people + titles.dropFirst()
        let detail = notes.isEmpty ? nil : String(notes.joined(separator: " · ").prefix(80))
        let room = places.isEmpty ? nil : String(places.joined(separator: ", ").prefix(80))
        return (titles.first ?? "", detail, room)
    }

    // MARK: Entries

    /// The fields in doubt of a settled date.
    static func flags(of date: SettledDate) -> Set<SlotField> {
        var result: Set<SlotField> = []
        if date.uncertain { result.insert(.date) }
        if date.weekdayConflict { result.insert(.day) }
        return result
    }

    /// The entries of a row on a known day (and date): its hours, then its title, person and place. nil when the row is not
    /// an entry of its own kind (no hour, or no mark of an appointment or a shift on the row nor on the page): the reading of
    /// a timetable then goes on as before. `allowBrokenTime` proposes, unticked, an entry whose hour cannot be read.
    /// `keepEmpty` keeps an entry that says nothing but its date and hours (the next line may complete it, see `extract`).
    static func entries(_ text: String, day: Int, date: Date?, flags: Set<SlotField>, cues: DocumentCues,
                        allowBrokenTime: Bool, keepEmpty: Bool = false) -> [ScheduleParser.Draft]? {
        guard (1...7).contains(day) else { return nil }
        var unmarked = text.replacingOccurrences(of: #"[(（]\s*[月火水木金土日]\s*[)）]"#, with: " ", options: .regularExpression)
        // A shift whose hours as written are not sure ("4h-12h", "22h-6h"): taken out first, read as written (see `unsureShifts`).
        var unsure: [WrittenShift] = []
        let early = rowCue(unmarked)
        if !(early.appointment || early.professional), early.work || (cues.work && !cues.appointments), !hasCourseMarker(unmarked) {
            unsure = unsureShifts(in: unmarked)
            unmarked = masking(unsure, in: unmarked)
        }
        let split = ScheduleParser.findTimes(in: unmarked)
        var remainder = split.rest
        let broken = split.times.isEmpty && unsure.isEmpty && allowBrokenTime && hasBrokenTime(unmarked)
        guard !split.times.isEmpty || broken || !unsure.isEmpty else { return nil }
        if broken {
            remainder = remainder.replacingOccurrences(of: #"(?<![\p{L}\d])[\d?]{1,2}\s?[hH:]\s?[\d?]{0,2}(?![\p{L}\d])"#, with: " ",
                                                       options: .regularExpression)
        }
        guard !ScheduleParser.isNoise(text) else { return nil }
        let cue = rowCue(remainder)
        guard cue.any || cues.appointments || cues.work else { return nil }
        // A row of a class ("Vorlesung Analysis", "CM", a course code) stays a class unless the row itself says otherwise.
        if !cue.any && hasCourseMarker(remainder) { return nil }
        let kind: ScheduleKind
        if cue.appointment || cue.professional {
            kind = .appointment
        } else if cue.work {
            kind = .work
        } else if cues.appointments {
            kind = .appointment
        } else {
            kind = .work
        }
        let described = describe(remainder)
        // A date and hours alone (a time stamp) are no entry: nothing is invented to fill it.
        if !keepEmpty, !cue.any, described.title.isEmpty, described.detail == nil, described.room == nil { return nil }
        if broken {
            return [ScheduleParser.Draft(weekday: day, start: 8 * 60, end: 9 * 60, title: described.title, room: described.room,
                                         uncertain: flags.union([.start, .end]), kind: kind, date: date, detail: described.detail,
                                         unselected: true)]
        }
        var drafts: [ScheduleParser.Draft] = []
        for (index, time) in split.times.enumerated() {
            var fields = flags.union(ScheduleParser.timeFlags(time))
            // Only the first range is placed in the text as written (the next ones are found once it is taken out).
            if index == 0, isAmbiguousHour(time, in: unmarked) {
                fields.insert(.start)
                if time.end != nil { fields.insert(.end) }
            }
            drafts.append(ScheduleParser.Draft(weekday: day, start: time.start, end: time.end, title: described.title,
                                               room: described.room, uncertain: fields, kind: kind, date: date,
                                               detail: described.detail))
        }
        for shift in unsure {
            drafts.append(ScheduleParser.Draft(weekday: day, start: shift.start, end: shift.end, title: described.title,
                                               room: described.room, uncertain: flags.union([.start, .end]), kind: kind, date: date,
                                               detail: described.detail, unselected: true))
        }
        return drafts
    }

    // MARK: Shifts whose hours are not sure

    /// A range of a work schedule read with its hours as written.
    struct WrittenShift {
        var start: Int
        var end: Int
        /// Ends after midnight ("22h-6h"): the entry stops at 24:00, the only end a day of the Planning can hold.
        var overnight: Bool
        var range: NSRange
    }

    /// Two hours written with "h" or ":" on one side at least, without AM or PM: groups 1 and 3 the hours, 2 and 4 the minutes.
    static let writtenRangeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d:.,/])(?<![A-Za-z])(\d{1,2})(?:\s?[hH:]\s?(\d{2})?)?(?:\s*[-~]\s*|\s+(?:à|a|to|bis|al|até)\s+)(\d{1,2})(?:\s?[hH:]\s?(\d{2})?)?(?![\d])(?!\s?[aApP]\.?[mM])"#,
        options: [])

    /// The ranges of a shift row whose hours the rules of a timetable would change or drop: a start written between 1 and 5
    /// ("4h-12h" would be read 16:00-24:00, "5h-13h" dropped) or an end before the start ("22h-6h", past midnight). They are
    /// given as written (the overnight one stopped at 24:00), for the person to check. Only the rows of a work schedule ask
    /// for them: the reading of a timetable of classes never does.
    static func unsureShifts(in text: String) -> [WrittenShift] {
        guard let regex = writtenRangeRegex else { return [] }
        let ns = text as NSString
        var result: [WrittenShift] = []
        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let written = ns.substring(with: match.range)
            guard written.contains(where: { $0 == "h" || $0 == "H" || $0 == ":" }),
                  let h1 = Int(ScheduleParser.group(match, 1, in: ns) ?? ""), let h2 = Int(ScheduleParser.group(match, 3, in: ns) ?? "")
            else { continue }
            let m1 = Int(ScheduleParser.group(match, 2, in: ns) ?? "0") ?? 0
            let m2 = Int(ScheduleParser.group(match, 4, in: ns) ?? "0") ?? 0
            guard h1 <= 23, h2 <= 24, m1 < 60, m2 < 60, !(h2 == 24 && m2 > 0) else { continue }
            let start = h1 * 60 + m1
            let end = h2 * 60 + m2
            if end <= start {
                guard end < start else { continue }
                result.append(WrittenShift(start: start, end: 24 * 60, overnight: true, range: match.range))
            } else if (1...5).contains(h1) {
                // The hours the usual reading moves to the afternoon (`resolveSingle`): 6h and 7h are read as written.
                result.append(WrittenShift(start: start, end: end, overnight: false, range: match.range))
            }
        }
        return result
    }

    /// The text with these ranges replaced by spaces (same length: the other places stay valid).
    static func masking(_ shifts: [WrittenShift], in text: String) -> String {
        var result = text as NSString
        for shift in shifts {
            result = result.replacingCharacters(in: shift.range, with: String(repeating: " ", count: shift.range.length)) as NSString
        }
        return result as String
    }

    /// A row that holds its own date and hours ("Mardi 24 novembre 2026, 14 h 30, Dentiste, Dr Roy"), when the row or the page
    /// says it is an appointment or a shift. A row whose date is written but unreadable ("Mardi ?? novembre") keeps its day
    /// name, no date, and the date marked. nil for anything else (a heading, a timetable row, a footer "Imprimé le ...").
    static func datedRow(_ text: String, cues: DocumentCues, reference: Date) -> [ScheduleParser.Draft]? {
        guard !ScheduleParser.isNoise(text) else { return nil }
        let lead = ScheduleParser.leadingDays(in: text)
        var weekday: Int? = nil
        if let lead = lead, lead.days.count == 1 { weekday = lead.days[0] }
        if weekday == nil { weekday = ScheduleParser.embeddedCJKDay(in: text) }
        let monthFirst = hasMeridiem(text)
        var source = lead?.rest ?? text
        var written = ScheduleDates.find(in: source, monthFirst: monthFirst)
        if written == nil, lead != nil, let whole = ScheduleDates.find(in: text, monthFirst: monthFirst) {
            // "Mar 18, 2026": the word taken for a day name was the month.
            source = text
            written = whole
            weekday = nil
        }
        if let found = written {
            guard let settled = ScheduleDates.settle(found, weekday: weekday, reference: reference) else { return nil }
            let rest = (source as NSString).replacingCharacters(in: found.range, with: " ")
            return entries(rest, day: settled.weekday, date: settled.date, flags: flags(of: settled), cues: cues, allowBrokenTime: true,
                           keepEmpty: true)
        }
        // A month is named but its day cannot be read: an entry on the day named, without a date, the date marked.
        guard let day = weekday, ScheduleDates.mentionsMonth(source) else { return nil }
        let rest = withoutDateDebris(source)
        var fields: Set<SlotField> = [.date]
        if lead?.fuzzy == true { fields.insert(.day) }
        // Proposed unticked, like an hour that cannot be read: kept ticked without a date it would come back every week.
        guard let found = entries(rest, day: day, date: nil, flags: fields, cues: cues, allowBrokenTime: true, keepEmpty: true)
        else { return nil }
        return found.map { draft in
            var copy = draft
            copy.unselected = true
            return copy
        }
    }

    /// The text without its unreadable date: the month name, the day number or marks just before it ("??", "2?", "de") and
    /// the year just after it ("?? novembre 2026, 14 h 30" -> "14 h 30"). The hours further on are kept.
    static func withoutDateDebris(_ text: String) -> String {
        var tokens = text.split(separator: " ").map { String($0) }
        func core(_ token: String) -> String {
            ScheduleParser.fold(token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()")))
        }
        guard let at = tokens.firstIndex(where: { token in
            let key = core(token)
            return key.count >= 3 && ScheduleDates.months[key] != nil && !ScheduleDates.weakMonthWords.contains(key)
        }) else { return text }
        func isDayDebris(_ token: String) -> Bool {
            let key = core(token)
            return ["de", "of", "le", "the"].contains(key)
                || key.range(of: #"^[\d?]{1,2}(?:er|re|st|nd|rd|th)?$"#, options: .regularExpression) != nil
        }
        func isYearDebris(_ token: String) -> Bool {
            let key = core(token)
            return key == "de" || key.range(of: #"^[\d?]{4}$"#, options: .regularExpression) != nil
        }
        var from = at
        var to = at
        while from > 0, at - from < 2, isDayDebris(tokens[from - 1]) { from -= 1 }
        while to + 1 < tokens.count, to - at < 2, isYearDebris(tokens[to + 1]) { to += 1 }
        tokens.removeSubrange(from...to)
        return tokens.joined(separator: " ")
    }

    /// A piece without the full names of days ("Rendez-vous : jeudi" -> "Rendez-vous :"): the day is already the entry's.
    /// Short forms ("Mon", "Sun") are kept: they are also words.
    static func withoutDayNames(_ piece: String) -> String {
        let tokens = piece.split(separator: " ").map { String($0) }
        let kept = tokens.filter { token in
            let key = ScheduleParser.dayKey(token)
            return !(key.count >= 5 && ScheduleParser.strongDays[key] != nil)
        }
        return kept.count == tokens.count ? piece : kept.joined(separator: " ")
    }

    /// A row that is only a date ("24 novembre 2026", "2026-11-24"), the heading of the entries under it.
    static func dateHeading(_ text: String, reference: Date) -> SettledDate? {
        guard let written = ScheduleDates.find(in: text, monthFirst: hasMeridiem(text)) else { return nil }
        let rest = (text as NSString).replacingCharacters(in: written.range, with: " ")
        guard ScheduleParser.findTime(in: rest) == nil, ScheduleParser.isDateish(rest) else { return nil }
        return ScheduleDates.settle(written, weekday: nil, reference: reference)
    }

    /// The rows of the page that hold a dated entry of their own, with the row just under one when it completes it (a
    /// second line with the place or the person), and the indexes of the lines they use. The other lines are read as a
    /// timetable by the layouts.
    static func extract(_ lines: [RecognizedLine], reference: Date) -> (drafts: [ScheduleParser.Draft], used: Set<Int>) {
        let cues = DocumentCues(lines: lines)
        let rows = ScheduleParser.readingRowGroups(lines)
        var drafts: [ScheduleParser.Draft] = []
        var used = Set<Int>()
        var last: [Int] = []
        var lastBottom: CGFloat = 0
        var lastHeight: CGFloat = 0
        for row in rows {
            let text = row.map { lines[$0].text }.joined(separator: " ")
            let top = row.map { lines[$0].box.minY }.min() ?? 0
            let bottom = row.map { lines[$0].box.maxY }.max() ?? top
            let height = row.map { lines[$0].box.height }.max() ?? 0
            if let found = datedRow(text, cues: cues, reference: reference) {
                last = Array(drafts.count..<(drafts.count + found.count))
                drafts.append(contentsOf: found)
                used.formUnion(row)
                lastBottom = bottom
                lastHeight = height
                continue
            }
            // The line just under an entry, close to it, with no hour, no date and no day: the rest of the entry.
            if !last.isEmpty, top - lastBottom <= 1.2 * max(height, lastHeight, 0.008), isContinuation(text) {
                complete(&drafts, last, with: text)
                used.formUnion(row)
            }
            last = []
        }
        // An entry left with nothing but its date and hours (no line under it completed it) is dropped: its lines are only a
        // time stamp of the page.
        drafts.removeAll { $0.title.isEmpty && $0.detail == nil && $0.room == nil }
        return (drafts, used)
    }

    static func isContinuation(_ text: String) -> Bool {
        guard text.filter({ $0.isLetter }).count >= 2, !ScheduleParser.isNoise(text) else { return false }
        if ScheduleParser.findTime(in: text) != nil || ScheduleDates.find(in: text) != nil { return false }
        return ScheduleParser.leadingDays(in: text) == nil
    }

    /// Fills what the entries miss with what the line says: the title, the place, the person; another title is a note.
    static func complete(_ drafts: inout [ScheduleParser.Draft], _ indexes: [Int], with text: String) {
        let found = describe(text)
        for index in indexes where index < drafts.count {
            if drafts[index].title.isEmpty, !found.title.isEmpty {
                drafts[index].title = found.title
                if let detail = found.detail, drafts[index].detail == nil { drafts[index].detail = detail }
            } else {
                var notes: [String] = []
                if let existing = drafts[index].detail { notes.append(existing) }
                if !found.title.isEmpty { notes.append(found.title) }
                if let detail = found.detail { notes.append(detail) }
                if !notes.isEmpty { drafts[index].detail = String(notes.joined(separator: " · ").prefix(80)) }
            }
            if drafts[index].room == nil, let room = found.room { drafts[index].room = room }
        }
    }
}
