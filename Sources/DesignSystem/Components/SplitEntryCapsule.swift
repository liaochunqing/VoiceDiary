import SwiftUI

// MARK: - SplitEntryCapsule
//
// 目录页右下角「新建日记」胶囊按钮，拆成两段：
//   - ✏️ Write：直接进编辑器，光标就位、键盘弹出。
//   - 🎤 Talk：进编辑器后自动拉起录音界面，用户直接说话。
//
// 不用 Button，直接用 HStack + onTapGesture，避免 Button 内部布局干扰胶囊形状。

struct SplitEntryCapsule: View {
    @Environment(\.palette) private var pal
    let onWrite: () -> Void
    let onTalk: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            writeLabel
            divider
            talkLabel
        }
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [pal.leather, pal.leatherDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    // MARK: - Write

    private var writeLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 15, weight: .semibold))
            Text("Write")
                .font(.dCallout.weight(.semibold))
        }
        .foregroundStyle(pal.onAccent)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 11)
        .contentShape(.rect)
        .onTapGesture { onWrite() }
        .accessibilityLabel(Text("Write a new entry"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 26)
    }

    // MARK: - Talk

    private var talkLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("Talk")
                .font(.dCallout.weight(.semibold))
        }
        .foregroundStyle(pal.gold)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
        .onTapGesture { onTalk() }
        .accessibilityLabel(Text("Record a voice entry"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#if DEBUG
struct SplitEntryCapsule_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(lightHex: 0xF5EBD5, darkHex: 0x1E1810).ignoresSafeArea()
            SplitEntryCapsule(onWrite: {}, onTalk: {})
                .padding()
        }
        .environment(\.palette, .darkGold)
    }
}
#endif
