import SwiftUI

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [PageData] = [
        PageData(icon: "book.closed.fill",
                 title: "This is your diary",
                 body: "Flip through it like a real journal. Every page is your story — and yours alone."),
        PageData(icon: "mic.fill",
                 title: "Use your voice, or type",
                 body: "Just speak, and it turns into text for you. Transcription runs entirely on your device — never through a server."),
        PageData(icon: "icloud.fill",
                 title: "Synced safely to your iCloud",
                 body: "Entries and recordings sync to your own private iCloud. We can't see any of it."),
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
                        .font(.dSerifPageTitle)
                        .foregroundStyle(pal.gold)
                        .multilineTextAlignment(.center)
                    Text(pages[page].body)
                        .font(.dSerifBody)
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
                        Text(page < pages.count - 1 ? "Next" : "Start writing")
                            .font(.dCallout.weight(.semibold))
                            .foregroundStyle(colors.first ?? .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Metric.m)
                            .background(pal.gold, in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
                    }

                    if page == 0 {
                        Button("Skip") { onFinish() }
                            .font(.dCaption)
                            .foregroundStyle(pal.gold.opacity(0.5))
                    }
                }
                .padding(.horizontal, Metric.xl)
                .padding(.bottom, Metric.xxl)
            }
            .readableColumn()
        }
        .animation(.easeInOut, value: page)
    }
}

private struct PageData {
    let icon: String
    let title: String
    let body: String
}
