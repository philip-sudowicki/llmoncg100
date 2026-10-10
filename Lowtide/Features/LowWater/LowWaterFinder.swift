import MapKit
import Observation

/// The calm place chosen for someone who is overwhelmed right now.
struct LowWaterResult {
    let place: Place
    let location: GeoPoint
    /// False when nothing is calm and this is the quietest open place instead.
    let isCalm: Bool
    let statusText: String
    let minutes: Int
    let metres: Double
    let route: MKRoute?
    let instruction: String?
    let instructionDetail: String?
}

/// Picks the nearest low water: open places that are calm for the user now, the nearest three by
/// straight-line distance, then the shortest real walking time from Apple's directions.
@MainActor
@Observable
final class LowWaterFinder {
    enum State {
        case searching
        case found(LowWaterResult)
        case nothingOpen
    }

    private(set) var state: State = .searching
    private(set) var start: GeoPoint?

    func find(places: [Place], locations: [String: GeoPoint], engine: TideEngine, minute: Int, from start: GeoPoint) async {
        self.start = start
        state = .searching

        let snapshots = places.compactMap { place in
            locations[place.id].map { PlaceSnapshot(place: place, location: $0, engine: engine, minute: minute, from: start) }
        }
        let calm = snapshots
            .filter { $0.status == .calm }
            .sorted { $0.distance < $1.distance }

        var candidates = Array(calm.prefix(3))
        var isCalm = true
        if candidates.isEmpty {
            // Nothing is calm: offer the quietest open place nearby rather than nothing at all.
            let open = snapshots.filter(\.isOpen)
            let quietest = open.min { lhs, rhs in
                let left = engine.score(of: lhs.place, at: Double(minute))
                let right = engine.score(of: rhs.place, at: Double(minute))
                return left == right ? lhs.distance < rhs.distance : left < right
            }
            guard let quietest else {
                state = .nothingOpen
                return
            }
            candidates = [quietest]
            isCalm = false
        }

        let etas = await walkingETAs(to: candidates, from: start)
        let chosenIndex = etas.enumerated()
            .compactMap { index, eta in eta.map { (index, $0) } }
            .min { $0.1.travelTime < $1.1.travelTime }?
            .0 ?? 0
        let chosen = candidates[chosenIndex]

        let route = try? await DirectionsService.walkingRoute(from: start, to: chosen.location)
        let eta = etas[chosenIndex]
        let minutes = route.map { max(1, Int(($0.expectedTravelTime / 60).rounded())) } ?? eta?.minutes ?? chosen.walkMinutes
        let metres = route?.distance ?? eta?.distance ?? chosen.distance * Walking.detourFactor
        let step = route?.steps.first { !$0.instructions.trimmingCharacters(in: .whitespaces).isEmpty }

        state = .found(LowWaterResult(
            place: chosen.place,
            location: chosen.location,
            isCalm: isCalm,
            statusText: isCalm
                ? TideText.lowWaterStatus(chosen.change, now: minute)
                : "Quietest open place nearby · \(chosen.status?.title ?? "Open") for you now",
            minutes: minutes,
            metres: metres,
            route: route,
            instruction: step?.instructions,
            instructionDetail: step.map { "then \(TideText.distance(metres: $0.distance))" }
        ))
    }

    /// Walking ETAs for up to three places at once. Nil where directions are unavailable.
    private func walkingETAs(to candidates: [PlaceSnapshot], from start: GeoPoint) async -> [WalkingETA?] {
        var results = [WalkingETA?](repeating: nil, count: candidates.count)
        await withTaskGroup(of: (Int, WalkingETA?).self) { group in
            for (index, candidate) in candidates.enumerated() {
                let destination = candidate.location
                group.addTask {
                    (index, try? await DirectionsService.walkingETA(from: start, to: destination))
                }
            }
            for await (index, eta) in group {
                results[index] = eta
            }
        }
        return results
    }
}
