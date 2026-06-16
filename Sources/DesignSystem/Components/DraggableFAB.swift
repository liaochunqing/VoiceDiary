import SwiftUI

struct DraggableFAB: View {
    @Environment(\.palette) private var pal
    let action: () -> Void

    @State private var totalOffset: CGSize = .zero
    @State private var currentDrag: CGSize = .zero

    var body: some View {
        Circle()
            .fill(pal.accent)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(pal.onAccent)
            )
            .shadow(color: pal.accent.opacity(0.35), radius: 8, y: 4)
            .offset(x: totalOffset.width + currentDrag.width,
                    y: totalOffset.height + currentDrag.height)
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { v in currentDrag = v.translation }
                    .onEnded { v in
                        totalOffset.width  += v.translation.width
                        totalOffset.height += v.translation.height
                        currentDrag = .zero
                    }
            )
            .onTapGesture { action() }
    }
}
