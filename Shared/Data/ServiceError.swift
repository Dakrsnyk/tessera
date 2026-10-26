import Foundation

/// The two ways a web service can fail (no valid answer, or an answer that can't be read), shared by
/// the services that fetch prices, rates and food data.
enum ServiceError: LocalizedError {
    case badResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .badResponse: tr("Le service n'a pas répondu.")
        case .decoding: tr("Les données reçues sont illisibles.")
        }
    }
}
