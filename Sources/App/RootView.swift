import SwiftUI

/// 第一里程碑：封面 →（轻触翻开）→ 日记列表。
/// 后续接入 pageCurl 翻页引擎、写日记、详情、设置、录音等。
struct RootView: View {
    @State private var opened = false

    var body: some View {
        ZStack {
            if opened {
                DiaryListView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                CoverView()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.45)) { opened = true }
                    }
                    .transition(.move(edge: .leading))
            }
        }
    }
}
