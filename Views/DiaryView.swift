import SwiftUI

struct DiaryView: View {
    @State private var currentPage = 1 // 中间页为今天，0为昨天，2为明天
    @State private var selectedDate = Date() // 当前的日期

    var body: some View {
        VStack {
            // Diary Pages
            DiaryPageViewController(pages: getDiaryEntries(), currentPage: $currentPage)
                .ignoresSafeArea() // 全屏显示
                .onChange(of: currentPage) { newPage in
                    // 更新 selectedDate，调整日期
                    updateSelectedDate(for: newPage)
                }
        }
    }

    // 获取当前的日记数据（昨天、今天、明天）
    func getDiaryEntries() -> [DiaryPage] {
        return [
            DiaryPage(date: formattedDate(for: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!),
                      content: "昨天的日记内容。"),
            DiaryPage(date: formattedDate(for: selectedDate),
                      content: "今天的日记内容。"),
            DiaryPage(date: formattedDate(for: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!),
                      content: "明天的日记内容。")
        ]
    }

    // 更新 selectedDate，调整日期
    func updateSelectedDate(for page: Int) {
        if page == 0 {
            // 用户向左滑，日期减一天
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        } else if page == 2 {
            // 用户向右滑，日期加一天
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        }
        
        // 重置 currentPage 为中间页
        currentPage = 1
    }

    // 格式化日期
    func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct DiaryPage: View {
    let date: String
    let content: String

    var body: some View {
        VStack {
            Text(date) // 显示日期
                .font(.title)
                .padding()
            Text(content) // 显示当天日记内容
                .padding()
        }
    }
}

struct DiaryPageViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]
    @Binding var currentPage: Int

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

        // 设置初始页为中间页（今天）
        pageViewController.setViewControllers(
            [context.coordinator.controllers[currentPage]], direction: .forward, animated: false
        )

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        let visibleViewController = pageViewController.viewControllers?.first
        let currentVisibleIndex = context.coordinator.controllers.firstIndex(of: visibleViewController!)

        if currentVisibleIndex != currentPage {
            pageViewController.setViewControllers(
                [context.coordinator.controllers[currentPage]], direction: .forward, animated: false
            )
        }
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
                parent.currentPage = index
            }
        }
    }
}

#Preview {
    ContentView()
}
