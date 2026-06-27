import XCTest
import SwiftUI
import SwiftData
@testable import VoiceDiary

// MARK: - 视图多设备渲染自测

/// 在每个代表设备尺寸下渲染关键页面，验证不崩溃、不产生明显布局溢出。
/// 使用 UIHostingController + UIWindow 强制 layout，模拟真实屏幕环境。
@MainActor
final class ViewSizeTests: XCTestCase {

    // MARK: 设备尺寸定义

    private struct Device {
        let name: String
        let size: CGSize  // pt
        init(_ name: String, _ size: CGSize) { self.name = name; self.size = size }
    }

    private let devices: [Device] = [
        Device("SE",          CGSize(width: 375, height: 667)),   // iPhone SE (3rd gen)
        Device("16 Pro",      CGSize(width: 393, height: 852)),   // iPhone 16 Pro
        Device("Pro Max",     CGSize(width: 430, height: 932)),   // iPhone 16 Pro Max
        Device("iPad 10",     CGSize(width: 820, height: 1180)),  // iPad (10th gen)
    ]

    // MARK: 通用渲染 helper

    /// 将给定 View 放进 UIHostingController，在指定尺寸下 layout，返回 hosting controller。
    /// 若 layout 过程中抛异常（如约束冲突导致 crash），测试直接失败。
    private func render<V: View>(_ view: V, at size: CGSize, file: StaticString = #filePath, line: UInt = #line) -> UIHostingController<V> {
        let h = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = h
        window.makeKeyAndVisible()
        // 强制 layout：确保 body 全部展开
        h.view.frame = CGRect(origin: .zero, size: size)
        h.view.setNeedsLayout()
        h.view.layoutIfNeeded()
        return h
    }

    // MARK: 列表页

    func testDiaryListView_allDevices() {
        let container = PreviewHelper.container()
        for device in devices {
            let h = render(
                PreviewWrapper(container: container) { DiaryListView() },
                at: device.size
            )
            XCTAssertNotNil(h.view, "\(device.name) should render DiaryListView")
        }
    }

    // MARK: 编辑器

    func testAddDiaryView_allDevices() {
        let container = PreviewHelper.container()
        for device in devices {
            let h = render(
                PreviewWrapper(container: container) { AddDiaryView() },
                at: device.size
            )
            XCTAssertNotNil(h.view, "\(device.name) should render AddDiaryView")
        }
    }

    // MARK: 日记详情

    func testDiaryDetailView_allDevices() {
        let container = PreviewHelper.container()
        let entry = makeSampleEntry()
        container.mainContext.insert(entry)
        for device in devices {
            let h = render(
                PreviewWrapper(container: container) { DiaryDetailView(entry: entry, page: 1) },
                at: device.size
            )
            XCTAssertNotNil(h.view, "\(device.name) should render DiaryDetailView")
        }
    }

    // MARK: 设置页

    func testSettingsView_allDevices() {
        let container = PreviewHelper.container()
        for device in devices {
            let h = render(
                PreviewWrapper(container: container) { SettingsView() },
                at: device.size
            )
            XCTAssertNotNil(h.view, "\(device.name) should render SettingsView")
        }
    }

    // MARK: 洞察页

    func testInsightsView_allDevices() {
        let container = PreviewHelper.container()
        for device in devices {
            let h = render(
                PreviewWrapper(container: container) { InsightsView() },
                at: device.size
            )
            XCTAssertNotNil(h.view, "\(device.name) should render InsightsView")
        }
    }

    // MARK: 封面页

    func testCoverView_allDevices() {
        for device in devices {
            let view = CoverView()
                .environment(ThemeManager())
                .environment(\.palette, .darkGold)
            let h = render(view, at: device.size)
            XCTAssertNotNil(h.view, "\(device.name) should render CoverView")
        }
    }

    // MARK: 付费墙

    func testPaywallView_allDevices() {
        for device in devices {
            let view = PaywallView(feature: .general)
                .environment(\.palette, .darkGold)
            let h = render(view, at: device.size)
            XCTAssertNotNil(h.view, "\(device.name) should render PaywallView")
        }
    }

    // MARK: 布局溢出检测

    /// 检查关键页面在最小屏（SE）下子 view 宽度不超过屏幕宽度。
    func testNoHorizontalOverflow_onSmallestScreen() {
        let container = PreviewHelper.container()
        let seSize = CGSize(width: 375, height: 667)

        let views: [(String, AnyView)] = [
            ("List",     AnyView(PreviewWrapper(container: container) { DiaryListView() })),
            ("Editor",   AnyView(PreviewWrapper(container: container) { AddDiaryView() })),
            ("Settings", AnyView(PreviewWrapper(container: container) { SettingsView() })),
            ("Insights", AnyView(PreviewWrapper(container: container) { InsightsView() })),
        ]

        for (name, view) in views {
            let h = render(view, at: seSize)
            let overflowing = Self.findOverflowingSubviews(in: h.view, parentWidth: seSize.width)
            XCTAssertTrue(overflowing.isEmpty,
                "\(name) has subviews exceeding SE width (375pt): \(overflowing.map { "\($0.0) x=\(String(format: "%.0f", $0.1)) w=\(String(format: "%.0f", $0.2))" }.joined(separator: "; "))")
        }
    }

    /// 递归遍历所有子 view，返回宽度超出父容器宽度的列表。
    /// 跳过装饰性视图（UIImageView、渐变等系统 background view），只关心实际内容溢出。
    private static func findOverflowingSubviews(in root: UIView, parentWidth: CGFloat) -> [(String, CGFloat, CGFloat)] {
        var results: [(String, CGFloat, CGFloat)] = []
        /// 这些类型是系统/装饰用，超宽是故意的，不算布局 bug。
        let skipTypes: Set<String> = ["UIImageView", "_UIGradientView", "_UIBackgroundConfigurationView"]
        func walk(_ v: UIView) {
            let typeName = String(describing: type(of: v))
            if !skipTypes.contains(typeName) {
                let f = v.frame
                if f.origin.x + f.size.width > parentWidth + 1 {  // 1pt 容差
                    results.append((typeName, f.origin.x, f.size.width))
                }
            }
            for sub in v.subviews { walk(sub) }
        }
        walk(root)
        return results
    }

    // MARK: - Helpers

    private func makeSampleEntry() -> DiaryEntry {
        DiaryEntry(
            content: "今天是个好日子，阳光洒在窗台上。\n\n傍晚去跑了步，整个人清爽了。",
            date: Date(),
            location: "上海 · 武康路",
            showLocation: true,
            emoji: "😊"
        )
    }
}

// MARK: - PreviewHelper 数据完整性测试

@MainActor
final class PreviewHelperTests: XCTestCase {
    func testContainerHasEntries() {
        let container = PreviewHelper.container()
        let ctx = container.mainContext
        let fd = FetchDescriptor<DiaryEntry>()
        let count = (try? ctx.fetchCount(fd)) ?? 0
        XCTAssertGreaterThan(count, 0, "Preview container should have sample entries")
    }

    func testSampleEntryHasContent() {
        let entry = PreviewHelper.sampleEntry()
        XCTAssertFalse(entry.content.isEmpty)
        XCTAssertFalse(entry.emoji.isEmpty)
        XCTAssertTrue(entry.showLocation)
    }
}
