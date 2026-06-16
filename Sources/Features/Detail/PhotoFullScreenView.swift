import SwiftUI

struct PhotoFullScreenView: View {
    let photos: [Data]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    init(photos: [Data], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(photos.indices, id: \.self) { i in
                    if let ui = UIImage(data: photos[i]) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(currentIndex == i ? scale : 1)
                            .offset(currentIndex == i ? offset : .zero)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { v in scale = max(1, v) }
                                    .onEnded { _ in
                                        withAnimation(.spring) { scale = 1; offset = .zero }
                                    }
                                    .simultaneously(with:
                                        DragGesture()
                                            .onChanged { v in
                                                if scale > 1 { offset = v.translation }
                                            }
                                            .onEnded { _ in
                                                if scale <= 1 {
                                                    withAnimation(.spring) { offset = .zero }
                                                }
                                            }
                                    )
                            )
                    }
                    Text("").tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))

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
}
