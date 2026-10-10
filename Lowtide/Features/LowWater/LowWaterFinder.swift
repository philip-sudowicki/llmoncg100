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
///
/// The screen must stay fast on a poor connection, so the walking-time requests run in parallel
/// and the answer appears as soon as they are all back or after a few seconds, whichever comes
/// first (falling back to straight-line estimates). The route map and first instruction are added
/// when the route arrives.
@MainActor
@Observable
final class LowWaterFinder {
    enum State {
        case searching
        case found(LowWaterResult)
        case nothingOpen
    }

    /// The longest the user waits before seeing a place.
    static let directionsTimeout: Duration = .seconds(4)

    private(set) var state: State = .searching
    private(set) var start: GeoPoint?
    /// A short sentence for VoiceOver when a place is found.
    private(set) var announcement: String?

    @ObservationIgnored private var search = 0
    @ObservationIgnored private var candidates: [PlaceSnapshot] = []
    @ObservationIgnored private var etas: [WalkingETA?] = []
    @ObservationIgnored private var answers = 0
    @ObservationIgnored private var candidatesAreCalm = true
    @ObservationIgnored private var minute = 0

    func find(places: [Place], locations: [String: GeoPoint], engine: TideEngine, minute: Int, from start: GeoPoint) {
        search += 1
        let current = search
        self.start = start
        self.minute = minute
        state = .searching
        announcement = nil

        let snapshots = places.compactMap { place in
            locations[place.id].map { PlaceSnapshot(place: place, location: $0, engine: engine, minute: minute, from: start) }
        }
        let calm = snapshots
            .filter { $0.status == .calm }
            .sorted { $0.distance < $1.distance }

        if calm.isEmpty {
            // Nothing is calm: offer the quietest open place nearby rather than nothing at all.
            let quietest = snapshots.filter(\.isOpen).min { lhs, rhs in
                let left = engine.score(of: lhs.place, at: Double(minute))
                let right = engine.score(of: rhs.place, at: Double(minute))
                return left == right ? lhs.distance < rhs.distance : left < right
            }
            guard let quietest else {
                state = .nothingOpen
                announcement = "Nothing nearby is open right now."
                return
            }
            candidates = [quietest]
            candidatesAreCalm = false
        } else {
            // Prefer places that stay calm and open until well after the user gets there.
            let lasting = calm.filter { $0.staysCalm(afterWalkingFrom: minute) }
            candidates = Array((lasting.isEmpty ? calm : lasting).prefix(3))
            candidatesAreCalm = true
        }

        etas = Array(repeating: nil, count: candidates.count)
        answers = 0
        for (index, candidate) in candidates.enumerated() {
            let destination = candidate.location
            Task { [weak self] in
                let eta = try? await DirectionsService.walkingETA(from: start, to: destination)
                self?.receive(eta, at: index, search: current)
            }
        }
        Task { [weak self] in
            try? await Task.sleep(for: Self.directionsTimeout)
            self?.choose(search: current)
        }
    }

    private func receive(_ eta: WalkingETA?, at index: Int, search current: Int) {
        guard current == search, case .searching = state, etas.indices.contains(index) else { return }
        etas[index] = eta
        answers += 1
        if answers == candidates.count {
            choose(search: current)
        }
    }

    /// Shows the shortest walk, then fetches its route. Places whose walking time hasn't arrived yet
    /// are compared using a straight-line estimate, so a slow answer never loses to a farther place.
    private func choose(search current: Int) {
        guard current == search, case .searching = state, !candidates.isEmpty, let start else { return }
        let index = candidates.indices.min { lhs, rhs in
            travelTime(at: lhs) < travelTime(at: rhs)
        } ?? 0
        let chosen = candidates[index]
        let eta = etas[index]
        let result = makeResult(chosen, eta: eta, route: nil)
        state = .found(result)
        announcement = "\(chosen.place.name), \(result.minutes) minute walk."

        let destination = chosen.location
        Task { [weak self] in
            let route = try? await DirectionsService.walkingRoute(from: start, to: destination)
            self?.attach(route, to: chosen, eta: eta, search: current)
        }
    }

    private func travelTime(at index: Int) -> TimeInterval {
        etas[index]?.travelTime ?? TimeInterval(candidates[index].walkMinutes * 60)
    }

    /// Called each minute while the screen is open. Keeps "quiet until" current, and returns false
    /// when the chosen place no longer stays calm long enough, so the caller can search again.
    func refresh(engine: TideEngine, minute: Int) -> Bool {
        guard case .found(let shown) = state, shown.isCalm, let start else { return true }
        let snapshot = PlaceSnapshot(place: shown.place, location: shown.location, engine: engine, minute: minute, from: start)
        guard snapshot.status == .calm, snapshot.staysCalm(afterWalkingFrom: minute) else { return false }
        self.minute = minute
        state = .found(LowWaterResult(
            place: shown.place,
            location: shown.location,
            isCalm: true,
            statusText: TideText.lowWaterStatus(snapshot.change, now: minute),
            minutes: shown.minutes,
            metres: shown.metres,
            route: shown.route,
            instruction: shown.instruction,
            instructionDetail: shown.instructionDetail
        ))
        return true
    }

    private func attach(_ route: MKRoute?, to chosen: PlaceSnapshot, eta: WalkingETA?, search current: Int) {
        guard current == search, let route, case .found(let shown) = state, shown.place.id == chosen.id else { return }
        state = .found(makeResult(chosen, eta: eta, route: route))
    }

    private func makeResult(_ chosen: PlaceSnapshot, eta: WalkingETA?, route: MKRoute?) -> LowWaterResult {
        let minutes = route.map { max(1, Int(($0.expectedTravelTime / 60).rounded())) } ?? eta?.minutes ?? chosen.walkMinutes
        let metres = route?.distance ?? eta?.distance ?? chosen.distance * Walking.detourFactor
        let step = route?.steps.first { !$0.instructions.trimmingCharacters(in: .whitespaces).isEmpty }
        return LowWaterResult(
            place: chosen.place,
            location: chosen.location,
            isCalm: candidatesAreCalm,
            statusText: candidatesAreCalm
                ? TideText.lowWaterStatus(chosen.change, now: minute)
                : "Quietest open place nearby · \(chosen.status?.title ?? "Open") for you now",
            minutes: minutes,
            metres: metres,
            route: route,
            instruction: step?.instructions,
            instructionDetail: step.map { "then \(TideText.distance(metres: $0.distance))" }
        )
    }
}
