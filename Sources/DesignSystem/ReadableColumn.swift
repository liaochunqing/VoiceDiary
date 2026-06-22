import SwiftUI

/// 把内容限制在一条「可读栏」里并水平居中。
///
/// iPhone 上屏幕宽 < `maxWidth`，限宽不生效、表现与原来完全一致；
/// iPad（含横屏）上把正文收窄成一栏书页宽度居中，避免衬线正文拉成超长行、
/// 整页被拉大失去精装本的窄栏书页感。
extension View {
    func readableColumn(_ maxWidth: CGFloat = Metric.readableWidth) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)   // 外层撑满可用宽度，内层默认居中
    }
}

extension Metric {
    /// 可读栏最大宽度：一本书页常见的舒适行宽，iPhone 触不到。
    static let readableWidth: CGFloat = 680
}
