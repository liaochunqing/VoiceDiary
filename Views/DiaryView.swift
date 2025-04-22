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

//    var pages: [IdentifiedHostingController<AnyView>]

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
        
        // 设置初始页为主列表页
        let firstVC = context.coordinator.controllers[2]
        pageViewController.setViewControllers([firstVC], direction: .forward, animated: true)
        context.coordinator.currentIndex = 2
        return pageViewController
    }


    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        // 检查页面数量是否发生变化
        if globalData.pageUpdate {
//            context.coordinator.lastPageUpdateTrigger = globalData.pageUpdateTrigger

            // 重新加载页面内容
            context.coordinator.controllers = globalData.diaryPages.map { $0 }
            
            // 获取当前显示的视图控制器
            if let currentVC = pageViewController.viewControllers?.first,
               let currentIndex = context.coordinator.controllers.firstIndex(of: currentVC) {
                // 更新当前索引
                context.coordinator.currentIndex = currentIndex
            } else {
                // 如果无法确定当前视图控制器，默认显示主列表页
                let mainListVC = context.coordinator.controllers[2]
                pageViewController.setViewControllers([mainListVC], direction: .forward, animated: false)
                context.coordinator.currentIndex = 2
            }
            
            DispatchQueue.main.async {
                globalData.pageUpdate = false
            }
        }
        
        //响应返回列表按钮
        if globalData.backToList {
            context.coordinator.animateMoveToPage(pageViewController: pageViewController,targetIndex: 2) {}
            DispatchQueue.main.async {
                globalData.backToList = false
            }
        }
        
        //打开详情页
        if globalData.moveToPage {
            context.coordinator.animateMoveToPage(pageViewController: pageViewController,targetIndex: globalData.currentIndex)
            DispatchQueue.main.async {
                globalData.moveToPage = false // 重置状态避免重复触发
            }
        }
    }


    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: DiaryPageViewController
        var currentIndex: Int = 0
        var globalData: GlobalData //
//        var lastPageUpdateTrigger: Int

        private var pageSoundPlayer: AVAudioPlayer?

         var controllers: [UIViewController]
        
            
            // 正确初始化器
        init(parent: DiaryPageViewController, globalData: GlobalData) {
            self.parent = parent
            self.globalData = globalData
//            self.lastPageUpdateTrigger = globalData.pageUpdateTrigger
            self.controllers = globalData.diaryPages.map { $0 }

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
            let fromIndex = currentIndex > targetIndex ? currentIndex-1 : currentIndex+1

            for index in stride(from: fromIndex, through: targetIndex, by: step)
            {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(abs(fromIndex - index)) * 0.05)
                {
                    self.playPageSound()
                    let vc = self.controllers[index]
                    pageViewController.setViewControllers([vc], direction:direction, animated: true) { Bool in
                        self.currentIndex = index
                    }
                }
            }
        }
        
        
        // 音频播放方法
        private func playPageSound() {
//            guard let player = pageSoundPlayer else { return }
//            if player.isPlaying {
//                player.currentTime = 0  // 重置播放进度实现即时重播
//            }
//            player.play()
        }
        
        func pageViewController(_ pageViewController: UIPageViewController,viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index > 0 else { return nil }

            playPageSound()

            return controllers[index - 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController,viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index < controllers.count - 1 else { return nil }
            
            playPageSound()

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
            
            VStack() {
                // 顶部摁钮
                HStack {
                    Button(action: {
                        globalData.backToList = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: W_SCALE(40), height: W_SCALE(40))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showDeleteConfirmation = true

                    }) {
                        if entry?.content != defaultContent {
                            
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: W_SCALE(40), height: W_SCALE(40))
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
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
                                        globalData.moveToPage = true

                                    } else {
                                        globalData.backToList = true
                                    }
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
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                                Image(systemName: "highlighter")
                                    .foregroundColor(.black)
                            }
                        }
                    }                }
                .padding(.horizontal)
                
                // 信息区
                if let entry = entry {
                    ScrollView {
                        Text(entry.content ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(UIColor.white))
                    .cornerRadius(W_SCALE(20))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 2, y: 2) // 添加阴影
                    .padding()
                    
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                        
                        Text(formatDate(entry.date))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("\(entry.emojiString)")
                            .font(.body)
                        Spacer()
                    }
                    .padding([.leading])
                    
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "character")
                            .foregroundColor(.gray)
                        Text("字数 \(entry.content?.count ?? 0)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.gray)
                        Text(entry.location ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                Spacer()
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


#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(
                    // ✅ 创建专用于预览的内存存储容器
                    try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
