import UserNotifications
import SwiftUI

@MainActor @Observable
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let enabledKey = "reminderEnabled"
    private let timeKey = "reminderTime"

    /// 是否开启每日提醒。存储属性 → 可被 @Observable 追踪，开关切换后界面能即时刷新。
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                scheduleReminder()
                cancelWinback()        // 开了每日提醒已有日常触达，撤掉挽回避免同日重复
            } else {
                cancelReminder()
                rescheduleWinback()    // 关了每日提醒 → 靠 3/7/30 天挽回兜底
            }
        }
    }

    /// 提醒时间，默认晚上 21:00。
    var reminderTime: Date {
        didSet {
            UserDefaults.standard.set(reminderTime, forKey: timeKey)
            if isEnabled { scheduleReminder() }
        }
    }

    /// 系统层通知授权状态。界面据此判断该弹授权框还是引导去设置。
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// 系统层已拒绝（无法再弹授权框，只能去系统设置开启）。
    var isDeniedBySystem: Bool { authorizationStatus == .denied }

    init() {
        // 注意：init 内的首次赋值不会触发 didSet，故不会在启动时误调度。
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        if let saved = UserDefaults.standard.object(forKey: timeKey) as? Date {
            reminderTime = saved
        } else {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.hour = 21; c.minute = 0
            reminderTime = Calendar.current.date(from: c) ?? Date()
        }
    }

    /// 同步系统授权状态，并在系统层已被关闭时把开关复位（避免界面显示「开」但其实收不到）。
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus == .denied && isEnabled {
            isEnabled = false
        }
    }

    /// 请求通知权限。返回是否已授权（已授权 / 本次授权都算 true）。
    /// notDetermined → 弹出 app 内系统授权框；denied → 直接返回 false（无法再弹框）。
    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            // 用户在授权框上做出选择后刷新状态。
            await refreshAuthorizationStatus()
            return granted
        @unknown default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// App 启动时调用：开着提醒就续期，把未来调度窗口补满（多天非重复通知会用完）。
    /// NotificationManager 的设置都从 UserDefaults 读，故可 new 一个临时实例来调用，无需共享。
    func refreshScheduleIfNeeded() {
        guard isEnabled else { return }
        scheduleReminder()
    }

    /// 今天写完日记后调用：撤掉今晚那条提醒，避免「明明写了还被催」。
    func cancelTodayReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID(for: Date())])
    }

    /// 调度未来若干天，每天一条本地通知，正文用当天的「今日提问」——
    /// 把提醒从「催你写」变成「给你一个话题」，契合「对它说话」，且每天不重样。
    private func scheduleReminder() {
        cancelReminder()
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: reminderTime)
        let now = Date()

        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            var dc = cal.dateComponents([.year, .month, .day], from: day)
            dc.hour = hm.hour
            dc.minute = hm.minute
            // 今天若已过提醒时间，跳过——避免立刻弹一条。
            guard let fireDate = cal.date(from: dc), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Open the book. Talk to it.")
            content.body = DailyPrompt.today(day)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            let req = UNNotificationRequest(identifier: reminderID(for: day), content: content, trigger: trigger)
            center.add(req)
        }
    }

    private func cancelReminder() {
        let cal = Calendar.current
        // 旧版单条 id + 当前调度窗口附近的逐日 id 一并清掉。
        var ids = ["dailyReminder"]
        for offset in -1..<30 {
            if let day = cal.date(byAdding: .day, value: offset, to: Date()) {
                ids.append(reminderID(for: day))
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func reminderID(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "dailyReminder-\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    // MARK: 静默挽回（win-back）

    /// 写完一篇后调用：以「本次保存」为锚点，重排 3/7/30 天后的挽回通知。
    /// 仅对**未开每日提醒**的用户排——开了每日提醒的已有日常触达，再叠挽回会同日重复打扰。
    /// 用户每写一篇就把这三个计时往后推，只有在真正停写后才依次触发。
    func rescheduleWinback() {
        cancelWinback()
        guard !isEnabled else { return }
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: reminderTime)
        let now = Date()
        for offset in [3, 7, 30] {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            var dc = cal.dateComponents([.year, .month, .day], from: day)
            dc.hour = hm.hour
            dc.minute = hm.minute
            guard let fireDate = cal.date(from: dc), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Open the book. Talk to it.")
            content.body = winbackBody(offset)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            let req = UNNotificationRequest(identifier: "winback-\(offset)", content: content, trigger: trigger)
            center.add(req)
        }
    }

    private func cancelWinback() {
        center.removePendingNotificationRequests(withIdentifiers: ["winback-3", "winback-7", "winback-30"])
    }

    private func winbackBody(_ offset: Int) -> String {
        switch offset {
        case 3:  return String(localized: "It's been a few days. The book's still here when you are.")
        case 7:  return String(localized: "A week without you. Open the book — even one line counts.")
        case 30: return String(localized: "Your diary misses you. Come back and tell it about today.")
        default: return String(localized: "Open the book. Talk to it.")
        }
    }
}
