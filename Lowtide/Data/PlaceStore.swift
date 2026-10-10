import Foundation
import Observation

/// Places, the demo centre they are laid out around, and the current time.
@MainActor
@Observable
final class PlaceStore {
    private(set) var places: [Place]
    /// Where the sample places are anchored: the user's first location fix, or central London.
    private(set) var centre: GeoPoint?
    private(set) var now: Date
    private(set) var loadFailed = false
    /// True while the places are laid out around central London because no location was available.
    private(set) var isFallbackCentre = false

    private let repository: any PlaceRepository
    let clock: DemoClock

    init(repository: any PlaceRepository = LocalPlaceRepository(), clock: DemoClock = .live, places: [Place] = [], centre: GeoPoint? = nil) {
        self.repository = repository
        self.clock = clock
        self.places = places
        self.centre = centre
        self.now = clock.now()
    }

    var minuteOfDay: Int { DemoClock.minuteOfDay(now) }

    func load() async {
        guard places.isEmpty else { return }
        do {
            places = try await repository.loadPlaces()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    /// Keeps `now` fresh so statuses update while the app is open. Only publishes when the
    /// minute changes, so the map isn't redrawn needlessly.
    func runClock() async {
        while !Task.isCancelled {
            let latest = clock.now()
            if DemoClock.minuteOfDay(latest) != minuteOfDay {
                now = latest
            }
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                return
            }
        }
    }

    func refreshNow() {
        now = clock.now()
    }

    /// Sets the demo centre once. Later location updates move the user, not the places, except
    /// that a fallback centre (central London) is replaced by the first real location fix.
    func anchor(at point: GeoPoint, isFallback: Bool = false) {
        guard centre == nil || (isFallbackCentre && !isFallback) else { return }
        centre = point
        isFallbackCentre = isFallback
    }

    func place(id: String) -> Place? {
        places.first { $0.id == id }
    }

    func location(of place: Place) -> GeoPoint {
        (centre ?? .centralLondon).offset(by: place.offset)
    }
}
