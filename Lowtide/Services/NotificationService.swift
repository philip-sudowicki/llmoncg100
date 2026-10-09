import Foundation
import Observation
import UserNotifications

/// Schedules the quiet, local "Alert me" notifications. Permission is only requested when the
/// user first taps Alert me.
@MainActor
@Observable
final class NotificationService {
    enum Outcome: Equatable {
        case scheduled(minute: Int)
        case notAllowed
        case failed
    }

    /// Pending alerts: place ID to the minute after midnight they fire.
    private(set) var scheduled: [String: Int] = [:]

    private nonisolated static let placeKey = "placeID"
    private nonisolated static let minuteKey = "minute"

    static func identifier(for placeID: String) -> String {
        "lowtide.calm.\(placeID)"
    }

    /// Reloads alerts that are still pending, for example after a relaunch.
    func refresh() async {
        let pending: [(String, Int)] = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { @Sendable requests in
                let alerts = requests.compactMap { request -> (String, Int)? in
                    guard let place = request.content.userInfo[Self.placeKey] as? String,
                          let minute = request.content.userInfo[Self.minuteKey] as? Int else { return nil }
                    return (place, minute)
                }
                continuation.resume(returning: alerts)
            }
        }
        scheduled = Dictionary(pending, uniquingKeysWith: { _, latest in latest })
    }

    func schedule(placeID: String, placeName: String, atMinute minute: Int) async -> Outcome {
        guard await requestPermission() else { return .notAllowed }

        let content = UNMutableNotificationContent()
        content.title = "Low tide at \(placeName)"
        content.body = "It should be calm for you from about \(TimeText.time(minute)). Take your time."
        // No sound: alerts stay gentle.
        content.sound = nil
        content.userInfo = [Self.placeKey: placeID, Self.minuteKey: minute]

        var components = DateComponents()
        components.hour = minute / 60
        components.minute = minute % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(for: placeID), content: content, trigger: trigger)

        let added: Bool = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { @Sendable error in
                continuation.resume(returning: error == nil)
            }
        }
        guard added else { return .failed }
        scheduled[placeID] = minute
        return .scheduled(minute: minute)
    }

    func cancel(placeID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: placeID)])
        scheduled[placeID] = nil
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { @Sendable granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
