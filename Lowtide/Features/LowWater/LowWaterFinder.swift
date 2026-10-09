import Foundation
import Observation

/// The nearest calm place by walking time, for "Find low water".
struct LowWaterResult: Equatable {
    let place: Place
    let destination: GeoPoint
    /// `nil` if walking directions were unavailable; times are then estimated.
    let route: WalkingRoute?
    let minutes: Int
    let metres: Double
    let change: TideChange
}

@MainActor
@Observable
final class LowWaterFinder {
    enum Phase: Equatable {
        case searching
        case found(LowWaterResult)
        case nothingCalm
    }

    private(set) var phase: Phase = .searching

    /// Takes the open places that are calm now, asks MapKit for walking routes to the nearest
    /// three by straight-line distance, and picks the shortest walk.
    func find(places: [Place], engine: TideEngine, minute: Int, origin: GeoPoint, anchor: GeoPoint) async {
        phase = .searching
        let candidates = LowWaterPicker.candidates(
            from: places, engine: engine, atMinute: minute, origin: origin, anchor: anchor
        )
        guard !candidates.isEmpty else {
            phase = .nothingCalm
            return
        }

        var routes: [Int: WalkingRoute] = [:]
        await withTaskGroup(of: (Int, WalkingRoute?).self) { group in
            for (index, place) in candidates.enumerated() {
                let destination = place.position(around: anchor)
                group.addTask {
                    (index, try? await DirectionsService.walkingRoute(from: origin, to: destination))
                }
            }
            for await (index, route) in group {
                if let route { routes[index] = route }
            }
        }

        let choice: (index: Int, route: WalkingRoute?)
        if let fastest = routes.min(by: { $0.value.travelTime < $1.value.travelTime }) {
            choice = (fastest.key, fastest.value)
        } else {
            // No directions (offline, for example): fall back to the nearest by distance.
            choice = (0, nil)
        }

        let place = candidates[choice.index]
        let destination = place.position(around: anchor)
        let straightLine = origin.distance(to: destination)
        phase = .found(LowWaterResult(
            place: place,
            destination: destination,
            route: choice.route,
            minutes: choice.route?.minutes ?? Walking.estimatedMinutes(straightLineMetres: straightLine),
            metres: choice.route?.distance ?? straightLine * Walking.detourFactor,
            change: engine.nextChange(for: place, atMinute: minute)
        ))
    }
}
