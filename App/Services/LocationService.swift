import CoreLocation
import Foundation

enum LocationError: LocalizedError {
    case denied
    case unavailable
    case notFound

    var errorDescription: String? {
        switch self {
        case .denied: "L'accès à la position est refusé. Tu peux l'autoriser dans Réglages, ou chercher ta ville."
        case .unavailable: "Ta position n'a pas pu être trouvée. Réessaie ou cherche ta ville."
        case .notFound: "Aucune ville trouvée."
        }
    }
}

/// City search (Apple geocoder, no key needed) and one-shot current location.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    static func search(_ query: String) async throws -> [WeatherLocation] {
        let trimmed = query.trimmed
        guard trimmed.count >= 2 else { return [] }
        let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
        let results = placemarks.compactMap { placemark -> WeatherLocation? in
            guard let location = placemark.location else { return nil }
            let city = placemark.locality ?? placemark.name ?? trimmed
            let detail = [placemark.administrativeArea, placemark.country].compactMap { $0 }.joined(separator: ", ")
            return WeatherLocation(
                name: detail.isEmpty ? city : "\(city), \(detail)",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
        if results.isEmpty { throw LocationError.notFound }
        return results
    }

    func currentLocation() async throws -> WeatherLocation {
        let location = try await requestLocation()
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return WeatherLocation(
            name: placemark?.locality ?? placemark?.name ?? "Ma position",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func requestLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        default:
            break
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation?.resume(throwing: LocationError.unavailable)
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.continuation != nil else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                self.finish(.failure(LocationError.denied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(LocationError.unavailable)) }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
