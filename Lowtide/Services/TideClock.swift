import Foundation
import Observation

/// The current time of day, refreshed every 20 seconds so statuses stay current.
@MainActor
@Observable
final class TideClock {
    private(set) var now = Date.now

    /// Pins the time of day for demos, previews and screenshots.
    @ObservationIgnored let fixedMinute: Int?

    init(fixedMinute: Int? = nil) {
        self.fixedMinute = fixedMinute
    }

    var minuteOfDay: Int {
        if let fixedMinute { return fixedMinute }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// "Friday".
    var weekday: String {
        now.formatted(.dateTime.weekday(.wide))
    }

    func run() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            now = .now
        }
    }
}

/// Launch arguments for demos and screenshots. Debug builds only.
///
/// - `-LowtideDemoTime 14:10` fixes the time of day.
/// - `-LowtideDemoScreen <screen>` opens a screen with sample settings and nothing saved:
///   `onboarding`, `map`, `place:<id>`, `checkin:<id>`, `lowwater`, `cards` or `profile`.
enum DemoOptions {
    enum Screen: Equatable {
        case onboarding
        case map
        case place(String)
        case checkIn(String)
        case lowWater
        case cards
        case profile

        init?(_ raw: String) {
            let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
            switch (parts.first, parts.count > 1 ? parts[1] : nil) {
            case ("onboarding", _): self = .onboarding
            case ("map", _): self = .map
            case ("place", let id?): self = .place(id)
            case ("checkin", let id?): self = .checkIn(id)
            case ("lowwater", _): self = .lowWater
            case ("cards", _): self = .cards
            case ("profile", _): self = .profile
            default: return nil
            }
        }
    }

    static var fixedMinute: Int? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "LowtideDemoTime").flatMap(ClockTime.minutes(from:))
        #else
        nil
        #endif
    }

    static var screen: Screen? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "LowtideDemoScreen").flatMap(Screen.init)
        #else
        nil
        #endif
    }
}
