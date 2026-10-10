import CoreLocation
import Observation

/// Wraps `CLLocationManager` with when-in-use permission only. Locations stay on the device.
@MainActor
@Observable
final class LocationService {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var location: CLLocation? = nil

    private let manager: CLLocationManager
    private let delegate: LocationDelegate

    init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.delegate = LocationDelegate()
        self.authorization = manager.authorizationStatus
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 15
        delegate.authorizationChanged = { [weak self] status in
            self?.handleAuthorization(status)
        }
        delegate.locationChanged = { [weak self] location in
            self?.location = location
        }
        manager.delegate = delegate
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    /// Denied, restricted, or Location Services switched off.
    var isUnavailable: Bool {
        authorization == .denied || authorization == .restricted
    }

    /// Asks for when-in-use permission the first time, then starts updates once allowed.
    func start() {
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    var point: GeoPoint? {
        location.map { GeoPoint($0.coordinate) }
    }

    /// The location only when it is recent (under 15 s old) and accurate to 100 m, so the places
    /// aren't laid out around a cached or cell-tower position.
    var precisePoint: GeoPoint? {
        guard let location,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 100,
              location.timestamp.timeIntervalSinceNow > -15
        else { return nil }
        return GeoPoint(location.coordinate)
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorization = status
        if isAuthorized {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }
}

/// Receives Core Location callbacks, which arrive on the main thread because the manager was created there.
private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var authorizationChanged: (@MainActor (CLAuthorizationStatus) -> Void)?
    var locationChanged: (@MainActor (CLLocation) -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationChanged?(status)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        MainActor.assumeIsolated {
            locationChanged?(latest)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // Temporary failures (no fix yet) are expected. The map falls back to the demo centre.
    }
}
