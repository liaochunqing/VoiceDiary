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
    func goToList(animated: Bool = true)     { coordinator?.navigate(to: 2, animated: animated) }
    func goToSettings()                      { coordinator?.navigate(to: 1) }
    func goToEntry(at entryIndex: Int)       { coordinator?.navigate(to: entryIndex + 3) }
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

        // 让 pageCurl 的拖拽手势可被方向/边界裁决拒绝，防止首/末页越界崩溃。
        context.coordinator.pageSwipeRecognizers =
            pvc.gestureRecognizers.filter { !($0 is UITapGestureRecognizer) }
        for r in context.coordinator.pageSwipeRecognizers {
            r.delegate = context.coordinator
            r.addTarget(context.coordinator, action: #selector(Coordinator.pageSwipeStateChanged(_:)))
        }

        context.coordinator.pvc = pvc
        let startVC = context.coordinator.vc(for: 2)  // 列表页

        // 异步预热设置页：等 pvc 回到 SwiftUI、进入 window 层级并获得正确 bounds 后，
        // 再瞬间切到设置页并切回目录。此时设置页的 SwiftUI body 会在有效布局上下文中求值、
        // 完整走完布局 → 渲染，之后用户第一次翻到设置页直接命中已就绪缓存，不会卡顿。
        // 两个 setViewControllers 都是 animated:false，用户完全看不到这个瞬间切换。
        DispatchQueue.main.async { [weak pvc, weak coordinator = context.coordinator] in
            guard let pvc, let coordinator else { return }
            let primeVC = coordinator.vc(for: 1)
            pvc.setViewControllers([primeVC], direction: .forward, animated: false)
            pvc.setViewControllers([startVC], direction: .reverse, animated: false)
            coordinator.currentIndex = 2
        }

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
        /// pageCurl 的拖拽手势（非单击）。我们当它们的 delegate，按落点决定是否放行翻页。
        var pageSwipeRecognizers: [UIGestureRecognizer] = []
        /// 翻页手势进行中时被临时禁滚的 ScrollView；手势结束后恢复。
        private var suspendedScrollViews: Set<UIScrollView> = []

        private let themeManager: ThemeManager
        private let navigator: BookNavigator
        private let container: ModelContainer
        private var entries: [DiaryEntry]

        private var audioPlayer: AVAudioPlayer?

        // pageCurl 结算到首/末页那一刻，会成对探测两侧邻页；若被探测的一侧返回 nil，UIKit 偶发以
        // 0 个 VC 提交内部转场而崩溃（NSInvalidArgumentException: number of view controllers
        // provided (0)…，正是「翻到末页/往回翻必崩」的根因）。对策：dataSource 在真实首/末页一律不返回
        // nil，而是顶一张可回退的占位空白页，从根上消灭 0 个 VC 的转场；真正的边界改由翻页手势的
        // shouldBegin 守卫拦住（末页禁前翻、首页禁后翻）。占位页只有外侧返回 nil，而外侧用户够不到。
        private lazy var headPlaceholder = makeBlankPage()  // 顶在第一页之前
        private lazy var tailPlaceholder = makeBlankPage()  // 顶在最后一页之后

        private func makeBlankPage() -> UIViewController {
            let vc = UIViewController()
            vc.view.backgroundColor = UIColor(themeManager.palette.paper)
            return vc
        }

        // 懒加载页缓存：index → VC，以及反向 VC → index（dataSource 据此找邻页）。
        // 不再常驻全部日记页：内存与日记数量解耦，最多常驻 cacheCapacity 个日记页 + 3 个固定页。
        private var vcCache: [Int: UIViewController] = [:]
        private var indexByVC: [ObjectIdentifier: Int] = [:]
        /// 日记页常驻上限（封面/设置/目录三页固定常驻、不计入此数）。
        private let cacheCapacity = 7

        // 页面结构：0=封面, 1=设置, 2=目录, 3..N=日记（日记 i 在 index i+3）
        private var pageCount: Int { 3 + entries.count }

        /// 固定页索引集合：封面(0)、设置(1)、目录(2)——无论如何不可被淘汰/删除。
        private let fixedPageIndices: Set<Int> = [0, 1, 2]

        init(entries: [DiaryEntry], themeManager: ThemeManager,
             navigator: BookNavigator, container: ModelContainer) {
            self.themeManager = themeManager
            self.navigator    = navigator
            self.container    = container
            self.entries      = entries
            super.init()
            // 预缓存固定页：封面(0)、设置(1)、目录(2) 在构造阶段直接建好并登记，
            // 后续 vc(for:) 命中缓存直接返回，不会触发「缓存缺失」误报警告。
            for idx in fixedPageIndices {
                let vc = makeContentVC(for: idx)
                vcCache[idx] = vc
                indexByVC[ObjectIdentifier(vc)] = idx
            }
        }

        // MARK: 页面懒加载 + 缓存

        /// 取指定 index 的页面 VC：命中缓存直接返回，否则即时构建并缓存，随后按需淘汰远处页。
        /// 固定页（0/1/2）绝不淘汰；若因任何意外从缓存消失，无条件重建并告警。
        func vc(for index: Int) -> UIViewController {
            if let cached = vcCache[index] {
                return cached
            }
            // 固定页正常应在初始化时就缓存；若之后仍走到这里，说明某处逻辑越过了保护。
            // 兜底重建确保不崩，同时打 log 便于追踪根因。
            #if DEBUG
            if fixedPageIndices.contains(index) {
                print("⚠️ [BookPageView] 固定页 index=\(index) 缓存缺失，触发兜底重建")
            }
            #endif
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
            // entries 为新→旧；index-3 即在数组中的位置，+1 得篇号（第 1 篇 = 最新）。
            default: return makeVC(DiaryDetailView(entry: entries[index - 3], page: (index - 3) + 1))
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
        /// 固定页（0/1/2）受硬保护：无论在不在 displayed/justInserted 集合里都不可淘汰。
        /// 绝不淘汰：① 固定页 0/1/2（硬保护）；② 正在显示的页（pvc 仍强引用它，丢映射会让滑动找不到邻页）；
        /// ③ 本次刚插入的页（远距跳转时目标页离旧 currentIndex 很远，否则会被误删）。
        private func evictIfNeeded(justInserted: Int) {
            let entryIdxs = vcCache.keys.filter { !fixedPageIndices.contains($0) }
            guard entryIdxs.count > cacheCapacity else { return }
            let displayed = Set((pvc?.viewControllers ?? []).compactMap { indexByVC[ObjectIdentifier($0)] })
            let protected = displayed.union([justInserted]).union(fixedPageIndices)
            let evictable = entryIdxs
                .filter { !protected.contains($0) }
                .sorted { abs($0 - currentIndex) > abs($1 - currentIndex) }
            for idx in evictable.prefix(entryIdxs.count - cacheCapacity) {
                guard !fixedPageIndices.contains(idx) else { continue }
                if let vc = vcCache.removeValue(forKey: idx) {
                    indexByVC.removeValue(forKey: ObjectIdentifier(vc))
                }
            }
        }

        // MARK: 翻页时冻结 ScrollView，防止手势冲突导致「边翻页边滚动」

        /// 递归遍历视图树，禁用所有 UIScrollView 的滚动，并记入 suspendedScrollViews。
        private func suspendScrolling(in view: UIView) {
            if let sv = view as? UIScrollView, sv.isScrollEnabled {
                sv.isScrollEnabled = false
                suspendedScrollViews.insert(sv)
            }
            for sub in view.subviews {
                suspendScrolling(in: sub)
            }
        }

        /// 恢复所有被 suspendScrolling 禁用的 ScrollView 滚动。
        private func resumeScrolling() {
            for sv in suspendedScrollViews {
                sv.isScrollEnabled = true
            }
            suspendedScrollViews.removeAll()
        }

        /// pageCurl 拖拽手势状态变化回调：结束时恢复 ScrollView 滚动。
        @objc fileprivate func pageSwipeStateChanged(_ gesture: UIGestureRecognizer) {
            switch gesture.state {
            case .ended, .cancelled, .failed:
                resumeScrolling()
            default:
                break
            }
        }

        /// 日记数据变动后，作废所有日记页缓存（index→日记 的映射已变），固定页保留。
        /// 固定页（0/1/2）受硬保护，永不清除。
        private func evictAllEntryVCs() {
            for idx in vcCache.keys where !fixedPageIndices.contains(idx) {
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

            // 关键：不论当前停在日记页还是固定页（封面/设置/目录），都必须重置 pvc 当前显示的 VC。
            // UIPageViewController 会强引用「当前页的预取邻页」以备翻书动画；evictAllEntryVCs 只清了
            // 我们自己的 indexByVC，pvc 仍攥着删除前预取的那个日记页 VC。若不重置：翻向它会显示已删
            // 条目，且它在 indexByVC 里已无映射 → 前/后邻页都解析为 nil → 再翻一下 pageCurl 便以 0 个
            // VC 提交转场，抛 NSInvalidArgumentException 崩溃（正是「删几篇日记后翻到末页再往回翻必崩」的根因）。
            let target: Int
            if currentIndex >= 3, let id = currentEntryID,
               let newIdx = newEntries.firstIndex(where: { $0.id == id }) {
                target = newIdx + 3      // 当前所看日记仍在：跟随到它的新位置
            } else if currentIndex >= 3 {
                target = 2               // 当前所看日记被删：回目录（避免用过期 currentIndex 走 navigate
                                         // 的多页连翻，否则 vc(for:) 会按旧 index 取到越界 entries 下标）
            } else {
                target = currentIndex    // 停在固定页：原地重置，仅为强制刷新 pvc 的预取邻页缓冲
            }
            pvc.setViewControllers([vc(for: target)], direction: .forward, animated: false)
            currentIndex = target
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
            if vc === tailPlaceholder { return self.vc(for: max(0, pageCount - 1)) }  // 末页占位 → 退回真实末页
            if vc === headPlaceholder { return headPlaceholder }                        // 首页占位自指，防止 pageCurl 以 0-VC 崩溃
            guard let idx = indexByVC[ObjectIdentifier(vc)], idx > 0 else {
                return headPlaceholder   // 真实第一页：顶占位而非 nil，避开 0 个 VC 转场崩溃
            }
            return self.vc(for: idx - 1)
        }
    }

    nonisolated func pageViewController(_ pvc: UIPageViewController,
                                        viewControllerAfter vc: UIViewController) -> UIViewController? {
        MainActor.assumeIsolated {
            if vc === headPlaceholder { return self.vc(for: 0) }   // 首页占位 → 前进到真实首页
            if vc === tailPlaceholder { return tailPlaceholder }     // 末页占位自指，防止 pageCurl 以 0-VC 崩溃
            guard let idx = indexByVC[ObjectIdentifier(vc)],
                  idx + 1 < pageCount else {
                return tailPlaceholder   // 真实最后一页：顶占位而非 nil，避开 0 个 VC 转场崩溃
            }
            return self.vc(for: idx + 1)
        }
    }
}

// MARK: - 翻页手势的方向与边界裁决（防止首/末页越界崩溃）

extension BookPageView.Coordinator: UIGestureRecognizerDelegate {
    /// 翻页手势全时接收触摸；方向/边界裁决在 shouldBegin 里做。
    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                       shouldReceive touch: UITouch) -> Bool { true }

    /// 竖向滑动不触发翻页；首/末页朝无邻页方向拖动时拦截，防止 pageCurl 以 0-VC 崩溃。
    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated {
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let v = pan.velocity(in: pan.view)
                if abs(v.y) > abs(v.x) { return false }
                if v.x < 0, currentIndex >= pageCount - 1 { return false }
                if v.x > 0, currentIndex <= 0 { return false }
                // 水平翻页即将开始 → 冻结所有 ScrollView，防止手势同时驱动滚动
                if let pvc { suspendScrolling(in: pvc.view) }
            }
            return true
        }
    }

    /// 与其它手势并存，避免干扰 pageCurl 自身的内部手势协作。
    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                       shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
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
            guard let vc = pvc.viewControllers?.first else { return }
            // 占位页不该停留；手势守卫偶尔失效时补救：无动画跳回真实边界页。
            if vc === tailPlaceholder {
                self.pvc?.setViewControllers([self.vc(for: self.pageCount - 1)],
                                              direction: .reverse, animated: false)
                self.currentIndex = self.pageCount - 1
                return
            }
            if vc === headPlaceholder {
                self.pvc?.setViewControllers([self.vc(for: 0)],
                                              direction: .forward, animated: false)
                self.currentIndex = 0
                return
            }
            if let idx = indexByVC[ObjectIdentifier(vc)] {
                currentIndex = idx
            }
        }
    }
}
