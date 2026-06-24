import LocalAuthentication
import SwiftUI

@MainActor @Observable
final class PrivacyLockManager {
    var isLocked = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "privacyLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "privacyLockEnabled") }
    }

    /// 根据设备能力返回合适的 SF Symbol 名。
    var biometryIconName: String {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return "lock.fill"
        }
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        let ctx = LAContext()
        var nsErr: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &nsErr) else {
            // 设备无密码/生物识别 —— 不能静默绕过锁定，但给出降级通道
            // UserDefaults 标记，下次进设置可关闭
            UserDefaults.standard.set(false, forKey: "privacyLockEnabled")
            isLocked = false
            return
        }
        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Unlock VoicePaper")
            )
            if ok { isLocked = false }
        } catch {
            // 用户取消 / 验证失败 —— 保持锁定，不做任何事
        }
    }
}
