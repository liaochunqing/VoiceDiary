//
//  mainListView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/17.
//

import Foundation
import SwiftUI
import Combine
import SwiftData

struct MainListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.date, order: .reverse) private var allEntries: [DiaryEntry]
    @AppStorage("existHelpEntry") private var existHelpEntry = false

    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    @EnvironmentObject var locationManager: LocationManager
    @State private var emojiString: String = "🙂"

    var filteredEntries: [DiaryEntry] {
        if searchText.isEmpty {
            return allEntries
        } else {
            return allEntries.filter { entry in
                (entry.content?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                entry.emojiString.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 搜索框
            SearchBar(text: $searchText, isFocused: $isSearchFieldFocused)
                .padding(.top)

            // 日记列表
            DiaryListView(
                entries: filteredEntries,
                modelContext: modelContext,
                searchText: $searchText,
                isSearchFieldFocused: $isSearchFieldFocused
            )
        }
        .onAppear {
            if !existHelpEntry
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    checkAndInsertDefaultEntry()
                    existHelpEntry = true
                }
            }
        }
    }

    private func checkAndInsertDefaultEntry() {
        if !allEntries.contains(where: { $0.content == defaultContent }) {
            let defaultEntry = DiaryEntry(
                id: UUID(),
                content: defaultContent,
                date: Date(),
                location: locationManager.address,
                emojiString: emojiString,
                fontStyle: ""
            )
            
            modelContext.insert(defaultEntry)
        }
    }
}

struct DiaryListView: View {
    @EnvironmentObject var emojiSettings: EmojiSettings
    @State private var emojis: [String] = []

    @State private var isTapDisabled = false
    @AppStorage("showLocation") private var showLocation: Bool = true
    @AppStorage("emojiPlacement") private var emojiPlacement: String = "settings"

    let entries: [DiaryEntry]
    let modelContext: ModelContext
    @EnvironmentObject var globalData: GlobalData
    @Binding var searchText: String
    var isSearchFieldFocused: FocusState<Bool>.Binding
    let subFontSize = W_SCALE(13)

    var body: some View {
        if emojiPlacement == "list" {
            EmojiBubbleView(
                width: Screen.width - 2 * W_SCALE(16),
                height: H_SCALE(170),
                emojis: emojis,
                emojiSize: emojiSettings.emojisSize,
                isRotationEnabled:emojiSettings.isRotationEnabled,
                gravityScale: emojiSettings.gravityScale,
                isThemeChanged: emojiSettings.isThemeChanged
            )
            .onAppear {
                emojis = DataManager.fetchEmojis(for: .month, in: modelContext)
                }
        }
        
        ScrollViewReader { proxy in
            List {
                ForEach(entries.indices, id: \.self) { i in
                    let entry = entries[i]
                    
                    VStack(alignment: .leading, spacing: H_SCALE(3)) {
                        HStack(spacing: W_SCALE(10)) {
                            Text(formatDate(entry.date))
                                .font(.system(size: subFontSize))
                                .foregroundStyle(.secondary)
                                .frame(alignment: .leading)
                                .multilineTextAlignment(.leading)
                            
                            Text("\(entry.emojiString)")
                                .font(.body)
                            Spacer()
                            
                            // 在这里加编号，格式化成三位数
                            Text(String(format: "%d", i + 1))
                                .font(.system(size: subFontSize))
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.content ?? "")
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(entry.fontColor)
                            .font(.custom(entry.fontStyle, size: entry.fontSize))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        
                        if entry.showLocation {
                            Text(entry.location ?? "")
                                .font(.system(size: subFontSize))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .frame(height: Screen.height * 0.105)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.tertiarySystemBackground))
                    .contentShape(Rectangle())
                    .id(entry.id) // 为滚动定位设置 ID
                    .onTapGesture {
                        guard !isTapDisabled else { return }
                        isTapDisabled = true
                        var gaptime = 0.01
                        
                        // 根据搜索框焦点状态决定是否执行动画滚动
                        if isSearchFieldFocused.wrappedValue {
                            // 退出搜索模式
                            searchText = ""
                            isSearchFieldFocused.wrappedValue = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(entry.id, anchor: .top)
                                }
                            }
                            gaptime = 0.5
                        }
                        
                        // 延迟跳转，确保滚动动画完成
                        DispatchQueue.main.asyncAfter(deadline: .now() + gaptime) {
                            let index = globalData.getIndexOfPageBy(entry: entry, entries: entries)
                            globalData.pageUpdate = true
                            globalData.currentIndex = index
                            globalData.moveToPage = true
                            isTapDisabled = false
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .listRowSpacing(H_SCALE(15))
            .listStyle(PlainListStyle())
            .padding(.horizontal)
            .shadow(color: Color.primary.opacity(0.3), radius: 4, x: 1, y: 1)

        }
    }
        

}


struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("搜索内容或地点...", text: $text)
                    .focused($isFocused)
                    .onTapGesture {
                        isFocused = true
                    }

                if !text.isEmpty {
                    Button(action: {
                        self.text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            if isFocused {
                Button("取消") {
                    self.text = ""
                    isFocused = false
                }
                .padding(.leading, 8)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isFocused)
            }
        }
        .padding(.horizontal)
    }
}
#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(
                    try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
