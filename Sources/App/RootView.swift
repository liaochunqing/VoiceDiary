import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.palette) private var pal
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    // 封面翻页动画
    @State private var coverAngle: Double = 0
    @State private var coverRemoved = false

    // 日记条目（给 BookPageView 用）
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    // 导航桥
    @State private var navigator = BookNavigator()

    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingDone")
    @State private var lockManager = PrivacyLockManager()

    var body: some View {
        ZStack {
            // 主体：真翻页 UIPageViewController
            BookPageView(entries: entries, themeManager: themeManager, navigator: navigator)
                .ignoresSafeArea()

            // 封面覆盖层：启动时自动翻开
            if !coverRemoved {
                CoverView()
                    .contentShape(Rectangle())
                    .rotation3DEffect(
                        .degrees(coverAngle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.5
                    )
                    .shadow(
                        color: .black.opacity(max(0, 0.45 * (1 + coverAngle / 90))),
                        radius: 20, x: 12, y: 0
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(coverAngle == 0)
                    // 点击可跳过动画
                    .onTapGesture { skipCover() }
                    .onAppear { startCoverAnimation() }
            }
        }
        .overlay {
            if lockManager.isLocked {
                lockScreen.transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "onboardingDone")
                showOnboarding = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lockManager.lockIfNeeded() }
        }
    }

    // MARK: 封面动画

    private func startCoverAnimation() {
        withAnimation(.easeIn(duration: 1.0)) {
            coverAngle = -90
        } completion: {
            coverRemoved = true
        }
    }

    private func skipCover() {
        withAnimation(.easeIn(duration: 0.3)) {
            coverAngle = -90
        } completion: {
            coverRemoved = true
        }
    }

    // MARK: 隐私锁屏

    private var lockScreen: some View {
        ZStack {
            pal.leather.ignoresSafeArea()
            VStack(spacing: Metric.l) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(pal.gold)
                Text("翻页日记已锁定")
                    .font(.dTitle)
                    .foregroundStyle(pal.gold)
                Button {
                    Task { await lockManager.unlock() }
                } label: {
                    Text("解锁")
                        .font(.dCallout.weight(.semibold))
                        .foregroundStyle(pal.leather)
                        .padding(.horizontal, Metric.xxl)
                        .padding(.vertical, Metric.m)
                        .background(pal.gold, in: Capsule())
                }
            }
        }
    }
}
