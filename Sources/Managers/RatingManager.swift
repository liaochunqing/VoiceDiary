import StoreKit
import UIKit

/// 评分请求调度：仅在用户高光时刻请求，且完全交给系统限频决定弹不弹。
enum RatingManager {
    /// 保存日记后调用。在第 5/20 篇或连续打卡 7 天时请求评分。
    static func tryRequestReview(entryCount: Int, streak: Int) {
        let shouldAsk = entryCount == 5 || entryCount == 20 || streak == 7
        guard shouldAsk else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
