import Foundation

/// The app's notion of "now". Normally the real time; can be shifted to a fixed time of day for
/// demos and previews, for example with the launch argument `-demoTime 14:00`.
struct DemoClock: Sendable {
    /// Seconds added to the real time.
    let offset: TimeInterval

    static let real = DemoClock(offset: 0)

    /// Reads `demoTime` ("HH:mm") from user defaults, which includes launch arguments.
    static var live: DemoClock {
        guard let text = UserDefaults.standard.string(forKey: "demoTime"),
              let minute = try? ClockParsing.minutes(text)
        else { return .real }
        return startingAt(minute: minute)
    }

    /// A clock that reads `minute` (minutes since midnight) today, then runs normally.
    static func startingAt(minute: Int, from now: Date = Date(), calendar: Calendar = .current) -> DemoClock {
        let target = calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(minute * 60))
        return DemoClock(offset: target.timeIntervalSince(now))
    }

    var isShifted: Bool { offset != 0 }

    func now() -> Date {
        Date().addingTimeInterval(offset)
    }

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// The real date for a minute of the app's current day, for scheduling notifications.
    func realDate(forMinute minute: Int, calendar: Calendar = .current) -> Date {
        let shiftedDay = calendar.startOfDay(for: now())
        return shiftedDay.addingTimeInterval(TimeInterval(minute * 60) - offset)
    }
}
