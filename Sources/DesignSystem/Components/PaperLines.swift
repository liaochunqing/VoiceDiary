import SwiftUI

/// 日记本横线纸纹：等距横线，叠在卡片底色上营造纸张质感。
struct PaperLines: View {
    var spacing: CGFloat = 28
    var color: Color = Palette.line

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
