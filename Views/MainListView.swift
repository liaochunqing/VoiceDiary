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
    @State private var selectedTab: Int = 0
//    @Binding var offset: CGFloat  // 初始偏移量为负值，隐藏设置界面
//    @Binding var startLocation:CGFloat // 手势起点
    @Environment(\.modelContext) private var modelContext
    @Query(sort:\DiaryEntry.date, order: .reverse) private var diaryEntries: [DiaryEntry]

    
//    let defaultTitle = "欢迎使用日记 App"
    let defaultContent = "这是一条默认的日记，你可以添加更多日记。"

    var body: some View {
        VStack {
            TabView(selection: $selectedTab) {
                VStack
                {
                    DiaryListView(entries: diaryEntries,
                                  modelContext: modelContext)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedTab) {oldValue,  newValue in
                // 当TabView切换时，上面的ScrollView也会滚动标题到中间
                withAnimation {
                    selectedTab = newValue
                }
            }
//            .gesture(DragGesture()
//                            .onChanged { value in
//                                let threshold: CGFloat = -22 // 自定义滑动阈值，判断为超出右边界
//                                if value.translation.width < threshold
//                                {
//                                    withAnimation(.easeIn)
//                                    {
//                                        rotationAngle = -90 // 增加旋转角度
//                                    }
//                                }
//                            }
//                    )
        }
        .onAppear()
        {
            checkAndInsertDefaultEntry()
//            print("checkAndInsertDefaultEntry")
        }
    }
    
    
    // **检查数据库中是否有默认日记，如果没有就插入**
    private func checkAndInsertDefaultEntry()
    {
        let hasDefaultEntry = diaryEntries.contains
                                {
                                    $0.content == defaultContent
                                }
//        print(hasDefaultEntry)

        if !hasDefaultEntry
        {
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
                        
                        Text("\(entry.selectedMood)")
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
                .onTapGesture
                {
                    guard !isTapDisabled else { return }
                    
                    isTapDisabled = true
                    let currentIndex = entries.firstIndex(where: { $0.id == entry.id }) ?? 0
                                    
                    DispatchQueue.main.async
                    {
                        if globalData.targetPageIndex == -1{
                            globalData.targetPageIndex = currentIndex + 3 // 触发跳转
                        }
//                        print("page:\(globalData.targetPageIndex)")
                    }
                    
                    // 在0.5秒后重新启用点击手势
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
