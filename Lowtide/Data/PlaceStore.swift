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

    /// Keeps `now` fresh so statuses update while the app is open.
    func runClock() async {
        while !Task.isCancelled {
            now = clock.now()
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

    /// Sets the demo centre once. Later location updates move the user, not the places.
    func anchor(at point: GeoPoint) {
        guard centre == nil else { return }
        centre = point
    }

    func place(id: String) -> Place? {
        places.first { $0.id == id }
    }

    func location(of place: Place) -> GeoPoint {
        (centre ?? .centralLondon).offset(by: place.offset)
    }
}
