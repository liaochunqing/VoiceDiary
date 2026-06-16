import SwiftUI

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [PageData] = [
        PageData(icon: "book.closed.fill",
                 title: "这是你的日记",
                 body: "翻着看，像真正的日记本。每一页都是你的故事，只属于你。",
                 bg: false),
        PageData(icon: "mic.fill",
                 title: "用声音，也用文字",
                 body: "说出来，让它帮你整理成文字。转写全程在本机完成，不经过任何服务器。",
                 bg: false),
        PageData(icon: "icloud.fill",
                 title: "安全同步到你的 iCloud",
                 body: "日记和录音同步到你自己的私有 iCloud，我们看不到任何内容。",
                 bg: false),
    ]

    var body: some View {
        let pal = themeManager.palette
        let colors = themeManager.current.leatherGradient

        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 图标区
                ZStack {
                    Circle()
                        .fill(pal.gold.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: pages[page].icon)
                        .font(.system(size: 56))
                        .foregroundStyle(pal.gold)
                }
                .padding(.bottom, Metric.xl)

                // 文案区
                VStack(spacing: Metric.m) {
                    Text(pages[page].title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(pal.gold)
                        .multilineTextAlignment(.center)
                    Text(pages[page].body)
                        .font(.dBody)
                        .foregroundStyle(pal.gold.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Metric.xl)
                }

                Spacer()

                // 点指示器
                HStack(spacing: Metric.s) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? pal.gold : pal.gold.opacity(0.3))
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: page)
                    }
                }
                .padding(.bottom, Metric.xl)

                // 按钮
                VStack(spacing: Metric.m) {
                    Button {
                        if page < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                        } else {
                            onFinish()
                        }
                    } label: {
                        Text(page < pages.count - 1 ? "下一步" : "开始记录")
                            .font(.dCallout.weight(.semibold))
                            .foregroundStyle(colors.first ?? .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Metric.m)
                            .background(pal.gold, in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
                    }

                    if page == 0 {
                        Button("跳过引导") { onFinish() }
                            .font(.dCaption)
                            .foregroundStyle(pal.gold.opacity(0.5))
                    }
                }
                .padding(.horizontal, Metric.xl)
                .padding(.bottom, Metric.xxl)
            }
        }
        .animation(.easeInOut, value: page)
    }
}

private struct PageData {
    let icon: String
    let title: String
    let body: String
    let bg: Bool
}
