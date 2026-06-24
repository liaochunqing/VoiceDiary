import SwiftUI

/// 字体自定义底部面板。展示在编辑器中，实时预览 + 字体 / 字号 / 颜色 / 行距选择。
struct FontPickerPanel: View {
    @Environment(\.palette) private var pal

    @Binding var font: DiaryFont
    @Binding var size: Double
    @Binding var color: DiaryFontColor

    let onClose: () -> Void
    let onApply: () -> Void
    let onPaywall: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽把手
            Capsule()
                .fill(pal.line)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: Metric.m) {
                    // 实时预览
                    previewCard

                    // 字体选择
                    sectionLabel("Font")
                    fontGrid

                    // 字号
                    sectionLabel("Size")
                    sizeRow

                    // 颜色
                    sectionLabel("Color")
                    colorRow
                }
                .padding(.horizontal, Metric.l)
                .padding(.bottom, Metric.l)
            }

            // 操作按钮固定在面板底部，不随内容滚动消失
            actionButtons
                .padding(.horizontal, Metric.l)
                .padding(.top, Metric.m)
                .padding(.bottom, Metric.m)
                .background(pal.paper)
                .overlay(alignment: .top) {
                    Rectangle().fill(pal.line).frame(height: 1)
                }
        }
        .background(pal.paper)
    }

    // MARK: - 实时预览

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Metric.xs) {
            Text("Preview")
                .font(.dLabel)
                .foregroundStyle(pal.inkSoft)
            Text("A quiet moment, written down. 0123")
                .font(font.swiftUIFont(size: size))
                .foregroundStyle(color.resolved(palette: pal))
                .padding(Metric.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .diaryCard()
        }
    }

    // MARK: - 字体卡⽚

    private var fontGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Metric.s), count: DiaryFont.allCases.count),
            spacing: Metric.s
        ) {
            ForEach(DiaryFont.allCases, id: \.self) { f in
                fontCard(f)
            }
        }
    }

    private func fontCard(_ f: DiaryFont) -> some View {
        Button {
            if !f.isBuiltIn, !PurchaseManager.shared.isUnlocked {
                onPaywall()
            } else {
                font = f
            }
        } label: {
            Text("Aa")
                .font(f.swiftUIFont(size: 22))
                .foregroundStyle(pal.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metric.s)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metric.s)
            .background(
                font == f ? pal.accent.opacity(0.12) : pal.card,
                in: RoundedRectangle(cornerRadius: Metric.thumbRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.thumbRadius)
                    .stroke(font == f ? pal.accent : pal.line, lineWidth: font == f ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if font == f {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(pal.accent)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 字号

    private var sizeRow: some View {
        HStack(spacing: Metric.m) {
            Slider(value: $size, in: 15...30, step: 1)
                .tint(pal.accent)
            TextField("", value: $size, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 48)
                .padding(.vertical, Metric.xs)
                .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.thumbRadius))
                .softEdge(RoundedRectangle(cornerRadius: Metric.thumbRadius), elevation: 0.5)
                .onChange(of: size) { _, v in
                    if v < 15 { size = 15 }
                    if v > 30 { size = 30 }
                }
        }
    }

    // MARK: - 颜色

    private var colorRow: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
            spacing: 10
        ) {
            ForEach(DiaryFontColor.allCases, id: \.self) { c in
                Button { color = c } label: {
                    ZStack {
                        Circle()
                            .fill(c.resolved(palette: pal))
                            .frame(width: 32, height: 32)
                        Circle()
                            .strokeBorder(
                                color == c ? pal.accent : pal.line,
                                lineWidth: color == c ? 2.5 : 1
                            )
                            .frame(width: 32, height: 32)
                        if color == c {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 按钮

    private var actionButtons: some View {
        HStack(spacing: Metric.m) {
            Button(action: onClose) {
                Text("Close")
                    .font(.dCallout.weight(.semibold))
                    .foregroundStyle(pal.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metric.s)
                    .diaryCard(radius: Metric.buttonRadius, elevation: 0.5)
            }
            Button(action: onApply) {
                Text("Apply")
                    .font(.dCallout.weight(.semibold))
                    .foregroundStyle(pal.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metric.s)
                    .background(pal.accent, in: RoundedRectangle(cornerRadius: Metric.buttonRadius))
            }
        }
    }

    // MARK: - 共用

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: Metric.xs) {
            Circle()
                .fill(pal.gold)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.dLabel)
                .foregroundStyle(pal.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
