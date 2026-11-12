import Foundation
import UserNotifications

/// A tray-change reminder ready to hand to the notification center.
struct ChangeReminder: Sendable {
  let fireDate: Date
  let title: String
  let body: String
}

/// Schedules the single pending tray-change notification.
struct NotificationScheduler: Sendable {
  static let shared = NotificationScheduler()

  private static let reminderIdentifier = "tray-change-next"

  /// Replaces the pending reminder, or clears it when `reminder` is `nil`.
  func schedule(_ reminder: ChangeReminder?) async {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    guard let reminder else { return }

    let content = UNMutableNotificationContent()
    content.title = reminder.title
    content.body = reminder.body
    content.sound = .default

    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: reminder.fireDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let request = UNNotificationRequest(
      identifier: Self.reminderIdentifier,
      content: content,
      trigger: trigger
    )
    try? await center.add(request)
  }

  /// Requests authorization when needed and reports whether alerts are allowed.
  func ensureAuthorization() async -> Bool {
    let status = await UNUserNotificationCenter.current()
      .notificationSettings()
      .authorizationStatus
    switch status {
    case .notDetermined:
      return await requestAuthorization()
    case .authorized, .provisional, .ephemeral:
      return true
    default:
      return false
    }
  }

  private func requestAuthorization() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound])
    } catch {
      return false
    }
  }
}
