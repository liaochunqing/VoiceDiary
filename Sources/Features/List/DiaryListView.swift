import SwiftUI
import SwiftData

struct DiaryListView: View {
    @Environment(\.palette) private var pal
    @Environment(\.bookNavigator) private var navigator
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @State private var search = ""
    @State private var showEditor = false

    private var filtered: [DiaryEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.content.localizedCaseInsensitiveContains(search) ||
            $0.location.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            pal.paper.ignoresSafeArea()

            VStack(spacing: Metric.m) {
                header
                searchBar
                ScrollView {
                    LazyVStack(spacing: Metric.m) {
                        ForEach(filtered, id: \.id) { entry in
                            let gi = entries.firstIndex { $0.id == entry.id } ?? 0
                            let page = gi + 1
                            Button {
                                navigator.goToEntry(at: gi)
                            } label: {
                                DiaryRow(entry: entry, page: page)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metric.l)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }

            fab
        }
        .fullScreenCover(isPresented: $showEditor) { AddDiaryView() }
    }

    // MARK: 顶部栏

    private var header: some View {
        HStack {
            Text("目录").font(.dPageTitle).foregroundStyle(pal.ink)
            Spacer()
            Button { navigator.goToSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 36, height: 36)
                    .background(pal.card, in: Circle())
                    .overlay(Circle().stroke(pal.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, Metric.l)
        .padding(.top, Metric.s)
    }

    // MARK: 搜索栏

    private var searchBar: some View {
        HStack(spacing: Metric.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(pal.inkSoft)
            TextField("搜索内容或地点…", text: $search).font(.dSubhead)
        }
        .padding(.horizontal, Metric.m)
        .padding(.vertical, Metric.s)
        .background(pal.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.line, lineWidth: 1))
        .padding(.horizontal, Metric.l)
    }

    // MARK: 新建按钮（可拖拽）

    private var fab: some View {
        DraggableFAB { showEditor = true }
            .padding(Metric.xl)
    }
}

// MARK: - 日记列表行

private struct DiaryRow: View {
    @Environment(\.palette) private var pal
    let entry: DiaryEntry
    let page: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: Metric.xs) {
                HStack(spacing: Metric.xs) {
                    Text(dateStr).font(.dCaption).foregroundStyle(pal.inkSoft)
                    if let m = entry.memos.first {
                        dot
                        Text("🎤 \(durStr(m.duration))")
                            .font(.dCaption).fontWeight(.semibold)
                            .foregroundStyle(pal.accent)
                    }
                    Spacer()
                }
                Text(entry.content)
                    .font(.dSubhead).foregroundStyle(pal.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                if entry.showLocation, !entry.location.isEmpty {
                    Label(entry.location, systemImage: "mappin")
                        .font(.dCaption).foregroundStyle(pal.inkSoft)
                }
                if !entry.photos.isEmpty {
                    HStack(spacing: Metric.xs) {
                        ForEach(entry.photos.prefix(3).indices, id: \.self) { i in
                            if let ui = UIImage(data: entry.photos[i]) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 38, height: 38)
                                    .clipShape(RoundedRectangle(cornerRadius: Metric.thumbRadius))
                            }
                        }
                        if entry.photos.count > 3 {
                            Text("+\(entry.photos.count - 3)")
                                .font(.dCaption).foregroundStyle(pal.inkSoft)
                                .frame(width: 38, height: 38)
                                .background(pal.line, in: RoundedRectangle(cornerRadius: Metric.thumbRadius))
                        }
                    }
                    .padding(.top, Metric.xs)
                }
                // 底部右角占位，防止内容被 badge 遮住
                Color.clear.frame(height: 16)
            }
            .padding(Metric.m)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 第 n 页 badge
            Text("第\(page)页")
                .font(.dMicro)
                .foregroundStyle(pal.inkSoft)
                .padding(.horizontal, Metric.s)
                .padding(.vertical, 3)
                .background(pal.paper, in: Capsule())
                .overlay(Capsule().stroke(pal.line, lineWidth: 1))
                .padding(Metric.s)
        }
        .background(pal.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(pal.line, lineWidth: 1))
    }

    private var dot: some View { Text("·").font(.dCaption).foregroundStyle(pal.inkSoft) }
    private var dateStr: String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f.string(from: entry.date)
    }
    private func durStr(_ d: Double) -> String { String(format: "%d:%02d", Int(d) / 60, Int(d) % 60) }
}
