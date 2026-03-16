import Foundation
import UserNotifications

/// Protocol for posting user-visible notifications.
@MainActor
protocol NotificationServiceProtocol: AnyObject {
    func showNotification(title: String, message: String)
}

/// Concrete notification service backed by UserNotifications.
@MainActor
final class NotificationService: NotificationServiceProtocol {
    func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}