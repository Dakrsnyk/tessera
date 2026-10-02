import EventKit
import Foundation
import SwiftUI
import UIKit

struct EventSnapshot: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var colorHex: String
    var location: String?

    func isOngoing(at date: Date) -> Bool { start <= date && end > date }
}

enum EventsResult: Hashable {
    case ready([EventSnapshot])
    case needsAccess
}

enum CalendarService {
    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static var accessDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted || status == .writeOnly
    }

    /// Asks for calendar access. Only called from the app, when the user adds an "À venir" widget.
    static func requestAccess() async -> Bool {
        do {
            return try await EKEventStore().requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Every event between two dates (all-day ones first each day), for the Planning mini-app.
    static func events(from start: Date, to end: Date) -> [EventSnapshot] {
        guard hasAccess, end > start else { return [] }
        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { lhs, rhs in
                if !DateMath.isSameDay(lhs.startDate, rhs.startDate) { return lhs.startDate < rhs.startDate }
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
            .map { event in
                EventSnapshot(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.trimmed.nonEmpty ?? tr("Sans titre"),
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    colorHex: event.calendar.map { Color.hexFromCG($0.cgColor) } ?? "3366FF",
                    location: event.location?.trimmed.nonEmpty
                )
            }
    }

    static func upcoming(from now: Date = Date(), hours: Int = 48, limit: Int = 8) -> EventsResult {
        guard hasAccess else { return .needsAccess }
        let store = EKEventStore()
        let end = now.addingTimeInterval(TimeInterval(hours) * 3600)
        let predicate = store.predicateForEvents(withStart: DateMath.startOfDay(now), end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
            .prefix(limit)
            .map { event in
                EventSnapshot(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.trimmed.nonEmpty ?? tr("Sans titre"),
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    colorHex: event.calendar.map { Color.hexFromCG($0.cgColor) } ?? "3366FF",
                    location: event.location?.trimmed.nonEmpty
                )
            }
        return .ready(Array(events))
    }
}

extension Color {
    static func hexFromCG(_ cgColor: CGColor?) -> String {
        guard let cgColor else { return "3366FF" }
        return Color(uiColor: UIColor(cgColor: cgColor)).hexString
    }
}
