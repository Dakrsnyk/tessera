import Foundation

/// URLs opened when the user taps a widget. Scheme: tessera://
enum DeepLink: Equatable {
    case design(UUID)
    case premium
    case tasks
    case habits
    case hydration
    case money
    case weatherLocation
    case calendarAccess
    case explore
    /// A mini-app space (Nutrition, Fitness, Budget…), by its raw value.
    case space(String)
    case store

    static let scheme = "tessera"

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case let .design(id):
            components.host = "design"
            components.path = "/\(id.uuidString)"
        case .premium: components.host = "premium"
        case .tasks: components.host = "tasks"
        case .habits: components.host = "habits"
        case .hydration: components.host = "hydration"
        case .money: components.host = "money"
        case .weatherLocation: components.host = "weather"
        case .calendarAccess: components.host = "calendar"
        case .explore: components.host = "explore"
        case let .space(id):
            components.host = "space"
            components.path = "/\(id)"
        case .store: components.host = "store"
        }
        return components.url ?? URL(string: "tessera://explore")!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host else { return nil }
        switch host {
        case "design":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .design(id)
        case "premium": self = .premium
        case "tasks": self = .tasks
        case "habits": self = .habits
        case "hydration": self = .hydration
        case "money": self = .money
        case "weather": self = .weatherLocation
        case "calendar": self = .calendarAccess
        case "explore": self = .explore
        case "space":
            let id = url.lastPathComponent
            guard !id.isEmpty, id != "/" else { return nil }
            self = .space(id)
        case "store": self = .store
        default: return nil
        }
    }
}
