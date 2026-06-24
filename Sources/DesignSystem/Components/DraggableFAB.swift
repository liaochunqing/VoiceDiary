import SwiftUI

// MARK: - AddEntryFAB
//
// 目录页「新增」按钮：传统圆形悬浮按钮（FAB）。
// 之前那颗会坠落/颤动/可拖拽的「水滴」效果不佳，已恢复为标准做法：
// 一个填充主题色的圆 + 居中「+」，轻按缩放反馈即可。
// 前 4 次打开仍自动冒出「New Entry」气泡提示，帮助发现。

struct AddEntryFAB: View {
    @Environment(\.palette) private var pal
    let action: () -> Void

    @State private var showHint = false
    @AppStorage("fabHintCount") private var hintCount = 0

    private let size: CGFloat = 60

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.05)) { showHint = false }
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pal.accentSoft.opacity(0.98), pal.accent, pal.leather],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: pal.accent.opacity(0.45), radius: 12, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(pal.onAccent)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(FABPressStyle())
        // "New Entry" 气泡提示：前 4 次打开自动出现
        .overlay(alignment: .trailing) {
            if showHint {
                NewEntryHint(palette: pal)
                    .fixedSize()
                    .offset(x: -72)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 8)),
                        removal:   .opacity
                    ))
            }
        }
        .onAppear { scheduleHint() }
        .accessibilityLabel(Text("New Entry"))
    }

    private func scheduleHint() {
        guard hintCount < 4 else { return }
        hintCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.72)) { showHint = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                withAnimation(.easeOut(duration: 0.38)) { showHint = false }
            }
        }
    }
}

// MARK: - 按压反馈（轻微缩放）

private struct FABPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - "New Entry" 提示气泡

private struct NewEntryHint: View {
    let palette: DiaryPalette

    var body: some View {
        HStack(spacing: 5) {
            Text("New Entry")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.onAccent)
            Image(systemName: "pencil.tip")
                .font(.system(size: 10))
                .foregroundStyle(palette.onAccent.opacity(0.80))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(palette.accent)
                .shadow(color: palette.accent.opacity(0.5), radius: 8, y: 3)
        )
        // 右侧三角指针
        .overlay(alignment: .trailing) {
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 7))
                .foregroundStyle(palette.accent)
                .offset(x: 5)
        }
    }
}
