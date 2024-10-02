//
//  mainListView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/17.
//

import Foundation

import SwiftUI
import Combine

struct mainListView: View {
    @StateObject var groupManager = GroupManager()

    @State private var selectedTab: Int = 0
    @Binding var offset: CGFloat  // 初始偏移量为负值，隐藏设置界面
    @Binding var startLocation:CGFloat // 手势起点
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(groupManager.groups.indices, id: \.self) { index in
                            Text(groupManager.groups[index].title)
                                .font(.headline)
                                .padding(10)
                                .cornerRadius(8)
                                .frame(minHeight: 30, maxHeight: 60) // 动态高度
                                .id(index)
                                .onTapGesture {
                                    withAnimation {
                                        selectedTab = index
                                        proxy.scrollTo(index, anchor: .center) // 点击时滚动到中间
                                    }
                                }
                                .overlay(
                                        Rectangle() // 底部的黑色横线
                                            .frame(height: 1) // 线的高度
                                            .foregroundColor(selectedTab == index ? Color.black : Color.clear) // 根据是否选中显示线
                                            .padding(.horizontal,12).padding(.top,-10), // 线与文字的间隔
                                        alignment: .bottom // 对齐到底部

                                    )
                        }
                    }
                }
                .padding(.horizontal)
                .onChange(of: selectedTab, { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center) // TabView 切换时滚动标题到中间
                    }
                })
            }      
//            .background(Color.gray.opacity(0.5))

            TabView(selection: $selectedTab) {
                ForEach(groupManager.groups.indices, id: \.self) { index in
                            VStack
                            {
                                DiaryListView(entries: [
                                    DiaryEntry(title: "今日记录", content: "今天是个好天气", tags: ["天气", "生活"]),
                                    DiaryEntry(title: "今日记录", content: "今天是个好天气", tags: ["天气", "生活"]),
                                    DiaryEntry(title: "今日记录", content: "今天是个好天气", tags: ["天气", "生活"]),
                                    DiaryEntry(title: "今日记录", content: "今天是个好天气", tags: ["天气", "生活"])
                                        ])
                    
                            }
//                            .background(Color.red)
                }
            }
            
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedTab) {oldValue,  newValue in
                // 当TabView切换时，上面的ScrollView也会滚动标题到中间
                withAnimation {
                    selectedTab = newValue
                }
            }
        }

    }
        
        
        

//        VStack
//        {
//            DiaryListView(entries: [
//                        DiaryEntry(date: Date(), content: "爱死机"),
//                        DiaryEntry(date: Date().addingTimeInterval(-86400 * 1), content: "日记，心情，备忘组件..."),
//                        DiaryEntry(date: Date().addingTimeInterval(-86400 * 2), content: "Places of interest\nroast duck..."),
//                        DiaryEntry(date: Date().addingTimeInterval(-86400 * 3), content: "幸福三要素\n1.选择的自由...")
//                    ])
//            
//        }
//        .background(Color(UIColor.secondarySystemBackground)) // 设置背景色
//        .gesture(
//            DragGesture()
//                .onChanged { value in
//                    // 当手势从屏幕左侧边缘开始，记录起点
//                    if startLocation == -1 {
//                        startLocation = value.startLocation.x
//                        print("++ \(startLocation)")
//                    }
//                    
//                    // 如果从左侧滑动，改变偏移量
//                    if startLocation < 15 && value.translation.width > 0 {
//                        offset = min(value.translation.width - UIScreen.main.bounds.width, 0)
//                        //                                print("==\(offset)")
//                    }
//                    
//                }
//                .onEnded { value in
//                    if startLocation < 15 {
//                        print("== \(startLocation)")
//                        
//                        // 当滑动超过一定距离时，显示设置界面
//                        if value.translation.width > 100 {
//                            withAnimation {
//                                offset = 0
//                            }
//                        } else {
//                            // 否则还原到初始位置
//                            withAnimation {
//                                offset = -UIScreen.main.bounds.width
//                            }
//                        }
//                    }
//                    
//                    // 重置起点
//                    startLocation = -1
//                }
//        )
}

struct DiaryListView: View {
    let entries: [DiaryEntry]
    
    var body: some View {
        List(entries, id: \.date) { entry in
            VStack(alignment: .leading) {
                Text(formatDate(entry.date))
                    .font(.system(size: W_SCALE(18)))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.leading)  // 左对齐
                
                Text(entry.content)
                    .multilineTextAlignment(.leading)  // 左对齐
                    .foregroundColor(Color(UIColor.label))
                    .font(.system(size: W_SCALE(23)))
                    .padding(.top, H_SCALE(5))
            }
            .frame(height: H_SCALE(90))
            .listRowSeparator(.hidden)  // 隐藏底部的横线
            .listRowBackground(Color.white)  // 每行的背景
        }
        .listRowSpacing(H_SCALE(20))
        .listStyle(PlainListStyle())  // 设置为 plain 样式
        .padding(.horizontal)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd  HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
