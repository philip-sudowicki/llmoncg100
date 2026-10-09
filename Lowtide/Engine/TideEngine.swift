import Foundation

/// A span of time today, in minutes after midnight. `end` is exclusive.
struct TimeWindow: Hashable, Sendable {
    let start: Int
    let end: Int

    var duration: Int { end - start }
}

/// One point on a place's personal tide curve.
struct TidePoint: Hashable, Sendable, Identifiable {
    let minute: Int
    let score: Double

    var id: Int { minute }
}

/// A run of the same status, used for summaries and the VoiceOver chart description.
struct TideSegment: Hashable, Sendable {
    let status: TideStatus
    let start: Int
    let end: Int
}

/// What happens next at a place.
enum TideChange: Hashable, Sendable {
    /// Calm now, and it stops being calm at this time.
    case calmUntil(Int)
    /// Calm now, and it stays calm until it closes at this time.
    case calmUntilClosing(Int)
    /// Not calm now, and calm from this time.
    case calmFrom(Int)
    /// Not calm now, and no calm time before it closes at this time.
    case noCalmBeforeClosing(Int)
    /// Closed now. Opens at this time, later today or tomorrow.
    case opens(Int, tomorrow: Bool)

    func text(style: TimeStyle = .current) -> String {
        switch self {
        case .calmUntil(let minute):
            "Calm until \(TimeText.time(minute, style: style))"
        case .calmUntilClosing(let minute):
            "Calm until it closes at \(TimeText.time(minute, style: style))"
        case .calmFrom(let minute):
            "Calm from \(TimeText.time(minute, style: style))"
        case .noCalmBeforeClosing(let minute):
            "No calm time before it closes at \(TimeText.time(minute, style: style))"
        case .opens(let minute, let tomorrow):
            tomorrow
                ? "Closed · opens tomorrow at \(TimeText.time(minute, style: style))"
                : "Closed · opens at \(TimeText.time(minute, style: style))"
        }
    }
}

/// Turns a place's forecast and the user's profile into a personal tide.
///
/// Pure Swift with no UI or platform dependencies, so it is fully unit-tested.
struct TideEngine: Sendable {
    static let calmThreshold = 0.4
    static let highThreshold = 0.7
    /// Changes are reported on a half-hour grid, using interpolated values between hours.
    static let stepMinutes = 30
    /// "Good match for you" looks this far ahead.
    static let goodMatchHorizon = 180

    var profile: SensoryProfile

    init(profile: SensoryProfile) {
        self.profile = profile
    }

    /// Maps decibels to 0–1: 40 dB or quieter is 0, 80 dB or louder is 1.
    static func normalisedNoise(decibels: Double) -> Double {
        min(max((decibels - 40) / 40, 0), 1)
    }

    // MARK: Scores and status

    /// The personal score: the worst weighted factor dominates.
    func score(_ values: FactorValues) -> Double {
        Factor.allCases.map { values[$0] * profile.weight(for: $0) }.max() ?? 0
    }

    func score(of place: Place, atMinute minute: Int) -> Double {
        score(place.forecast.values(atMinute: Double(minute)))
    }

    /// The status right now, or `nil` while the place is closed.
    func status(of place: Place, atMinute minute: Int) -> TideStatus? {
        guard place.hours.isOpen(atMinute: minute) else { return nil }
        return TideStatus(score: score(of: place, atMinute: minute))
    }

    private func isCalm(_ place: Place, atMinute minute: Int) -> Bool {
        TideStatus(score: score(of: place, atMinute: minute)) == .calm
    }

    // MARK: Changes and windows

    func nextChange(for place: Place, atMinute now: Int) -> TideChange {
        let hours = place.hours
        if now < hours.open { return .opens(hours.open, tomorrow: false) }
        if now >= hours.close { return .opens(hours.open, tomorrow: true) }

        let calmNow = isCalm(place, atMinute: now)
        for minute in Self.grid(after: now, before: hours.close) where isCalm(place, atMinute: minute) != calmNow {
            return calmNow ? .calmUntil(minute) : .calmFrom(minute)
        }
        return calmNow ? .calmUntilClosing(hours.close) : .noCalmBeforeClosing(hours.close)
    }

    /// Calm windows from now (or opening time) until closing, in order.
    func calmWindows(for place: Place, from now: Int) -> [TimeWindow] {
        let hours = place.hours
        guard now < hours.close else { return [] }
        let start = max(now, hours.open)
        let points = [start] + Array(Self.grid(after: start, before: hours.close))

        var windows: [TimeWindow] = []
        var runStart: Int?
        for minute in points {
            let calm = isCalm(place, atMinute: minute)
            if calm, runStart == nil {
                runStart = minute
            } else if !calm, let begin = runStart {
                windows.append(TimeWindow(start: begin, end: minute))
                runStart = nil
            }
        }
        if let begin = runStart {
            windows.append(TimeWindow(start: begin, end: hours.close))
        }
        return windows
    }

    /// The longest calm window from now until closing. Ties go to the earlier window.
    func bestWindow(for place: Place, atMinute now: Int) -> TimeWindow? {
        var best: TimeWindow?
        for window in calmWindows(for: place, from: now) where window.duration > (best?.duration ?? 0) {
            best = window
        }
        return best
    }

    /// When "Alert me" should fire: the start of the next calm window after now.
    func nextCalmStart(for place: Place, atMinute now: Int) -> Int? {
        calmWindows(for: place, from: now).first { $0.start > now }?.start
    }

    /// Open now and calm for the next three hours (or until closing, if sooner).
    func isGoodMatch(_ place: Place, atMinute now: Int) -> Bool {
        guard place.hours.isOpen(atMinute: now) else { return false }
        let horizon = min(place.hours.close, now + Self.goodMatchHorizon)
        let points = [now] + Array(Self.grid(after: now, before: horizon))
        return points.allSatisfy { isCalm(place, atMinute: $0) }
    }

    // MARK: Heads-up triggers

    /// Triggers worth a heads-up for this profile: those tied to a factor set to Some or A lot.
    func headsUp(for place: Place) -> [Trigger] {
        place.triggers.filter { profile[sensitivity: $0.factor].wantsHeadsUp }
    }

    // MARK: Curves

    /// The personal score through opening hours, for charts and sparklines.
    func series(for place: Place, stepMinutes: Int = 15) -> [TidePoint] {
        let hours = place.hours
        var minutes = Array(stride(from: hours.open, to: hours.close, by: stepMinutes))
        minutes.append(hours.close)
        return minutes.map { TidePoint(minute: $0, score: score(of: place, atMinute: $0)) }
    }

    /// Runs of the same status through opening hours, on the half-hour grid.
    func segments(for place: Place) -> [TideSegment] {
        let hours = place.hours
        let points = [hours.open] + Array(Self.grid(after: hours.open, before: hours.close))
        var segments: [TideSegment] = []
        var current: (status: TideStatus, start: Int)?
        for minute in points {
            let status = TideStatus(score: score(of: place, atMinute: minute))
            if let run = current, run.status != status {
                segments.append(TideSegment(status: run.status, start: run.start, end: minute))
                current = (status, minute)
            } else if current == nil {
                current = (status, minute)
            }
        }
        if let run = current {
            segments.append(TideSegment(status: run.status, start: run.start, end: hours.close))
        }
        return segments
    }

    /// The middle of the calmest two hours of the day, used for "Usually calmest mid-afternoon".
    func calmestMinute(for place: Place) -> Int? {
        let hours = place.hours
        let span = 120
        guard hours.close - hours.open >= span else { return nil }
        var bestMinute: Int?
        var bestAverage = Double.infinity
        for start in stride(from: hours.open, through: hours.close - span, by: Self.stepMinutes) {
            let samples = stride(from: start, through: start + span, by: Self.stepMinutes).map {
                score(of: place, atMinute: $0)
            }
            let average = samples.reduce(0, +) / Double(samples.count)
            // Small differences are noise: prefer a clearly calmer window, else keep the earlier one.
            if average < bestAverage - 0.01 {
                bestAverage = average
                bestMinute = start + span / 2
            }
        }
        return bestMinute
    }

    /// Half-hour marks strictly after `now` and strictly before `end`.
    static func grid(after now: Int, before end: Int) -> StrideTo<Int> {
        let first = (now / stepMinutes + 1) * stepMinutes
        return stride(from: first, to: end, by: stepMinutes)
    }
}
