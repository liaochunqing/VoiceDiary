import SwiftUI
import SwiftData
import AVFoundation


struct DiaryView: View {
    @EnvironmentObject var globalData: GlobalData
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    var body: some View {
        VStack {
            if !globalData.diaryPages.isEmpty {
                DiaryPageViewController()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if globalData.diaryPages.isEmpty {
                globalData.initializePages(with: entries)
            }
        }
    }
}

struct DiaryPageViewController: UIViewControllerRepresentable {
    @EnvironmentObject var globalData: GlobalData

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, globalData: globalData) //
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
        
        // 设置手势识别器的代理，限制仅响应水平方向滑动
        for recognizer in pageViewController.gestureRecognizers {
            if let panGesture = recognizer as? UIPanGestureRecognizer {
                panGesture.delegate = context.coordinator
            }
        }
        
        // 设置初始页为主列表页
        let firstVC = context.coordinator.controllers[2]
        pageViewController.setViewControllers([firstVC], direction: .forward, animated: true)
        context.coordinator.currentIndex = 2
        
        //音效加载
        context.coordinator.loadSound()
        return pageViewController
    }


    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        // 检查页面数量是否发生变化
        if globalData.pageUpdate {
            // 重新加载页面内容
            context.coordinator.controllers = globalData.diaryPages.map { $0 }
            
            DispatchQueue.main.async {
                globalData.pageUpdate = false
            }
        }
        
        //响应返回列表按钮
        if globalData.backToList {
            context.coordinator.animateMoveToPage(pageViewController: pageViewController,targetIndex: 2,animated: true)
            DispatchQueue.main.async {
                globalData.backToList = false
            }
        }
        
        //无动画跳转到指定页
        if globalData.moveToPageNoAnimate {
            context.coordinator.moveToPage(pageViewController: pageViewController,targetIndex: globalData.currentIndex)
            DispatchQueue.main.async {
                globalData.moveToPageNoAnimate = false // 重置状态避免重复触发
            }
        }
        
        //动画跳转到指定页
        if globalData.moveToPage {
            context.coordinator.animateMoveToPage(pageViewController: pageViewController,targetIndex: globalData.currentIndex,animated: true)
            DispatchQueue.main.async {
                globalData.moveToPage = false // 重置状态避免重复触发
            }
        }
    }


    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: DiaryPageViewController
        var controllers: [UIViewController]

        var currentIndex: Int = 0
        var globalData: GlobalData

        var audioPlayer: AVAudioPlayer?
        var activePlayers: [AVAudioPlayer] = []
            
        init(parent: DiaryPageViewController, globalData: GlobalData) {
            self.parent = parent
            self.globalData = globalData
            self.controllers = globalData.diaryPages.map { $0 }
        }
        
        func animateMoveToPage(pageViewController: UIPageViewController,targetIndex:Int,animated:Bool)
        {
            let currentIndex = self.currentIndex
            guard currentIndex != targetIndex else { return }
            
            let step = currentIndex > targetIndex ? -1 : 1
            let direction: UIPageViewController.NavigationDirection = (step > 0) ? .forward : .reverse
            let fromIndex = currentIndex + (step > 0 ? 1 : -1) // 设置起始索引

            if animated == false{
                let vc = self.controllers[targetIndex]
                pageViewController.setViewControllers([vc], direction:direction, animated: false){ Bool in
                    self.currentIndex = targetIndex
               }
            }else{
                for index in stride(from: fromIndex, through: targetIndex, by: step)
                {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(abs(fromIndex - index)) * 0.07)
                    {
                        let vc = self.controllers[index]
                        pageViewController.setViewControllers([vc], direction:direction, animated: true) { Bool in
                            self.currentIndex = index
                        }
                        
                        self.playOverlappingPageSound()
                    }
                }
            }
        }
        
        func moveToPage(pageViewController: UIPageViewController,targetIndex:Int){
            let vc = self.controllers[targetIndex]
            pageViewController.setViewControllers([vc], direction:.forward, animated: false){ Bool in
                self.currentIndex = targetIndex
           }
        }

        
        func loadSound() {
            if let soundURL = Bundle.main.url(forResource: audio_pageFlip, withExtension: "m4a") {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    audioPlayer?.prepareToPlay()
                } catch {
                    print("无法加载音效文件: \(error)")
                }
            }
        }
        
        // 单独音频播放方法
        private func playPageSound() {
            
            let isSoundEnabled = UserDefaults.standard.bool(forKey: "isSoundEnabled")
            guard isSoundEnabled else { return }
            
            guard let player = audioPlayer else { return }
            if player.isPlaying {
                player.stop()
                player.currentTime = 0  // 重置播放进度实现即时重播
            }
            player.play()
        }
        
        // 重叠音频播放方法
        private func playOverlappingPageSound() {
            
            let isSoundEnabled = UserDefaults.standard.bool(forKey: "isSoundEnabled")
            guard isSoundEnabled else { return }
            
            guard let soundURL = Bundle.main.url(forResource: audio_pageFlip, withExtension: "m4a") else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                player.play()
                // 保持对播放器的引用，防止被释放
                self.activePlayers.append(player)
                // 设置一个定时器，在音效播放完成后移除引用
                Timer.scheduledTimer(withTimeInterval: player.duration, repeats: false) { _ in
                    if let index = self.activePlayers.firstIndex(of: player) {
                        self.activePlayers.remove(at: index)
                    }
                }
            } catch {
                print("无法播放音效: \(error)")
            }
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            playPageSound()
        }

        // 返回前一个视图控制器
        func pageViewController(_ pageViewController: UIPageViewController,viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index > 0 else { return nil }

            return controllers[index - 1]
        }

        // 返回下一个视图控制器
        func pageViewController(_ pageViewController: UIPageViewController,viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index < controllers.count - 1 else { return nil }

            return controllers[index + 1]
        }

        // 当翻页动画完成时，更新 currentPage
        func pageViewController(_ pageViewController: UIPageViewController,didFinishAnimating finished: Bool,previousViewControllers: [UIViewController],transitionCompleted completed: Bool) {
           
            if completed,
               let visibleViewController = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleViewController){
                currentIndex = index
                DispatchQueue.main.async {
                    self.globalData.currentIndex = index
                    self.globalData.hideAddButton = index < 2 ? true : false

                }
            }
        }
    }
}

// 在 Coordinator 类中实现 UIGestureRecognizerDelegate 协议
extension DiaryPageViewController.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: panGesture.view)
            // 仅当水平方向的速度大于垂直方向时，才允许手势开始
            return abs(velocity.x) > abs(velocity.y)
        }
        return true
    }
}

struct DiaryPage: View {
    let infoRowSpacing: CGFloat = W_SCALE(10)
    let id:UUID
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort:\DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @EnvironmentObject var globalData: GlobalData
    @State private var showEditDiaryView = false
    @State private var entry: DiaryEntry?
    @State private var showDeleteConfirmation = false
    
    init(id: UUID) {
        self.id = id
    }
    
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
                    .ignoresSafeArea() // 使背景颜色扩展到安全区域之外
            
            VStack(spacing: infoRowSpacing) {
                // 顶部摁钮
                HStack {
                    Button(action: {
                        globalData.backToList = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: W_SCALE(40), height: W_SCALE(40))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.black)
                        }
                    }
                    Spacer()

                    // ✨ 中间标题
                    if let index = entries.firstIndex(where: { $0.id == self.id }) {
                        let pageNumber = index + 1
                        Text("第 \(pageNumber) 页")
                            .font(.system(size: W_SCALE(18), weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    
                    Button(action: {showDeleteConfirmation = true}) {
//                        if entry?.content != defaultContent {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: W_SCALE(40), height: W_SCALE(40))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 1, y: 1)
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
//                        }
                    }
                    .padding(.horizontal)
                    .alert("确定删除这篇日记吗？", isPresented: $showDeleteConfirmation) {
                        Button("删除", role: .destructive) {
                            if let entry = entry {
                                let deleteEntryIndex = entries.firstIndex(where: { $0.id == entry.id })

                                DataManager.delete(entry, from: modelContext)
                                try? modelContext.save()
                        
                                var newCenterIndex: Int? = nil
                                if let deleteEntryIndex = deleteEntryIndex, deleteEntryIndex < entries.count {
                                    // 如果存在下一个条目，选择它
                                    newCenterIndex = deleteEntryIndex
                                } else if let deleteEntryIndex = deleteEntryIndex, deleteEntryIndex - 1 >= 0 {
                                    // 否则选择上一个条目
                                    newCenterIndex = deleteEntryIndex - 1
                                }
                                        
                                if let newCenterIndex = newCenterIndex, newCenterIndex < entries.count {
                                    let currentEntry = entries[newCenterIndex]
                                    let index = globalData.updatePageBy(entry: currentEntry, entries: entries)
                                    globalData.pageUpdate = true
                                    globalData.currentIndex = index
                                    globalData.moveToPageNoAnimate = true
                                } else {
                                    globalData.currentIndex = 2//回到列表页
                                    globalData.moveToPageNoAnimate = true                                }
                                }
                        }
                        Button("取消", role: .cancel) {}
                    }
                    
                    Button(action: {
                        showEditDiaryView = true
                    }) {
                        if entry?.content != defaultContent {
                            
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: W_SCALE(40), height: W_SCALE(40))
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                                Image(systemName: "highlighter")
                                    .foregroundColor(.black)
                            }
                        }
                    }                }
                .padding(.horizontal)
                
                
                // 信息区
                if let entry = entry {
                    
                    ReadOnlyTextView(
                        text: entry.content ?? "",
                        font: UIFont(name: entry.fontStyle, size: entry.fontSize) ?? UIFont.systemFont(ofSize: entry.fontSize),
                        foregroundColor: UIColor(entry.fontColor)  // 将 SwiftUI 的 Color 转换为 UIColor
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .background(Color(.secondarySystemFill))
                    .background(
                        Color(.secondarySystemFill)
                            .blur(radius: 1, opaque: false)
                    )
                    .cornerRadius(W_SCALE(20))
//                    .shadow(color: Color(.white), radius: 1, x: -1, y: -1)
                    .padding()

                
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "clock")
                        
                        Text(formatDate(entry.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(entry.emojiString)")
                            .font(.body)
                        
                        Spacer()
                    }
                    .padding(.horizontal)

                    
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "character.cursor.ibeam")
//                            .foregroundColor(.gray)
                        Text("字数 \(entry.content?.count ?? 0)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(entry.location ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                }
            }
        }
        .onAppear {
                    entry = DataManager.fetchByID(id, in: modelContext)
        }
    
        .fullScreenCover(isPresented: $showEditDiaryView) {
            AddDiaryView(existingEntry: entry, isPresented: $showEditDiaryView)
        }
    }
}


struct ReadOnlyTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let foregroundColor: UIColor  // 新增属性

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.font = font
        textView.text = text
        textView.textColor = foregroundColor  // 设置文本颜色
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.font = font
        uiView.textColor = foregroundColor  // 更新文本颜色
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(

            try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
