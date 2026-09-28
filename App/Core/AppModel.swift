import Foundation
import Observation
import SwiftUI
import WidgetKit

/// Single source of truth for the app's data. Everything is written through to the shared store,
/// then widgets are asked to refresh.
@MainActor
@Observable
final class AppModel {
    static let freeDesignLimit = 5
    static let freeHabitLimit = 3

    private(set) var designs: [WidgetDesign] = []
    private(set) var content = ContentState()
    private(set) var settings = AppSettings()
    private(set) var premium = PremiumState()

    // Live data used by previews, refreshed on demand.
    private(set) var weather: WeatherResult = .needsLocation
    private(set) var crypto: [String: CryptoResult] = [:]
    private(set) var events: EventsResult = .needsAccess

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    init(store: SharedStore = .shared) {
        self.store = store
        reloadFromDisk()
    }

    /// Widgets can change tasks, habits and water while the app is in the background.
    func reloadFromDisk() {
        designs = store.designs
        content = store.content
        settings = store.settings
        premium = store.premium
        weather = WeatherService.cached.map { cache -> WeatherResult in
            guard let location = settings.weatherLocation, cache.matches(location) else { return .needsLocation }
            return .ready(cache)
        } ?? (settings.weatherLocation == nil ? .needsLocation : .unavailable(nil))
        events = CalendarService.upcoming()
    }

    var isPremium: Bool { premium.isPremium() }

    // MARK: Designs

    var canCreateDesign: Bool { isPremium || designs.count < Self.freeDesignLimit }

    var recentDesigns: [WidgetDesign] {
        designs.sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
    }

    var favoriteDesigns: [WidgetDesign] { recentDesigns.filter(\.isFavorite) }

    func design(id: UUID) -> WidgetDesign? { designs.first { $0.id == id } }

    func isSaved(_ design: WidgetDesign) -> Bool { designs.contains { $0.id == design.id } }

    func save(_ design: WidgetDesign) {
        var updated = design
        updated.updatedAt = Date()
        updated.lastUsedAt = Date()
        if updated.name.trimmed.isEmpty { updated.name = updated.kind.title }
        if let index = designs.firstIndex(where: { $0.id == updated.id }) {
            let previous = designs[index]
            if case let .photo(old) = previous.background, previous.background != updated.background {
                ImageStore.delete(named: old)
            }
            designs[index] = updated
        } else {
            designs.insert(updated, at: 0)
        }
        store.designs = designs
        NotificationScheduler.syncCountdownReminder(for: updated)
        scheduleWidgetReload()
    }

    func delete(_ design: WidgetDesign) {
        designs.removeAll { $0.id == design.id }
        if case let .photo(name) = design.background { ImageStore.delete(named: name) }
        store.designs = designs
        NotificationScheduler.cancelCountdownReminder(for: design.id)
        scheduleWidgetReload()
    }

    func duplicate(_ design: WidgetDesign) -> WidgetDesign? {
        guard canCreateDesign else { return nil }
        var copy = design
        copy.id = UUID()
        copy.name = "\(design.name) (copie)"
        copy.createdAt = Date()
        copy.isFavorite = false
        if case let .photo(name) = design.background, let image = ImageStore.image(named: name), let newName = ImageStore.save(image) {
            copy.background = .photo(newName)
        }
        save(copy)
        return copy
    }

    func toggleFavorite(_ design: WidgetDesign) {
        guard let index = designs.firstIndex(where: { $0.id == design.id }) else { return }
        designs[index].isFavorite.toggle()
        store.designs = designs
    }

    // MARK: Content

    func updateContent(_ change: (inout ContentState) -> Void) {
        change(&content)
        store.content = content
        scheduleWidgetReload()
    }

    var canAddHabit: Bool { isPremium || content.habits.count < Self.freeHabitLimit }

    // MARK: Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        let before = settings
        change(&settings)
        store.settings = settings
        if before.weatherLocation != settings.weatherLocation {
            weather = settings.weatherLocation == nil ? .needsLocation : .unavailable(nil)
            Task { await refreshWeather(force: true) }
        }
        if before.cryptoCurrency != settings.cryptoCurrency {
            crypto = [:]
        }
        scheduleWidgetReload()
    }

    // MARK: Premium

    func updatePremium(_ state: PremiumState) {
        guard state != premium else { return }
        premium = state
        store.premium = state
        scheduleWidgetReload()
    }

    // MARK: Live data

    func refreshWeather(force: Bool = false) async {
        guard let location = settings.weatherLocation else {
            weather = .needsLocation
            return
        }
        if !force, case let .ready(snapshot) = weather, snapshot.matches(location),
           Date().timeIntervalSince(snapshot.fetchedAt) < WeatherService.refreshInterval {
            return
        }
        weather = await WeatherService.load(allowNetwork: true)
        scheduleWidgetReload()
    }

    func refreshCrypto(_ coinID: String) async {
        crypto[coinID] = await CryptoService.load(coinID: coinID, allowNetwork: true)
    }

    func refreshEvents() {
        events = CalendarService.upcoming()
    }

    /// Data for a preview inside the app: the user's real content and the latest fetched data.
    func payload(for design: WidgetDesign) -> WidgetPayload {
        var payload = WidgetPayload()
        payload.settings = settings
        payload.content = content
        payload.weather = weather
        payload.crypto = crypto[design.options.coinID] ?? CryptoService.cached(design.options.coinID, currency: settings.cryptoCurrency).map { CryptoResult.ready($0) } ?? .unavailable(nil)
        payload.events = events
        return payload
    }

    /// Loads whatever network data a design needs for its preview.
    func prepare(_ design: WidgetDesign) async {
        switch design.kind {
        case .weather: await refreshWeather()
        case .crypto: await refreshCrypto(design.options.coinID)
        case .upNext: refreshEvents()
        default: break
        }
    }

    // MARK: Widgets

    /// Coalesces bursts of edits (typing a task, dragging a slider) into one widget reload.
    func scheduleWidgetReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Onboarding

    func completeOnboarding() {
        updateSettings { $0.hasCompletedOnboarding = true }
    }

    /// Erases everything the user created. Premium status is kept (it belongs to the App Store account).
    func resetAllData() {
        for design in designs {
            if case let .photo(name) = design.background { ImageStore.delete(named: name) }
        }
        designs = []
        content = ContentState()
        var fresh = AppSettings()
        fresh.hasCompletedOnboarding = true
        settings = fresh
        store.designs = designs
        store.content = content
        store.settings = settings
        store.remove(.weather)
        store.remove(.crypto)
        weather = .needsLocation
        crypto = [:]
        NotificationScheduler.cancelAll()
        scheduleWidgetReload()
    }
}
