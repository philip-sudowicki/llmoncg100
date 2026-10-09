import Foundation

/// Plain-English text for times and tide changes. Pure Swift so it can be unit-tested.
enum TideText {
    static let minutesPerDay = 24 * 60

    // MARK: Times

    /// "9am", "3:30pm", "12pm", "midnight".
    static func clock(_ minute: Int) -> String {
        if minute == minutesPerDay { return "midnight" }
        let wrapped = ((minute % minutesPerDay) + minutesPerDay) % minutesPerDay
        let hour24 = wrapped / 60
        let minutes = wrapped % 60
        let suffix = hour24 < 12 ? "am" : "pm"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        if minutes == 0 { return "\(hour12)\(suffix)" }
        return "\(hour12):\(minutes < 10 ? "0" : "")\(minutes)\(suffix)"
    }

    /// "9–10am", "11am–1pm", "3:30–5pm".
    static func range(from start: Int, to end: Int) -> String {
        let startText = clock(start)
        let endText = clock(end)
        let sameHalf = (start < 12 * 60) == (end < 12 * 60) && end != minutesPerDay
        if sameHalf, startText.hasSuffix("am") || startText.hasSuffix("pm") {
            return "\(startText.dropLast(2))–\(endText)"
        }
        return "\(startText)–\(endText)"
    }

    /// Forecasts are hourly, so changes are shown to the nearest half hour.
    /// If that would land at or before now, the next five minutes is used instead.
    static func displayMinute(_ minute: Int, now: Int) -> Int {
        let rounded = Int((Double(minute) / 30).rounded()) * 30
        if rounded > now { return rounded }
        return ((minute + 4) / 5) * 5
    }

    // MARK: Tide changes

    /// "Calm until 3:30pm", "Calm from 3pm", "Not calm again today", "Closed · opens 9am".
    static func nextChange(_ change: TideChange, now: Int) -> String {
        switch change {
        case .calmUntil(let minute):
            "Calm until \(clock(displayMinute(minute, now: now)))"
        case .calmUntilClosing(let closes):
            "Calm until \(clock(closes))"
        case .calmFrom(let minute):
            "Calm from \(clock(displayMinute(minute, now: now)))"
        case .notCalmAgainToday:
            "Not calm again today"
        case .closed(let opens):
            "Closed · opens \(clock(opens))"
        }
    }

    /// Spoken status for map pins, for example "calm until 3:30pm" or "busy, calm from 3pm".
    static func spokenStatus(_ status: TideStatus?, change: TideChange, now: Int) -> String {
        let changeText = lowercasedFirst(nextChange(change, now: now))
        switch status {
        case .calm: return changeText
        case .busy: return "busy, \(changeText)"
        case .high: return "high tide, \(changeText)"
        case nil: return changeText.replacingOccurrences(of: " · ", with: ", ")
        }
    }

    /// The status banner on the place page.
    static func banner(status: TideStatus?, change: TideChange, now: Int, place: Place) -> (title: String, detail: String) {
        let title: String
        switch status {
        case .calm: title = "Low tide now"
        case .busy: title = "Busy for you now"
        case .high: title = "High tide now"
        case nil: title = "Closed now"
        }

        let detail: String
        switch change {
        case .calmUntil(let minute):
            let then = period(near: minute, in: place).map { ", then \($0.name)" } ?? ""
            detail = "Calm until about \(clock(displayMinute(minute, now: now)))\(then)."
        case .calmUntilClosing(let closes):
            detail = "Calm until it closes at \(clock(closes))."
        case .calmFrom(let minute):
            detail = "Calm from about \(clock(displayMinute(minute, now: now)))."
        case .notCalmAgainToday:
            detail = "It won't be calm for you again before it closes at \(clock(place.hours.closes))."
        case .closed(let opens):
            detail = "Opens at \(clock(opens))."
        }
        return (title, detail)
    }

    /// A named busy spell that starts around (or contains) a minute.
    static func period(near minute: Int, in place: Place) -> NamedPeriod? {
        place.periods.first { minute >= $0.start - 30 && minute < $0.end }
    }

    // MARK: Place details

    static func openingLine(for place: Place, now: Int) -> String {
        if place.hours.isOpen(at: now) {
            return "Open until \(clock(place.hours.closes))"
        }
        return "Closed · opens \(clock(place.hours.opens))"
    }

    static func walk(minutes: Int) -> String {
        "\(minutes) min walk"
    }

    /// "Best time: now until 3:30pm" or "Best time: 5:30–7pm".
    static func bestTime(_ window: TimeWindow?, now: Int, closes: Int) -> String {
        guard let window else { return "No calm time left today" }
        let end = window.end == closes ? window.end : displayMinute(window.end, now: now)
        if window.start <= now {
            return "Best time: now until \(clock(end))"
        }
        return "Best time: \(range(from: displayMinute(window.start, now: now), to: end))"
    }

    /// "Usually calmest mid-afternoon".
    static func takeaway(_ takeaway: Takeaway) -> String {
        switch takeaway {
        case .calmAllDay:
            "Usually calm the whole time it's open"
        case .calmMostOfTheDay:
            "Usually calm for most of the day"
        case .calmest(let window):
            "Usually calmest \(partOfDay(window.midpoint))"
        case .quietest(let minute):
            "Rarely calm for you. Quietest around \(clock(minute))"
        }
    }

    static func partOfDay(_ minute: Int) -> String {
        switch minute {
        case ..<(9 * 60): "early in the morning"
        case ..<(12 * 60): "in the morning"
        case ..<(14 * 60): "around lunchtime"
        case ..<(16 * 60 + 30): "mid-afternoon"
        case ..<(18 * 60): "late afternoon"
        default: "in the evening"
        }
    }

    /// "Quiet hour on weekdays, 9–10am".
    static func quietHour(_ quietHour: QuietHour) -> String {
        let days: String
        switch quietHour.days {
        case "weekdays": days = " on weekdays"
        case "daily": days = " every day"
        case "weekends": days = " at weekends"
        default: days = ""
        }
        return "Quiet hour\(days), \(range(from: quietHour.start, to: quietHour.end))"
    }

    // MARK: How it feels

    /// A 1 to 5 meter level for a normalised value.
    static func meterLevel(_ value: Double) -> Int {
        min(max(1 + Int((value * 4).rounded()), 1), 5)
    }

    /// Plain-English description of a factor at a place, for example "Quiet · about 45 dB".
    /// Place-specific notes replace the generic wording for light, crowds and smells.
    static func feeling(_ factor: Factor, at place: Place, minute: Int) -> String {
        let levels = place.forecast.levels(at: Double(minute))
        switch factor {
        case .noise:
            let decibels = place.forecast.decibels(at: Double(minute))
            let word = place.notes.noise ?? SoundLevel.noiseWord(decibels)
            return "\(word) · about \(SoundLevel.roundedForDisplay(decibels)) dB"
        case .sudden:
            return describe(levels.sudden, ["Hardly any sudden sounds", "The odd sudden sound", "Some sudden sounds", "Frequent sudden sounds"])
        case .light:
            return place.notes.light ?? describe(levels.light, ["Soft, even light", "Mostly soft light", "Bright in places", "Harsh or flickering light"])
        case .crowd:
            return place.notes.crowd ?? describe(levels.crowd, ["Nearly empty", "A few people, plenty of space", "Fairly busy", "Packed"])
        case .smell:
            return place.notes.smell ?? describe(levels.smell, ["Nothing noticed", "Faint smells", "Noticeable smells", "Strong smells"])
        }
    }

    /// Picks one of four phrases for a value from 0 to 1.
    private static func describe(_ value: Double, _ phrases: [String]) -> String {
        switch value {
        case ..<0.2: phrases[0]
        case ..<0.45: phrases[1]
        case ..<0.7: phrases[2]
        default: phrases[3]
        }
    }

    /// "You checked in: Calm · 2:14pm", with the weekday when it wasn't today.
    static func checkIn(_ feeling: CheckInFeeling, at date: Date, today: Date, calendar: Calendar = .current) -> String {
        let time = clock(DemoClock.minuteOfDay(date, calendar: calendar))
        if calendar.isDate(date, inSameDayAs: today) {
            return "You checked in: \(feeling.title) · \(time)"
        }
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        return "You checked in: \(feeling.title) · \(weekday) \(time)"
    }

    static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }
}
