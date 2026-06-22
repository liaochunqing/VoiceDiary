import SwiftUI

// MARK: - 纸张材质语言（全主题共用）
//
// 统一的「新拟物 / 纸感」规则，与配色解耦：
//   · 卡片 = 比底纸更亮的卡面 + 双层柔和阴影 + 顶亮底暗的发丝斜面（替代生硬 1px 全描边）
//   · 底纸 = 纯色 + 极淡上光泽 + 一层细微颗粒，营造真实纸张厚度
// 配色由各 palette 决定，材质规则恒定 → 5 套主题质感统一。
// 阴影一律用中性黑（深色模式下 pal.ink 是亮色，当阴影会变发光，故不可用）。

/// 确定性随机：颗粒分布稳定，不每帧抖动。
private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 2685821657736338717 &+ 1 }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}

/// 纸张颗粒：一次性铺满的细微噪点，正片叠底叠在底纸上。
struct PaperGrain: View {
    var opacity: Double = 0.035

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 7)
            let count = Int(size.width * size.height / 900)
            for _ in 0..<count {
                let x = rng.next() * size.width
                let y = rng.next() * size.height
                let s = 0.5 + rng.next() * 0.9
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color(.black.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

/// 整屏底纸：纯色 + 顶部微光泽 + 底部极淡阴影 + 颗粒。
struct PaperBackground: View {
    @Environment(\.palette) private var pal

    var body: some View {
        ZStack {
            pal.paper
            LinearGradient(
                colors: [Color.white.opacity(0.05), .clear, .black.opacity(0.04)],
                startPoint: .top, endPoint: .bottom)
            PaperGrain()
        }
        .ignoresSafeArea()
    }
}

/// 纸面浮起感：亮卡面 + 顶亮底暗发丝斜面 + 双层柔和投影（环境光 + 接触影）。
struct DiaryCardModifier: ViewModifier {
    @Environment(\.palette) private var pal
    var radius: CGFloat = Metric.cardRadius
    var elevation: CGFloat = 1   // 1 = 标准卡片，0.5 = 轻浮（搜索框等）

    func body(content: Content) -> some View {
        content
            .background(pal.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), pal.line.opacity(0.45)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10 * elevation), radius: 12 * elevation, y: 6 * elevation)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

/// 带横线纸纹的正文信纸卡：纸纹在底、文字在上 + 同款斜面与柔和投影。
struct PaperLinedCardModifier: ViewModifier {
    @Environment(\.palette) private var pal
    var radius: CGFloat = Metric.cardRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(pal.card)
                    .overlay(
                        PaperLines(color: pal.line.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), pal.line.opacity(0.45)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

/// 圆 / 胶囊等小控件的纸感软边：渐变发丝边 + 轻投影（替代生硬描边）。
struct SoftEdgeModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var pal
    let shape: S
    var elevation: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), pal.line.opacity(0.45)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07 * elevation), radius: 4 * elevation, y: 2 * elevation)
    }
}

extension View {
    /// 统一纸感卡片：去硬边框，改柔和分层阴影 + 发丝斜面。
    func diaryCard(radius: CGFloat = Metric.cardRadius, elevation: CGFloat = 1) -> some View {
        modifier(DiaryCardModifier(radius: radius, elevation: elevation))
    }

    /// 横线纸纹信纸卡（正文卡 / 编辑区）。
    func paperLinedCard(radius: CGFloat = Metric.cardRadius) -> some View {
        modifier(PaperLinedCardModifier(radius: radius))
    }

    /// 小控件软边（圆 / 胶囊），传入与背景同形状的 shape。
    func softEdge<S: InsettableShape>(_ shape: S, elevation: CGFloat = 1) -> some View {
        modifier(SoftEdgeModifier(shape: shape, elevation: elevation))
    }
}

/// 日记本横线纸纹：等距横线，叠在卡片底色上营造纸张质感。
struct PaperLines: View {
    var spacing: CGFloat = 28
    var color: Color = Color(lightHex: 0xD9CBAC, darkHex: 0x3E3222)

    var body: some View {
        Canvas { ctx, size in
            var y = spacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), lineWidth: 1)
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// 线性水滴定位针：SF Symbols 没有干净的「📍水滴」描边符号，这里自绘。
/// 用 quad 曲线拼水滴轮廓 + 内圆，描边风、轻量，配在地点文字前。
struct LocationPin: View {
    var size: CGFloat = 13
    var color: Color = .accentColor
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { ctx, sz in
            let k = min(sz.width, sz.height) / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }

            // 水滴轮廓：底尖(12,21) → 右(19,9) → 顶(12,2) → 左(5,9) → 回尖
            var drop = Path()
            drop.move(to: p(12, 21))
            drop.addQuadCurve(to: p(19, 9), control: p(18, 16))
            drop.addQuadCurve(to: p(12, 2), control: p(19, 2))
            drop.addQuadCurve(to: p(5, 9),  control: p(5, 2))
            drop.addQuadCurve(to: p(12, 21), control: p(6, 16))
            drop.closeSubpath()
            ctx.stroke(drop, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))

            // 内圆
            let r = 2.4 * k
            let circle = Path(ellipseIn: CGRect(x: 12 * k - r, y: 9 * k - r, width: r * 2, height: r * 2))
            ctx.stroke(circle, with: .color(color), lineWidth: lineWidth)
        }
        .frame(width: size, height: size)
    }
}
