import LocalAuthentication
import SwiftUI

@MainActor @Observable
final class PrivacyLockManager {
    var isLocked = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "privacyLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "privacyLockEnabled") }
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        let ctx = LAContext()
        var nsErr: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &nsErr) else {
            isLocked = false; return
        }
        let ok = (try? await ctx.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "解锁翻页日记"
        )) ?? false
        if ok { isLocked = false }
    }
}
