import Foundation
import UserNotifications

enum CalmAlertResult: Equatable {
    case scheduled
    case permissionDenied
    case failed
}

/// Local "Alert me" notifications. Permission is requested only when the user first taps Alert me.
/// Alerts are silent: no sound, no badge.
@MainActor
enum NotificationService {
    private static let prefix = "calm-alert."

    static func identifier(for placeID: String) -> String {
        prefix + placeID
    }

    static func scheduleCalmAlert(placeID: String, title: String, body: String, at date: Date) async -> CalmAlertResult {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert]) else {
                return .permissionDenied
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try await center.add(UNNotificationRequest(identifier: identifier(for: placeID), content: content, trigger: trigger))
            return .scheduled
        } catch {
            return .failed
        }
    }

    static func cancelCalmAlert(placeID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: placeID)])
    }

    static func scheduledPlaceIDs() async -> Set<String> {
        let identifiers = await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
        return Set(identifiers.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) })
    }
}

/// Shows Alert me notifications as a banner even while Lowtide is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
