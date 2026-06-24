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

        context.coordinator.pvc = pvc
        let startVC = context.coordinator.vc(for: 2)  // 列表页
        pvc.setViewControllers([startVC], direction: .forward, animated: false)
        context.coordinator.currentIndex = 2
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.updateEntries(entries, pvc: pvc)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        var currentIndex = 2
        weak var pvc: UIPageViewController?

        private let themeManager: ThemeManager
        private let navigator: BookNavigator
        private let container: ModelContainer
        private var entries: [DiaryEntry]

        private var audioPlayer: AVAudioPlayer?

        // 懒加载页缓存：index → VC，以及反向 VC → index（dataSource 据此找邻页）。
        // 不再常驻全部日记页：内存与日记数量解耦，最多常驻 cacheCapacity 个日记页 + 3 个固定页。
        private var vcCache: [Int: UIViewController] = [:]
        private var indexByVC: [ObjectIdentifier: Int] = [:]
        /// 日记页常驻上限（封面/设置/目录三页固定常驻、不计入此数）。
        private let cacheCapacity = 7

        // 页面结构：0=封面, 1=设置, 2=目录, 3..N=日记（日记 i 在 index i+3）
        private var pageCount: Int { 3 + entries.count }

        init(entries: [DiaryEntry], themeManager: ThemeManager,
             navigator: BookNavigator, container: ModelContainer) {
            self.themeManager = themeManager
            self.navigator    = navigator
            self.container    = container
            self.entries      = entries
            super.init()
        }

        // MARK: 页面懒加载 + 缓存

        /// 取指定 index 的页面 VC：命中缓存直接返回，否则即时构建并缓存，随后按需淘汰远处页。
        func vc(for index: Int) -> UIViewController {
            if let cached = vcCache[index] { return cached }
            let vc = makeContentVC(for: index)
            vcCache[index] = vc
            indexByVC[ObjectIdentifier(vc)] = index
            evictIfNeeded(justInserted: index)
            return vc
        }

        private func makeContentVC(for index: Int) -> UIViewController {
            switch index {
            case 0:  return makeVC(CoverView())
            case 1:  return makeVC(SettingsView())
            case 2:  return makeVC(DiaryListView())
            default: return makeVC(DiaryDetailView(entry: entries[index - 3], page: index - 2))
            }
        }

        private func makeVC<V: View>(_ view: V) -> UIViewController {
            let page = ThemedPage(themeManager: themeManager, navigator: navigator,
                                  container: container, content: view)
            let vc = UIHostingController(rootView: page)
            vc.view.backgroundColor = UIColor(themeManager.palette.paper)
            return vc
        }

        /// 淘汰离当前页最远的日记页，把常驻日记页数压回 cacheCapacity。
        /// 绝不淘汰：① 固定页 0/1/2；② 正在显示的页（pvc 仍强引用它，丢映射会让滑动找不到邻页）；
        /// ③ 本次刚插入的页（远距跳转时目标页离旧 currentIndex 很远，否则会被误删）。
        private func evictIfNeeded(justInserted: Int) {
            let entryIdxs = vcCache.keys.filter { $0 >= 3 }
            guard entryIdxs.count > cacheCapacity else { return }
            let displayed = Set((pvc?.viewControllers ?? []).compactMap { indexByVC[ObjectIdentifier($0)] })
            let protected = displayed.union([justInserted])
            let evictable = entryIdxs
                .filter { !protected.contains($0) }
                .sorted { abs($0 - currentIndex) > abs($1 - currentIndex) }
            for idx in evictable.prefix(entryIdxs.count - cacheCapacity) {
                if let vc = vcCache.removeValue(forKey: idx) {
                    indexByVC.removeValue(forKey: ObjectIdentifier(vc))
                }
            }
        }

        /// 日记数据变动后，作废所有日记页缓存（index→日记 的映射已变），固定页保留。
        private func evictAllEntryVCs() {
            for idx in vcCache.keys.filter({ $0 >= 3 }) {
                if let vc = vcCache.removeValue(forKey: idx) {
                    indexByVC.removeValue(forKey: ObjectIdentifier(vc))
                }
            }
        }

        // MARK: 日记条目动态更新

        func updateEntries(_ newEntries: [DiaryEntry], pvc: UIPageViewController) {
            guard newEntries.map(\.id) != entries.map(\.id) else { return }

            let currentEntryID: UUID? = (currentIndex >= 3 && currentIndex - 3 < entries.count)
                ? entries[currentIndex - 3].id : nil

            entries = newEntries
            evictAllEntryVCs()  // index→日记 映射已变，作废全部日记页缓存

            if currentIndex >= 3 {
                if let id = currentEntryID,
                   let newIdx = newEntries.firstIndex(where: { $0.id == id }) {
                    let target = newIdx + 3
                    pvc.setViewControllers([vc(for: target)], direction: .forward, animated: false)
                    currentIndex = target
                } else {
                    navigate(to: 2, animated: true)
                }
            }
        }

        // MARK: 程序化翻页（支持多页连翻）

        func navigate(to target: Int, animated: Bool = true) {
            guard let pvc,
                  target >= 0, target < pageCount,
                  target != currentIndex else { return }

            let direction: UIPageViewController.NavigationDirection = target > currentIndex ? .forward : .reverse
            let distance = abs(target - currentIndex)

            guard animated, distance > 1 else {
                // 单页翻 / 无动画：直接跳
                pvc.setViewControllers([vc(for: target)], direction: direction, animated: animated) { [weak self] _ in
                    self?.currentIndex = target
                }
                if animated { playPageSound() }
                return
            }

            // 翻页序列：
            //  · 近距离（≤4）逐页连翻，模拟翻书；
            //  · 远距离（>4）只演示「前两页 + 后两页」，中间一大段直接跳过。
            //    否则跳到第 N 页会顺序连翻 N 次，动画长达数十秒。
            let step = direction == .forward ? 1 : -1
            let indices: [Int]
            if distance > 4 {
                indices = [currentIndex + step, currentIndex + 2 * step,
                           target - step, target]
            } else {
                indices = Array(stride(from: currentIndex + step, through: target, by: step))
            }

            flip(indices, direction: direction)
        }

        /// 快速连翻：短间隔依次触发，后一翻盖掉仍在进行的 pageCurl —— 这正是「哗哗」快速翻书的手感。
        /// （等每页动画完整跑完再翻下一页会变成慢吞吞的一页一页，用户不可接受。）
        /// 最后一翻无后继、不会被打断，因此一定稳稳落在目标页。
        private func flip(_ indices: [Int], direction: UIPageViewController.NavigationDirection) {
            guard pvc != nil, !indices.isEmpty else { return }
            let interval = 0.09
            for (i, index) in indices.enumerated() {
                let isLast = i == indices.count - 1
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) { [weak self] in
                    guard let self, let pvc = self.pvc else { return }
                    self.playPageSound()
                    pvc.setViewControllers([self.vc(for: index)], direction: direction, animated: true) { [weak self] _ in
                        // 只在最后一翻锁定 currentIndex；中间页可能被下一翻打断，记了也会被覆盖
                        if isLast { self?.currentIndex = index }
                    }
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
            guard let idx = indexByVC[ObjectIdentifier(vc)], idx > 0 else { return nil }
            return self.vc(for: idx - 1)
        }
    }

    nonisolated func pageViewController(_ pvc: UIPageViewController,
                                        viewControllerAfter vc: UIViewController) -> UIViewController? {
        MainActor.assumeIsolated {
            guard let idx = indexByVC[ObjectIdentifier(vc)],
                  idx + 1 < pageCount else { return nil }
            return self.vc(for: idx + 1)
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
               let idx = indexByVC[ObjectIdentifier(vc)] {
                currentIndex = idx
            }
        }
    }
}
