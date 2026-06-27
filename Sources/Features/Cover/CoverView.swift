import SwiftUI
import SwiftData

/// 皮质封面「正面」：皮革渐变 + 中部皮带 + 暗金标题。启动动画与封面页共用。
struct CoverFace: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let pal = themeManager.palette
        let colors = themeManager.current.leatherGradient
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            pal.gold.opacity(0.22)
                .frame(height: 2)
                .frame(maxHeight: .infinity, alignment: .center)

            VStack(spacing: Metric.m) {
                Text("My Diary")
                    .font(.system(size: 60, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(pal.gold)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                Text("VOICEPAPER")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(pal.gold.opacity(0.65))
                Text("Open the book. Talk to it.")
                    .font(.system(size: 14))
                    .tracking(2)
                    .foregroundStyle(pal.gold.opacity(0.5))
                    .padding(.top, Metric.xs)
            }
            .offset(y: -12)
        }
    }
}

struct CoverView: View {
    @Environment(\.palette) private var pal

    var body: some View {
        ZStack {
            CoverFace()
            VStack {
                Spacer()
                Text("Swipe to open")
                    .font(.dSubhead)
                    .foregroundStyle(pal.gold.opacity(0.55))
                    .padding(.bottom, Metric.xl)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct CoverView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CoverView()
                .environment(ThemeManager())
                .environment(\.palette, .darkGold)
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("SE")

            CoverView()
                .environment(ThemeManager())
                .environment(\.palette, .darkGold)
                .previewDevice("iPhone 16 Pro")
                .previewDisplayName("16 Pro")

            CoverView()
                .environment(ThemeManager())
                .environment(\.palette, .darkGold)
                .previewDevice("iPhone 16 Pro Max")
                .previewDisplayName("Pro Max")

            CoverView()
                .environment(ThemeManager())
                .environment(\.palette, .darkGold)
                .previewDevice("iPad (10th generation)")
                .previewDisplayName("iPad 10")
        }
    }
}
#endif
