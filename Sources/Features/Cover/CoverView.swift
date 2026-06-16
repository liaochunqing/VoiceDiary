import SwiftUI
import SwiftData

/// 皮质封面「正面」：皮革渐变 + 中部皮带 + 暗金标题。启动动画与封面页共用。
struct CoverFace: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.leather, Palette.leatherDark],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Palette.gold.opacity(0.22)
                .frame(height: 2)
                .frame(maxHeight: .infinity, alignment: .center)

            VStack(spacing: Metric.s) {
                Text("我 的 日 记")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(Palette.gold)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                Text("VOICE DIARY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Palette.gold.opacity(0.65))
            }
            .offset(y: -12)
        }
    }
}

struct CoverView: View {
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
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, Metric.l)
                        .padding(.vertical, Metric.s)
                        .background(
                            Capsule().fill(Palette.gold.opacity(0.15))
                                .overlay(Capsule().strokeBorder(Palette.gold, lineWidth: 1))
                        )
                        .padding(.bottom, Metric.l)
                }
                Text("轻触翻开")
                    .font(.dCaption)
                    .foregroundStyle(Palette.gold.opacity(0.55))
                    .padding(.bottom, Metric.xl)
            }
        }
    }
}
