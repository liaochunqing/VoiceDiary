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

            VStack(spacing: Metric.s) {
                Text("我 的 日 记")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(pal.gold)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                Text("VOICE DIARY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(pal.gold.opacity(0.65))
            }
            .offset(y: -12)
        }
    }
}

struct CoverView: View {
    @Environment(\.palette) private var pal
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    private var streak: Int { DataManager.currentStreak(entries) }

    var body: some View {
        ZStack {
            CoverFace()
            VStack {
                Spacer()
                if streak > 1 {
                    Text("🔥 连续记录 \(streak) 天")
                        .font(.dCaption)
                        .foregroundStyle(pal.gold)
                        .padding(.horizontal, Metric.l)
                        .padding(.vertical, Metric.s)
                        .background(
                            Capsule().fill(pal.gold.opacity(0.15))
                                .overlay(Capsule().strokeBorder(pal.gold, lineWidth: 1))
                        )
                        .padding(.bottom, Metric.l)
                }
                Text("轻触翻开")
                    .font(.dCaption)
                    .foregroundStyle(pal.gold.opacity(0.55))
                    .padding(.bottom, Metric.xl)
            }
        }
    }
}
