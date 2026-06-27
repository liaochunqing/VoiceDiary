import SwiftUI

extension View {
    /// 与 `.sheet(isPresented:)` 等价，但在 sheet 弹出时给背后的呈现视图盖一层蒙层，
    /// 把背景压暗、强化前后层次，避免 sheet 与背后窗口混在一起看不清。
    ///
    /// 蒙层是呈现视图自身的 overlay，绘制在 sheet 之下；非全高 detent 时尤其明显。
    /// 不拦截触摸（`allowsHitTesting(false)`），不影响系统下滑关闭等手势。
    ///
    /// `detents` 传 nil（默认）时不设置 presentationDetents，保留系统默认行为；
    /// 传具体值时才生效，避免显式 .large 改变内部子 sheet 的高度计算。
    func dimmedSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent>? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .overlay {
                Color.black
                    .opacity(isPresented.wrappedValue ? 0.35 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.05), value: isPresented.wrappedValue)
            }
            .sheet(isPresented: isPresented, onDismiss: onDismiss) {
                content().modifier(ApplyDetenetsIfNeeded(detents: detents))
            }
    }
}

private struct ApplyDetenetsIfNeeded: ViewModifier {
    let detents: Set<PresentationDetent>?
    func body(content: Content) -> some View {
        if let detents {
            content.presentationDetents(detents)
        } else {
            content
        }
    }
}
