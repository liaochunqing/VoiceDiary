import SwiftUI
import UIKit
import SwiftData
import AVFoundation

// MARK: - BookNavigator

@MainActor
final class BookNavigator {
    fileprivate weak var coordinator: BookPageView.Coordinator?

    // 页面结构：[0=封面, 1=设置, 2=列表, 3..N=日记]
    // direction 由 navigate 根据目标 index 自动判断，确保多页连翻方向正确
    func goToList()                    { coordinator?.navigate(to: 2) }
    func goToSettings()                { coordinator?.navigate(to: 1) }
    func goToEntry(at entryIndex: Int) { coordinator?.navigate(to: entryIndex + 3) }
}

extension EnvironmentValues {
    @Entry var bookNavigator: BookNavigator = BookNavigator()
}

// MARK: - 主题感知包装（解决 UIHostingController 主题更新失效）

private struct ThemedPage<Content: View>: View {
    let themeManager: ThemeManager
    let navigator: BookNavigator
    let container: ModelContainer
    let content: Content

    var body: some View {
        content
            .modelContainer(container)
            .environment(themeManager)
            .environment(\.palette, themeManager.palette)
            .environment(\.bookNavigator, navigator)
    }
}

// MARK: - BookPageView

struct BookPageView: UIViewControllerRepresentable {
    @Environment(\.modelContext) private var modelContext
    let entries: [DiaryEntry]
    let themeManager: ThemeManager
    let navigator: BookNavigator

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(
            entries: entries,
            themeManager: themeManager,
            navigator: navigator,
            container: modelContext.container
        )
        navigator.coordinator = c
        return c
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate   = context.coordinator
        pvc.view.backgroundColor = .clear

        context.coordinator.loadSound()

        // 禁用 pageCurl 的单击翻页手势，保留拖拽；防止右侧 tap 触发翻页拦截 toggle 等控件
        for recognizer in pvc.gestureRecognizers where recognizer is UITapGestureRecognizer {
            recognizer.isEnabled = false
        }

        let startVC = context.coordinator.controllers[2]  // 列表页
        pvc.setViewControllers([startVC], direction: .forward, animated: false)
        context.coordinator.currentIndex = 2
        context.coordinator.pvc = pvc
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.updateEntries(entries, pvc: pvc)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        var controllers: [UIViewController] = []
        var currentIndex = 2
        weak var pvc: UIPageViewController?

        private let themeManager: ThemeManager
        private let navigator: BookNavigator
        private let container: ModelContainer
        private var entries: [DiaryEntry]

        private var audioPlayer: AVAudioPlayer?

        init(entries: [DiaryEntry], themeManager: ThemeManager,
             navigator: BookNavigator, container: ModelContainer) {
            self.themeManager = themeManager
            self.navigator    = navigator
            self.container    = container
            self.entries      = entries
            super.init()
            buildPages()
        }

        // MARK: 页面构建

        private func buildPages() {
            let coverVC    = makeVC(CoverView())
            let settingsVC = makeVC(SettingsView())
            let listVC     = makeVC(DiaryListView())
            let entryVCs   = entries.enumerated().map { i, entry in
                makeVC(DiaryDetailView(entry: entry, page: i + 1))
            }
            controllers = [coverVC, settingsVC, listVC] + entryVCs
        }

        private func makeVC<V: View>(_ view: V) -> UIViewController {
            let page = ThemedPage(themeManager: themeManager, navigator: navigator,
                                  container: container, content: view)
            let vc = UIHostingController(rootView: page)
            vc.view.backgroundColor = UIColor(themeManager.palette.paper)
            return vc
        }

        // MARK: 日记条目动态更新

        func updateEntries(_ newEntries: [DiaryEntry], pvc: UIPageViewController) {
            guard newEntries.map(\.id) != entries.map(\.id) else { return }

            let currentEntryID: UUID? = (currentIndex >= 3 && currentIndex - 3 < entries.count)
                ? entries[currentIndex - 3].id : nil

            entries = newEntries
            let entryVCs = entries.enumerated().map { i, entry in
                makeVC(DiaryDetailView(entry: entry, page: i + 1))
            }
            controllers = [controllers[0], controllers[1], controllers[2]] + entryVCs

            if currentIndex >= 3 {
                if let id = currentEntryID,
                   let newIdx = newEntries.firstIndex(where: { $0.id == id }) {
                    let target = newIdx + 3
                    pvc.setViewControllers([controllers[target]], direction: .forward, animated: false)
                    currentIndex = target
                } else {
                    navigate(to: 2, animated: true)
                }
            }
        }

        // MARK: 程序化翻页（支持多页连翻）

        func navigate(to target: Int, animated: Bool = true) {
            guard let pvc,
                  target >= 0, target < controllers.count,
                  target != currentIndex else { return }

            let direction: UIPageViewController.NavigationDirection = target > currentIndex ? .forward : .reverse
            let distance = abs(target - currentIndex)

            guard animated, distance > 1 else {
                // 单页翻 / 无动画：直接跳
                pvc.setViewControllers([controllers[target]], direction: direction, animated: animated) { [weak self] _ in
                    self?.currentIndex = target
                }
                if animated { playPageSound() }
                return
            }

            // 多页连翻：每隔 70 ms 翻一页，模拟翻书效果
            let step = direction == .forward ? 1 : -1
            let indices = Array(stride(from: currentIndex + step, through: target, by: step))

            for (offset, index) in indices.enumerated() {
                let delayNs = UInt64(offset) * 70_000_000   // 70 ms per page
                let vc = controllers[index]
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: delayNs)
                    pvc.setViewControllers([vc], direction: direction, animated: true) { [weak self] _ in
                        self?.currentIndex = index
                    }
                    playPageSound()
                }
            }
        }

        // MARK: 翻页音效

        func loadSound() {
            guard let url = Bundle.main.url(forResource: "fp3", withExtension: "m4a") else { return }
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        }

        private func playPageSound() {
            // @AppStorage 默认值 true 不会写入 UserDefaults，键缺失时 bool(forKey:) 返回 false，
            // 会导致全新安装翻页静音（与设置开关显示的「开」不一致）。键缺失按 true 处理。
            let soundOn = UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true
            guard soundOn else { return }
            guard let player = audioPlayer else { return }
            if player.isPlaying { player.stop(); player.currentTime = 0 }
            player.play()
        }
    }
}

// MARK: - DataSource / Delegate

extension BookPageView.Coordinator: UIPageViewControllerDataSource {
    nonisolated func pageViewController(_ pvc: UIPageViewController,
                                        viewControllerBefore vc: UIViewController) -> UIViewController? {
        MainActor.assumeIsolated {
            guard let idx = controllers.firstIndex(of: vc), idx > 0 else { return nil }
            return controllers[idx - 1]
        }
    }

    nonisolated func pageViewController(_ pvc: UIPageViewController,
                                        viewControllerAfter vc: UIViewController) -> UIViewController? {
        MainActor.assumeIsolated {
            guard let idx = controllers.firstIndex(of: vc),
                  idx + 1 < controllers.count else { return nil }
            return controllers[idx + 1]
        }
    }
}

extension BookPageView.Coordinator: UIPageViewControllerDelegate {
    nonisolated func pageViewController(_ pvc: UIPageViewController,
                                        willTransitionTo pending: [UIViewController]) {
        MainActor.assumeIsolated { playPageSound() }
    }

    nonisolated func pageViewController(_ pvc: UIPageViewController,
                                        didFinishAnimating finished: Bool,
                                        previousViewControllers: [UIViewController],
                                        transitionCompleted completed: Bool) {
        guard completed else { return }
        MainActor.assumeIsolated {
            if let vc = pvc.viewControllers?.first,
               let idx = controllers.firstIndex(of: vc) {
                currentIndex = idx
            }
        }
    }
}
