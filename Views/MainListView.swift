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
    
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

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
            .padding(.horizontal)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
        }
        .onChange(of: allEntries) {
            checkAndInsertDefaultEntry()
            }
        .onAppear {
            checkAndInsertDefaultEntry()
            }
    }

    private func checkAndInsertDefaultEntry() {
        if !allEntries.contains(where: { $0.content == defaultContent }) {
            let defaultEntry = DiaryEntry(id: UUID(), content: defaultContent, date: Date())
            modelContext.insert(defaultEntry)
        }
    }
}

struct DiaryListView: View {
    @State private var isTapDisabled = false

    let entries: [DiaryEntry]
    let modelContext: ModelContext
    @EnvironmentObject var globalData: GlobalData
    @Binding var searchText: String
    var isSearchFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(entries.indices, id: \.self) { i in
                    let entry = entries[i]
                    
                    VStack(alignment: .leading, spacing: H_SCALE(5)) {
                        HStack(spacing: W_SCALE(10)) {
                            Text(formatDate(entry.date))
                                .font(.system(size: W_SCALE(16)))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .frame(alignment: .leading)
                                .multilineTextAlignment(.leading)
                            
                            Text("\(entry.emojiString)")
                                .font(.body)
                            Spacer()
                            
                            // 在这里加编号，格式化成三位数
                            Text(String(format: "%d", i + 1))
                                .font(.system(size: W_SCALE(16)))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }

                        Text(entry.content ?? "")
                            .multilineTextAlignment(.leading)
                            .foregroundColor(Color(UIColor.label))
                            .font(.system(size: W_SCALE(23)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        
                        Text(entry.location ?? "")
                            .font(.system(size: W_SCALE(16)))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .frame(height: Screen.height * 0.1)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.white)
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
            .listRowSpacing(H_SCALE(20))
            .listStyle(PlainListStyle())
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
                            .foregroundColor(.gray)
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
