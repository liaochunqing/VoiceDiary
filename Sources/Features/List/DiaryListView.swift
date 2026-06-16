import SwiftUI
import SwiftData

struct DiaryListView: View {
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @State private var search = ""

    private var filtered: [DiaryEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.content.localizedCaseInsensitiveContains(search) ||
            $0.location.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Palette.paper.ignoresSafeArea()

            VStack(spacing: Metric.m) {
                header
                searchBar
                ScrollView {
                    LazyVStack(spacing: Metric.m) {
                        ForEach(filtered, id: \.id) { entry in
                            let gi = entries.firstIndex { $0.id == entry.id } ?? 0
                            DiaryRow(entry: entry, page: entries.count - gi)
                        }
                    }
                    .padding(.horizontal, Metric.l)
                    .padding(.bottom, 90)
                }
                .scrollIndicators(.hidden)
            }
            fab
        }
    }

    private var header: some View {
        HStack {
            Text("日记").font(.dPageTitle).foregroundStyle(Palette.ink)
            Spacer()
            Button {} label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .background(Palette.card, in: Circle())
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, Metric.l)
        .padding(.top, Metric.s)
    }

    private var searchBar: some View {
        HStack(spacing: Metric.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
            TextField("搜索内容或地点…", text: $search).font(.dSubhead)
        }
        .padding(.horizontal, Metric.m)
        .padding(.vertical, Metric.s)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
        .padding(.horizontal, Metric.l)
    }

    private var fab: some View {
        Button {} label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 56, height: 56)
                .background(Palette.accent, in: Circle())
                .shadow(color: Palette.accent.opacity(0.35), radius: 8, y: 4)
        }
        .padding(Metric.xl)
    }
}

private struct DiaryRow: View {
    let entry: DiaryEntry
    let page: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.xs) {
            HStack(spacing: Metric.xs) {
                Text(dateStr).font(.dCaption).foregroundStyle(Palette.inkSoft)
                dot
                Text(entry.emoji).font(.dCaption)
                dot
                Text("第\(page)页").font(.dCaption).foregroundStyle(Palette.inkSoft)
                if let m = entry.memos.first {
                    dot
                    Text("🎤 \(durStr(m.duration))")
                        .font(.dCaption).fontWeight(.semibold)
                        .foregroundStyle(Palette.accent)
                }
                Spacer()
            }
            Text(entry.content)
                .font(.dSubhead).foregroundStyle(Palette.ink)
                .lineLimit(2).multilineTextAlignment(.leading)
            if entry.showLocation, !entry.location.isEmpty {
                Text(entry.location).font(.dCaption).foregroundStyle(Palette.inkSoft)
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
                }
                .padding(.top, Metric.xs)
            }
        }
        .padding(Metric.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(Palette.line, lineWidth: 1))
    }

    private var dot: some View { Text("·").font(.dCaption).foregroundStyle(Palette.inkSoft) }
    private var dateStr: String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f.string(from: entry.date)
    }
    private func durStr(_ d: Double) -> String { String(format: "%d:%02d", Int(d) / 60, Int(d) % 60) }
}
