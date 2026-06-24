import SwiftUI

extension View {
    /// 与 `.sheet(isPresented:)` 等价，但在 sheet 弹出时给背后的呈现视图盖一层蒙层，
    /// 把背景压暗、强化前后层次，避免 sheet 与背后窗口混在一起看不清。
    ///
    /// 蒙层是呈现视图自身的 overlay，绘制在 sheet 之下；非全高 detent 时尤其明显。
    /// 不拦截触摸（`allowsHitTesting(false)`），不影响系统下滑关闭等手势。
    func dimmedSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .overlay {
                Color.black
                    .opacity(isPresented.wrappedValue ? 0.28 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.3), value: isPresented.wrappedValue)
            }
            .sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
}
