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
    
    var body: some View {
        VStack(spacing: 16) {
            // 列表视图
            DiaryListView(entries: allEntries, modelContext: modelContext)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
        }
        .onChange(of: allEntries) {
            if !allEntries.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                    checkAndInsertDefaultEntry()
                }
            }
        }
    }

    // 插入默认日记
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
    
    var body: some View {
        List {
            ForEach(entries, id: \.id) { entry in
                VStack(alignment: .leading, spacing: H_SCALE(5)) { // 增加垂直间距控制
                    //时间
                    HStack (spacing: W_SCALE(10)){
                        Text(formatDate(entry.date))
                            .font(.system(size: W_SCALE(16))) // 缩小字号
                            .foregroundColor(Color(UIColor.secondaryLabel)) // 更浅的颜色
                            .frame(alignment: .leading) // 确保左对齐[5](@ref)
                            .multilineTextAlignment(.leading)
                        
                        Text("\(entry.emojiString)")
                            .font(.body)
                        Spacer()
                    }

                    //正文
                    Text(entry.content!)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color(UIColor.label))
                        .font(.system(size: W_SCALE(23)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    
                    //地点
                    Text(entry.location!)
                        .font(.system(size: W_SCALE(16))) // 缩小字号
                        .foregroundColor(Color(UIColor.secondaryLabel)) // 更浅的颜色
                        .frame(maxWidth: .infinity, alignment: .leading) // 确保左对齐[5](@ref)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // 容器整体对齐[3](@ref)
                .frame(height: Screen.height * 0.1) // 高度为屏幕高度的10%
                .listRowSeparator(.hidden)  // 隐藏底部的横线
                .listRowBackground(Color.white)  // 每行的背景
                .contentShape(Rectangle()) // 定义完整点击区域
                .onTapGesture {
                    guard !isTapDisabled else { return }

                    isTapDisabled = true
                
                    let index = globalData.getIndexOfPageBy(entry: entry, entries: entries)
                    
                    globalData.pageUpdate = true
                    globalData.currentIndex = index
                    globalData.moveToPage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTapDisabled = false
                    }
                }
            }
//            .onDelete(perform: deleteItem)

        }
        .listRowSpacing(H_SCALE(20))
        .listStyle(PlainListStyle())  // 设置为 plain 样式
    }
    
    func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            // 在此处处理要删除的记录实例，例如：
            modelContext.delete(entry)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(
                    // ✅ 创建专用于预览的内存存储容器
                    try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
