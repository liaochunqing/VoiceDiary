import SwiftUI

struct RootView: View {
    @Environment(\.palette) private var pal
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var opened = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingDone")
    @State private var lockManager = PrivacyLockManager()

    var body: some View {
        ZStack {
            if opened {
                NavigationStack {
                    DiaryListView()
                }
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
        .animation(.easeInOut(duration: 0.35), value: opened)
        // 隐私锁遮罩
        .overlay {
            if lockManager.isLocked {
                lockScreen
            }
        }
        // 初次引导
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "onboardingDone")
                showOnboarding = false
            }
        }
        // 进入后台后锁屏
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lockManager.lockIfNeeded() }
        }
    }

    // MARK: 锁屏遮罩

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
        .transition(.opacity)
    }
}
