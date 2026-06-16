import UserNotifications
import SwiftUI

@MainActor @Observable
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let timeKey = "reminderTime"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "reminderEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "reminderEnabled")
            if newValue { scheduleReminder() } else { cancelReminder() }
        }
    }

    // 提醒时间，默认晚上 21:00
    var reminderTime: Date {
        get {
            if let saved = UserDefaults.standard.object(forKey: timeKey) as? Date { return saved }
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.hour = 21; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: timeKey)
            if isEnabled { scheduleReminder() }
        }
    }

    func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted && isEnabled { scheduleReminder() }
        return granted
    }

    func checkStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    private func scheduleReminder() {
        cancelReminder()
        let content = UNMutableNotificationContent()
        content.title = "今天还没写日记"
        content.body = "来记录一下今天吧，哪怕只是一句话 ✍️"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        center.add(req)
    }

    private func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
}
