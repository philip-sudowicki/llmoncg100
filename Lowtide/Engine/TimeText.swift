import Foundation

/// Parses "HH:mm" strings into minutes after midnight.
enum ClockTime {
    static func minutes(from text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...24).contains(hour), (0..<60).contains(minute) else { return nil }
        let total = hour * 60 + minute
        return total <= 24 * 60 ? total : nil
    }
}

/// Whether times read "3:30pm" or "15:30".
enum TimeStyle: Sendable {
    case twelveHour
    case twentyFourHour

    /// Follows the user's 12- or 24-hour setting.
    static var current: TimeStyle {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return format.contains("H") || format.contains("k") ? .twentyFourHour : .twelveHour
    }
}

/// Short, friendly times: "3pm", "3:30pm", "midnight".
enum TimeText {
    static func time(_ minute: Int, style: TimeStyle = .current) -> String {
        let wrapped = ((minute % 1440) + 1440) % 1440
        let hour = wrapped / 60
        let minutes = wrapped % 60
        switch style {
        case .twentyFourHour:
            return String(format: "%02d:%02d", hour, minutes)
        case .twelveHour:
            if wrapped == 0 { return "midnight" }
            return clock12(hour: hour, minutes: minutes) + (hour < 12 ? "am" : "pm")
        }
    }

    /// A range such as "9–10am", "11am–1pm" or "09:00–10:00".
    static func range(from start: Int, to end: Int, style: TimeStyle = .current) -> String {
        switch style {
        case .twentyFourHour:
            return "\(time(start, style: style))–\(time(end, style: style))"
        case .twelveHour:
            let startHalf = (start % 1440) < 720
            let endHalf = (end % 1440) < 720
            let endIsMidnight = end % 1440 == 0
            if startHalf == endHalf, !endIsMidnight, start % 1440 != 0 {
                let startText = clock12(hour: (start % 1440) / 60, minutes: start % 60)
                return "\(startText)–\(time(end, style: style))"
            }
            return "\(time(start, style: style))–\(time(end, style: style))"
        }
    }

    private static func clock12(hour: Int, minutes: Int) -> String {
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return minutes == 0 ? "\(displayHour)" : String(format: "%d:%02d", displayHour, minutes)
    }
}
