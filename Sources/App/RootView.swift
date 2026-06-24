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
                    // 左滑可跳过动画
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width < -60 {
                                    skipCover()
                                }
                            }
                    )
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
        // initial: true 关键 —— .onChange 默认不在初始值触发，会导致冷启动时
        // 即使开了隐私锁也不上锁（日记直接可见），只有切后台再回来才锁。
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background { lockManager.lockIfNeeded() }
            if phase == .active {
                if !coverRemoved { lockManager.lockIfNeeded() }
                // 回前台时结算连续记录保护：昨天漏写且前天在轨，就自动兜底，避免单日中断归零。
                DataManager.reconcileSaver(entries)
                // 回前台重算订阅权益，防止订阅过期后 isUnlocked 残留 true（白嫖）。
                Task { await PurchaseManager.shared.checkEntitlements() }
            }
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
                Image(systemName: lockManager.biometryIconName)
                    .font(.system(size: 48))
                    .foregroundStyle(pal.gold)
                Text("VoicePaper is locked")
                    .font(.dTitle)
                    .foregroundStyle(pal.gold)
                Button {
                    Task { await lockManager.unlock() }
                } label: {
                    Text("Try Again")
                        .font(.dCallout.weight(.semibold))
                        .foregroundStyle(pal.leather)
                        .padding(.horizontal, Metric.xxl)
                        .padding(.vertical, Metric.m)
                        .background(pal.gold, in: Capsule())
                }
            }
        }
        .task { await lockManager.unlock() }
    }
}
