import SwiftUI

struct DiaryView: View {
    @State private var currentIndex = 1 // 中间页为今天，0为昨天，2为明天
    @State private var selectedDate = Date() // 当前的日期

    var body: some View {
        VStack {
            // Diary Pages
            DiaryPageViewController(pages: getDiaryEntries(), currentIndex: $currentIndex)
                .ignoresSafeArea() // 全屏显示
//                .onChange(of: currentIndex) { oldValue, newValue in
//                    updateSelectedDate(for: newValue)
//                }
        }
    }

    // 获取当前的日记数据（昨天、今天、明天）
    func getDiaryEntries() -> [DiaryPage] {
        return [
            DiaryPage(date: Calendar.current.date(byAdding: .day, value: +1, to: selectedDate)!,
                      content: "明天的日记内容。"),
            DiaryPage(date: selectedDate,
                      content: "今天的日记内容。"),
            DiaryPage(date: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!,
                      content: "昨天的日记内容。")
        ]
    }

    // 更新 selectedDate，调整日期
//    func updateSelectedDate(for page: Int) {
//        if page == 0 {
//            // 用户向左滑，日期减一天
//            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
//        } else if page == 2 {
//            // 用户向右滑，日期加一天
//            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
//        }
//        print("selectedDate:\(selectedDate)")
//
//        // 重置 currentPage 为中间页
////        currentPage = 1
//    }

    // 格式化日期
//    func formattedDate(for date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
}

struct DiaryPage: View {
    let date: Date
    let content: String

    var body: some View {
        VStack {
            Text(formattedDate(for: date)) // 显示日期
                .font(.title)
                .padding()
            Text(content) // 显示当天日记内容
                .padding()
        }
    }
    
    // 格式化日期
    func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct DiaryPageViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]
    @Binding var currentIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .pageCurl, // 翻书效果
            navigationOrientation: .horizontal,
            options: nil
        )

        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        print("today:\(Date())")

        print("Current Pages Dates==:")
        for page in pages {
            if let diaryPage = (page as? DiaryPage) {
                print(diaryPage.formattedDate(for: diaryPage.date))
            }
        }
        // 设置初始页为中间页（今天）
        // 防止越界访问，确保 controllers 数量足够
//        let controllersCount = context.coordinator.controllers.count
//        let orgPage: Int = (context.coordinator.controllers.count == 2) ? 0 : 1
        pageViewController.setViewControllers(
            [context.coordinator.controllers[1]], direction: .forward, animated: false
        )

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
//        let visibleViewController = pageViewController.viewControllers?.first
//        let currentVisibleIndex = context.coordinator.controllers.firstIndex(of: visibleViewController!)
//
//        if currentVisibleIndex != currentPage {
//            pageViewController.setViewControllers(
//                [context.coordinator.controllers[currentPage]], direction: .forward, animated: true
//            )
//        }
//        print("selectedDate:\(selectedDate)")

    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: DiaryPageViewController
        var controllers = [UIViewController]()

        init(_ pageViewController: DiaryPageViewController) {
            parent = pageViewController
            controllers = parent.pages.map { UIHostingController(rootView: $0) }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            return index == 0 ? nil : controllers[index - 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            return index + 1 == controllers.count ? nil : controllers[index + 1]
        }

        // 当翻页动画完成时，更新 currentPage
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            if completed, let visibleViewController = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleViewController)
            {
                print("index:\(index)")

                // 打印 pages 中的所有 date
                let dp = parent.pages[index] as! DiaryPage
                print(dp.formattedDate(for: dp.date))

                for page in parent.pages {
                    if let diaryPage = (page as? DiaryPage) {
                        print(diaryPage.formattedDate(for: diaryPage.date))
                    }
                }
                // 动态更新 pages 数组，确保当前页面为中间页
                if index == 0 {
                    // 向前翻页（显示昨天）
                    parent.pages.removeLast()

                    let newDate = Calendar.current.date(byAdding: .day, value: 1, to: dp.date)!
                    parent.pages.insert(DiaryPage(date: newDate, content: "前一天的日记") as! Page, at: 0)
                } else if index == 2 {
                    // 向后翻页（显示明天）
                    parent.pages.removeFirst()

                    let newDate = Calendar.current.date(byAdding: .day, value: -1, to: dp.date)!
                    parent.pages.append(DiaryPage(date: newDate, content: "后一天的日记") as! Page)
                }
                
                // 打印 pages 中的所有 date
                        print("Current Pages Dates:")
                        for page in parent.pages {
                            if let diaryPage = (page as? DiaryPage) {
                                print(diaryPage.formattedDate(for: diaryPage.date))
                            }
                        }

                // 保证当前页面始终在中间
                controllers = parent.pages.map { UIHostingController(rootView: $0) }

//                parent.currentIndex = 1
                pageViewController.setViewControllers([self.controllers[1]], direction: .forward, animated: false)
            }
        }
    }
}

#Preview {
    ContentView()
}
