import SwiftUI

struct PhotoFullScreenView: View {
    let photos: [Data]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragDismissOffset: CGFloat = 0

    init(photos: [Data], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - min(abs(dragDismissOffset) / 220, 0.6))
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { i, photo in
                    if let ui = UIImage(data: photo) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(currentIndex == i ? scale : 1)
                            .offset(currentIndex == i ? offset : .zero)
                            .gesture(photoGesture)
                    }
                    Text("").tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .offset(y: dragDismissOffset)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(radius: 4)
                    }
                    .padding(.top, 56)
                    .padding(.trailing, Metric.l)
                }
                Spacer()
                if photos.count > 1 {
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.dCaption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, Metric.xl)
                }
            }
        }
    }

    private var photoGesture: some Gesture {
        // 放大/缩小手势
        let pinch = MagnificationGesture()
            .onChanged { v in scale = max(0.5, v) }
            .onEnded { v in
                if v < 0.75 {
                    onDismiss()
                } else {
                    withAnimation(.spring) { scale = 1; offset = .zero }
                }
            }

        // 双击放大 / 还原
        let doubleTap = TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring) {
                    scale = scale > 1 ? 1 : 2
                    offset = .zero
                }
            }

        // 拖拽：放大时平移图片；正常时下拉关闭
        let drag = DragGesture()
            .onChanged { v in
                if scale > 1 {
                    offset = v.translation
                } else {
                    dragDismissOffset = v.translation.height
                }
            }
            .onEnded { v in
                if scale > 1 {
                    withAnimation(.spring) { offset = .zero }
                } else if abs(v.translation.height) > 80 {
                    onDismiss()
                } else {
                    withAnimation(.spring) { dragDismissOffset = 0 }
                }
            }

        return pinch.simultaneously(with: doubleTap.simultaneously(with: drag))
    }
}
