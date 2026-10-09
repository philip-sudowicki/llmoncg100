import Foundation

/// A span of minutes since midnight, end exclusive.
struct TimeWindow: Equatable, Hashable, Sendable {
    let start: Int
    let end: Int

    var duration: Int { end - start }
    var midpoint: Int { (start + end) / 2 }
}

/// What happens next at a place, from the user's point of view.
enum TideChange: Equatable, Sendable {
    /// Calm now, then busy or high tide from this minute.
    case calmUntil(Int)
    /// Calm now and until the place closes at this minute.
    case calmUntilClosing(Int)
    /// Not calm now, calm from this minute.
    case calmFrom(Int)
    /// Not calm now and not calm again before closing.
    case notCalmAgainToday
    /// Closed now. Opens at this minute (today or tomorrow, as the forecast repeats daily).
    case closed(opensAt: Int)
}

/// One point on a place's personal tide curve.
struct TidePoint: Identifiable, Equatable, Sendable {
    let minute: Int
    let score: Double

    var id: Int { minute }
}

/// When a place is usually calmest across its opening hours.
enum Takeaway: Equatable, Sendable {
    /// Calm the whole time it is open.
    case calmAllDay
    /// Calm for at least `mostOfTheDayMinutes` in one stretch.
    case calmMostOfTheDay
    case calmest(TimeWindow)
    /// Never calm for this profile, so name the quietest time instead.
    case quietest(Int)

    static let mostOfTheDayMinutes = 6 * 60
}

/// Turns a place's forecast and the user's sensitivities into personal scores and statuses.
///
/// - The score for a moment is the maximum over all factors of `value × weight`, so the worst
///   trigger dominates.
/// - Below 0.4 is Calm (low tide), below 0.7 is Busy and 0.7 or above is High tide.
/// - A closed place has no status.
struct TideEngine: Sendable {
    static let calmLimit = 0.4
    static let highLimit = 0.7
    /// "Good match for you" needs this many calm minutes ahead.
    static let goodMatchMinutes = 180

    let sensitivities: [Factor: Sensitivity]

    init(sensitivities: [Factor: Sensitivity]) {
        self.sensitivities = sensitivities
    }

    init(profile: SensoryProfile) {
        self.init(sensitivities: profile.sensitivities)
    }

    func sensitivity(for factor: Factor) -> Sensitivity {
        sensitivities[factor] ?? .some
    }

    func weight(for factor: Factor) -> Double {
        sensitivity(for: factor).weight
    }

    // MARK: Scores and status

    func score(_ levels: FactorLevels) -> Double {
        Factor.allCases.map { levels[$0] * weight(for: $0) }.max() ?? 0
    }

    static func status(forScore score: Double) -> TideStatus {
        if score < calmLimit { return .calm }
        if score < highLimit { return .busy }
        return .high
    }

    func score(of place: Place, at minute: Double) -> Double {
        score(place.forecast.levels(at: minute))
    }

    func status(of place: Place, at minute: Int) -> TideStatus? {
        guard place.hours.isOpen(at: minute) else { return nil }
        return Self.status(forScore: score(of: place, at: Double(minute)))
    }

    private func isCalm(_ place: Place, at minute: Int) -> Bool {
        score(of: place, at: Double(minute)) < Self.calmLimit
    }

    // MARK: Changes and windows

    /// The next time the user's calm/not-calm state flips before closing, found minute by minute
    /// on the interpolated forecast, so half-hour changes are possible.
    func nextChange(for place: Place, at minute: Int) -> TideChange {
        let hours = place.hours
        guard hours.isOpen(at: minute) else { return .closed(opensAt: hours.opens) }
        let calmNow = isCalm(place, at: minute)
        for later in (minute + 1)..<max(minute + 1, hours.closes) where isCalm(place, at: later) != calmNow {
            return calmNow ? .calmUntil(later) : .calmFrom(later)
        }
        return calmNow ? .calmUntilClosing(hours.closes) : .notCalmAgainToday
    }

    /// Calm spans between two minutes, clipped to opening hours.
    func calmWindows(for place: Place, from start: Int, to end: Int) -> [TimeWindow] {
        let first = max(start, place.hours.opens)
        let last = min(end, place.hours.closes)
        guard first < last else { return [] }
        var windows: [TimeWindow] = []
        var runStart: Int?
        for minute in first..<last {
            if isCalm(place, at: minute) {
                if runStart == nil { runStart = minute }
            } else if let began = runStart {
                windows.append(TimeWindow(start: began, end: minute))
                runStart = nil
            }
        }
        if let began = runStart {
            windows.append(TimeWindow(start: began, end: last))
        }
        return windows
    }

    /// The longest calm window from now until closing. Ties go to the earlier window.
    func bestWindow(for place: Place, from minute: Int) -> TimeWindow? {
        Self.longest(calmWindows(for: place, from: minute, to: place.hours.closes))
    }

    /// The next calm window that starts after this minute, used by Alert me.
    func nextCalmWindow(for place: Place, after minute: Int) -> TimeWindow? {
        calmWindows(for: place, from: minute, to: place.hours.closes).first { $0.start > minute }
    }

    /// True when the place stays open and calm for the next three hours.
    func isGoodMatch(_ place: Place, at minute: Int) -> Bool {
        let end = minute + Self.goodMatchMinutes
        guard place.hours.isOpen(at: minute), end <= place.hours.closes else { return false }
        return (minute..<end).allSatisfy { isCalm(place, at: $0) }
    }

    /// When the place is usually calmest across the whole opening day.
    func takeaway(for place: Place) -> Takeaway {
        if let best = Self.longest(calmWindows(for: place, from: place.hours.opens, to: place.hours.closes)) {
            if best.start == place.hours.opens, best.end == place.hours.closes { return .calmAllDay }
            if best.duration >= Takeaway.mostOfTheDayMinutes { return .calmMostOfTheDay }
            return .calmest(best)
        }
        let samples = stride(from: place.hours.opens, to: place.hours.closes, by: 30)
        let quietest = samples.min { score(of: place, at: Double($0)) < score(of: place, at: Double($1)) }
        return .quietest(quietest ?? place.hours.opens)
    }

    /// The personal score through opening hours, for charts and sparklines.
    func curve(for place: Place, step: Int = 30) -> [TidePoint] {
        var points = stride(from: place.hours.opens, to: place.hours.closes, by: max(step, 1)).map {
            TidePoint(minute: $0, score: score(of: place, at: Double($0)))
        }
        points.append(TidePoint(minute: place.hours.closes, score: score(of: place, at: Double(place.hours.closes))))
        return points
    }

    // MARK: Triggers

    /// Triggers worth a heads-up chip: those whose factor the user marked Some or A lot.
    func headsUps(for place: Place) -> [PlaceTrigger] {
        place.triggers.filter { sensitivity(for: $0.tag.factor).wantsHeadsUps }
    }

    private static func longest(_ windows: [TimeWindow]) -> TimeWindow? {
        windows.reduce(nil) { best, window in
            guard let best else { return window }
            return window.duration > best.duration ? window : best
        }
    }
}
