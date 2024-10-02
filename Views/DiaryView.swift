import SwiftUI
import UIKit

struct DiaryView: View {
    @State private var currentDate = Date()

        var body: some View {
            DiaryPageViewController(currentDate: $currentDate)
                .edgesIgnoringSafeArea(.all) // 全屏显示
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

struct DiaryPageViewController: UIViewControllerRepresentable {
    @Binding var currentDate: Date
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
//        let pageViewController = UIPageViewController(
//            transitionStyle: .pageCurl, // 翻书效果
//            navigationOrientation: .horizontal,
//            options: nil
            
            let pageViewController = UIPageViewController(
                transitionStyle: .pageCurl, // 翻书效果
                navigationOrientation: .horizontal,
                options: nil
        )

        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator

        // 初始化中间页（今天）
        let todayVC = context.coordinator.viewControllerFor(date: currentDate)
        pageViewController.setViewControllers([todayVC], direction: .forward, animated: false)

        return pageViewController
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        // 如果需要在 SwiftUI 中手动更新视图，可以在这里操作
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: DiaryPageViewController

        init(_ pageViewController: DiaryPageViewController) {
            parent = pageViewController
        }
        
        // 获取特定日期的日记视图控制器
        func viewControllerFor(date: Date) -> UIViewController {
            let entry = loadDiaryEntry(for: date)
            let viewController = UIViewController()
            let label = UILabel()
            label.text = entry.content
            label.textAlignment = .center
            label.frame = viewController.view.bounds
            viewController.view.addSubview(label)
            return viewController
        }

        // 动态加载日记条目
        func loadDiaryEntry(for date: Date) -> DiaryEntry {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            
            // 生成一个随机的标题，可以根据需要修改
            let title = "日记标题：\(formatter.string(from: date))"
            
            // 示例内容，这里也可以根据需求动态生成
            let content = "日记内容：\(formatter.string(from: date))"
            
            // 创建并返回一个新的 DiaryEntry 实例
            return DiaryEntry(title: title, content: content, date: date)
        }

        // 翻到前一天
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            let previousDate = Calendar.current.date(byAdding: .day, value: 1, to: parent.currentDate)!
            return viewControllerFor(date: previousDate)
        }

        // 翻到后一天
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            let nextDate = Calendar.current.date(byAdding: .day, value: -1, to: parent.currentDate)!
            return viewControllerFor(date: nextDate)
        }

        // 翻页完成后更新 currentDate
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            if completed, let visibleViewController = pageViewController.viewControllers?.first,
               let label = visibleViewController.view.subviews.first as? UILabel,
               let content = label.text {
                // 根据显示的内容动态更新 currentDate
                if let newDate = extractDate(from: content) {
                    parent.currentDate = newDate
                }
            }
        }

        // 从日记内容中提取日期（假设内容中包含日期信息）
        func extractDate(from content: String) -> Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            // 假设 content 是 "日记内容：2024年10月2日" 这样的格式
            let components = content.components(separatedBy: "：")
            return components.count > 1 ? formatter.date(from: components[1]) : nil
        }
    }
}
#Preview {
    ContentView()
}
