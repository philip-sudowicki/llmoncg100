import Foundation

/// Plain-English sentences about a place's tide, shared by the map, the place page and VoiceOver.
struct TideNarrative: Sendable {
    let engine: TideEngine
    var style: TimeStyle = .current

    private func time(_ minute: Int) -> String {
        TimeText.time(minute, style: style)
    }

    /// "Calm until 3:30pm", "Calm from 3pm", "Closed · opens at 9am".
    func statusLine(for place: Place, atMinute now: Int) -> String {
        engine.nextChange(for: place, atMinute: now).text(style: style)
    }

    /// For VoiceOver: "calm until 3:30pm" or "busy now, calm from 3pm".
    func spokenStatus(for place: Place, atMinute now: Int) -> String {
        let change = engine.nextChange(for: place, atMinute: now)
        switch engine.status(of: place, atMinute: now) {
        case .calm:
            return change.text(style: style).lowercasedFirst
        case .busy, .high:
            let status = engine.status(of: place, atMinute: now)?.title.lowercased() ?? ""
            return "\(status) now, \(change.text(style: style).lowercasedFirst)"
        case nil:
            return change.text(style: style).replacingOccurrences(of: " · ", with: ", ").lowercasedFirst
        }
    }

    /// "Open until 7pm", "Opens at 9am", "Closed · opens tomorrow at 9am".
    func hoursLine(for place: Place, atMinute now: Int) -> String {
        let hours = place.hours
        if now < hours.open { return "Opens at \(time(hours.open))" }
        if now >= hours.close { return "Closed · opens tomorrow at \(time(hours.open))" }
        return "Open until \(time(hours.close))"
    }

    func bannerTitle(for status: TideStatus?) -> String {
        switch status {
        case .calm: "Low tide now"
        case .busy: "Busy for you now"
        case .high: "High tide now"
        case nil: "Closed now"
        }
    }

    /// "Calm until about 3:30pm, then the after-school rush."
    func bannerDetail(for place: Place, atMinute now: Int) -> String {
        switch engine.nextChange(for: place, atMinute: now) {
        case .calmUntil(let minute):
            let reason = busyPeriod(for: place, near: minute)?.label ?? "it gets busier"
            return "Calm until about \(time(minute)), then \(reason)."
        case .calmUntilClosing(let minute):
            return "Calm until it closes at \(time(minute))."
        case .calmFrom(let minute):
            if let rush = busyPeriod(for: place, containing: now) {
                return "Calm from about \(time(minute)), once \(rush.label) eases."
            }
            return "Calm from about \(time(minute))."
        case .noCalmBeforeClosing(let minute):
            return "No calm time for you before it closes at \(time(minute))."
        case .opens(let minute, let tomorrow):
            if tomorrow { return "Opens tomorrow at \(time(minute))." }
            let calm = engine.nextCalmStart(for: place, atMinute: now).map { " Calm from \(time($0))." } ?? ""
            return "Opens at \(time(minute)).\(calm)"
        }
    }

    /// "Best time: now until 3:30pm".
    func bestTimeLine(for place: Place, atMinute now: Int) -> String {
        guard let window = engine.bestWindow(for: place, atMinute: now) else {
            return now >= place.hours.close ? "Closed for today" : "No calm time left today"
        }
        if window.start <= now {
            return "Best time: now until \(time(window.end))"
        }
        return "Best time: \(TimeText.range(from: window.start, to: window.end, style: style))"
    }

    /// "Usually calmest mid-afternoon".
    func takeaway(for place: Place) -> String {
        let segments = engine.segments(for: place)
        if segments.allSatisfy({ $0.status == .calm }) { return "Usually calm for you all day" }
        if !segments.contains(where: { $0.status == .calm }) { return "Rarely calm for you, even at its quietest" }
        guard let minute = engine.calmestMinute(for: place) else { return "Usually calm at some point in the day" }
        return "Usually calmest \(Self.partOfDay(minute))"
    }

    /// A spoken summary of the chart for VoiceOver.
    func chartSummary(for place: Place, atMinute now: Int) -> String {
        let segments = engine.segments(for: place).map { segment in
            let range = TimeText.range(from: segment.start, to: segment.end, style: style)
            return "\(segment.status.title) \(range)"
        }
        var sentences = [segments.joined(separator: ", ")]
        if place.hours.isOpen(atMinute: now) {
            sentences.append("Now: \(spokenStatus(for: place, atMinute: now))")
        }
        sentences.append(bestTimeLine(for: place, atMinute: now))
        return sentences.joined(separator: ". ") + "."
    }

    static func partOfDay(_ minute: Int) -> String {
        switch minute {
        case ..<(11 * 60): "in the morning"
        case ..<(14 * 60): "around midday"
        case ..<(16 * 60 + 30): "mid-afternoon"
        case ..<(18 * 60): "late afternoon"
        default: "in the evening"
        }
    }

    private func busyPeriod(for place: Place, near minute: Int) -> BusyPeriod? {
        place.busyPeriods.first { abs($0.start - minute) <= 45 }
    }

    private func busyPeriod(for place: Place, containing minute: Int) -> BusyPeriod? {
        place.busyPeriods.first { $0.start <= minute && minute < $0.end }
    }
}

extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
