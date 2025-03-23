import SwiftUI
import SwiftData
import AVFoundation


struct DiaryView: View {
    @State private var selectedDate = Date() // 当前的日期
    @State private var backToList:Bool = false
    @Query(sort:\DiaryEntry.date, order: .reverse) private var diaryEntries: [DiaryEntry]

    var body: some View {
        VStack {
            // 将空白页添加到 diaryEntries 的前面
            let diaryPages: [DiaryPage] = diaryEntries.map {
                DiaryPage(id: $0.id, date: $0.date, content: $0.content ?? "", backToList: $backToList)
            }

            // Diary Pages
            DiaryPageViewController(pages: diaryPages, backToList: $backToList)
                .ignoresSafeArea() // 全屏显示
        }
    }
}

struct DiaryPage: View {
    let id:UUID
    let date: Date
    @State private var content: String
    var onBackToIndex: (() -> Void)?  // 触发目录跳转的回调
    @Binding var backToList: Bool
    
    let isNew:Bool
    @FocusState private var isContentFocused: Bool
    @Environment(\.modelContext) private var modelContext
//    @Query private var diaryEntries: [DiaryEntry]
    @Query(sort:\DiaryEntry.date, order: .reverse) private var diaryEntries: [DiaryEntry]

    init(id: UUID,date: Date, content: String = "", isNew:Bool = false,backToList:Binding<Bool>) {
        self.id = id
        self.date = date
        self._content = State(initialValue: content)
        self.isNew = isNew
        self._backToList = backToList // 绑定 backToList

    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 回到列表
            HStack {
                Button("回到目录") {
                    backToList = true // 触发跳转
                    onBackToIndex?()  // 点击时触发闭包

                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.trailing)
                
                Spacer()

                // 完成按钮
                if isContentFocused {
                    HStack {
                        Button("完成") {
                            if isNew{
                                if content.isEmpty == false {
                                    // 插入新的 DiaryEntry 数据
                                    let newEntry = DiaryEntry(id: UUID(),content: content, date: Date())
                                    modelContext.insert(newEntry)
                                }
                            }else{
                                if let entry : DiaryEntry = fetchDiaryEntry(byID: id){
                                    entry.content = content
                                }
                                
                            }
                            // 取消焦点以隐藏键盘
                            isContentFocused = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.trailing)
                    }
                }
            }
            
            
            
            // 日期显示
            Text(date, style: .date)
                .font(.headline)
                .padding(.top)

            // 日记内容编辑器
            TextEditor(text: $content)
                .focused($isContentFocused)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .onAppear {
                    // 如果内容为空，则自动聚焦以弹出键盘
                    if content.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isContentFocused = true
                        }
                    }
                }

            Spacer()

            
        }
        .padding()
        .onTapGesture {
            // 点击视图其他区域时收起键盘
            isContentFocused = false
        }
    }
    
    func fetchDiaryEntry(byID id: UUID) -> DiaryEntry? {
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first  // 返回唯一结果[1](@ref)
    }
}

struct DiaryPageViewController: UIViewControllerRepresentable {
    var pages: [DiaryPage] // ✅ 匹配传入的数组类型
    @Binding var backToList:Bool
    @EnvironmentObject var globalData: GlobalData

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, globalData: globalData) // 🚀 关键注入点
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .pageCurl, // 翻书效果
            navigationOrientation: .horizontal,
            options: nil
        )

        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        // 移除用于翻页的单击手势，但保留其他点击手势
        for recognizer in pageViewController.gestureRecognizers {
            if let tapGesture = recognizer as? UITapGestureRecognizer, tapGesture.numberOfTapsRequired == 1 {
                pageViewController.view.removeGestureRecognizer(tapGesture)
            }
        }
        
        // 设置初始页为中间页（今天）
        if let firstVC = context.coordinator.controllers.first
        {
            pageViewController.setViewControllers([firstVC], direction: .forward, animated: true)
        }

        return pageViewController
    }

    // 确保 SwiftUI 在 pages 变化时更新 ViewController
    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        
        //响应返回列表按钮
        if backToList {
            if context.coordinator.currentIndex == 0
            {
                context.coordinator.moveToList()
            }
            else
            {
                context.coordinator.animateMoveToPage(pageViewController: pageViewController,targetIndex: 0) {
                    context.coordinator.moveToList()
                }
            }
            
            DispatchQueue.main.async
            {
                backToList = false
            }
        }
        
        //打开详情页
        if globalData.targetPageIndex >= 0 {
            context.coordinator.animateMoveToPage(
                pageViewController: pageViewController,
                targetIndex: globalData.targetPageIndex
            )
            DispatchQueue.main.async {
                globalData.targetPageIndex = -1 // 重置状态避免重复触发
            }
        }
        
        // 同步数据库的增删改除
        if context.coordinator.parent.pages.count != pages.count {
            // 更新 Coordinator 的数据
            context.coordinator.parent.pages = pages
            context.coordinator.controllers = pages.map { UIHostingController(rootView: $0) }
            
            // 强制刷新 UIPageViewController 的当前页
            if let currentVC = pageViewController.viewControllers?.first,
               let currentIndex = context.coordinator.controllers.firstIndex(of: currentVC) {
                // 处理已被删除的情况，例如回到第一页
                let newIndex = min(currentIndex, context.coordinator.controllers.count - 1)
                pageViewController.setViewControllers(
                    [context.coordinator.controllers[newIndex]],
                    direction: .forward,
                    animated: false
                )
            } else {
                // 默认显示第一页
                pageViewController.setViewControllers(
                    [context.coordinator.controllers[0]],
                    direction: .forward,
                    animated: false
                )
            }
        }
    }


    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: DiaryPageViewController
        var currentIndex: Int = 0
        var globalData: GlobalData // ✅ 通过属性持有

        private var pageSoundPlayer: AVAudioPlayer?

        lazy var controllers: [UIViewController] = {
                parent.pages.map { page in
                    UIHostingController(rootView: page)
                }
            }()
        
            
            // ✅ 正确初始化器
        init(parent: DiaryPageViewController, globalData: GlobalData) {
            self.parent = parent
            self.globalData = globalData
            
            // 初始化音频播放器
            if let soundURL = Bundle.main.url(forResource: "page_flip", withExtension: "mp3") {
                pageSoundPlayer = try? AVAudioPlayer(contentsOf: soundURL)
                pageSoundPlayer?.prepareToPlay()
            }
        }
        
        func animateMoveToPage(pageViewController: UIPageViewController,targetIndex:Int,completion: (() -> Void)? = nil)
        {
            let currentIndex = self.currentIndex
            guard currentIndex != targetIndex else { return }
            
            let step = currentIndex > targetIndex ? -1 : 1
            let direction: UIPageViewController.NavigationDirection = (step > 0) ? .forward : .reverse

            for index in stride(from: currentIndex, through: targetIndex, by: step)
            {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(abs(currentIndex - index)) * 0.05)
                {
                    self.playPageSound()
                    let vc = self.controllers[index]
                    pageViewController.setViewControllers([vc], direction:direction, animated: true) { Bool in
                        self.currentIndex = index
                        if direction == .reverse, index == targetIndex{
                            completion?()
                        }
                    }
                }
            }
        }
        
        func moveToList() {
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.globalData.listRotationAngle = 0
                    }
                }
        }
        
        // 音频播放方法
            private func playPageSound() {
                guard let player = pageSoundPlayer else { return }
                if player.isPlaying {
                    player.currentTime = 0  // 重置播放进度实现即时重播
                }
                player.play()
            }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let currentIndex = controllers.firstIndex(of: viewController) else { return nil }
            
            //第一页往前翻是目录
            let previousIndex = currentIndex - 1
            if previousIndex < 0 {
                withAnimation(.easeIn(duration: 1)) {
                    parent.globalData.listRotationAngle = 0
                }
                    return nil
            }
            
            playPageSound()

            return currentIndex == 0 ? nil : controllers[currentIndex - 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let currentIndex = controllers.firstIndex(of: viewController) else {
                    return nil
                }
                let nextIndex = currentIndex + 1
                guard nextIndex < controllers.count else {
                    return nil
                }
            playPageSound()

                return controllers[nextIndex]
        }

        // 当翻页动画完成时，更新 currentPage
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool) {
            
            if completed,
                let visibleViewController = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleViewController)
            {
                currentIndex = index
            }
        }

    }
}

#Preview {
    ContentView()
}
