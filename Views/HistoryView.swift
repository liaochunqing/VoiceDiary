//
//  HistoryView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/2.
//

import Foundation
import SwiftUI

struct HistoryView: View {
    let events: [WikiEvent] // 传入的事件数组
        @Environment(\.dismiss) var dismiss // 用于关闭视图

        var body: some View {
            VStack {
                Text("事件详情")
                    .font(.title)
                    .padding()
                
                List(events, id: \.year) { event in
                                Text("*\(event.year)  \(event.text)")
                                    .padding()
                            }
                
                Spacer()
                
                Button("关闭") {
                    dismiss() // 关闭当前视图
                }
                .padding()
            }
        }
}


// 定义历史事件的数据结构
//struct WikiEvent: Codable {
//    let text: String
//    let year: Int
//}
struct WikiEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var year: Int
    var text: String
}
// 响应的数据结构
struct WikiResponse: Codable {
    let events: [WikiEvent]
}
// 获取系统语言的函数
func getSystemLanguage() -> String {
    if #available(iOS 16.0, *) {
        // iOS 16 及以上版本
        return Locale.current.language.languageCode?.identifier ?? "en"
    } else {
        // iOS 15 及以下版本
        return Locale.current.languageCode ?? "en"
    }
}

// 函数：从数组中随机选择 n 个元素，且保持原数组的顺序
func selectRandomElements<T>(from array: [T], count n: Int) -> [T] {
    guard n <= array.count else {
        // 如果需要的数量大于数组的大小，返回整个数组
        return array
    }
    
    // 生成一个随机的不重复索引数组
    var randomIndexes: Set<Int> = []
    while randomIndexes.count < n {
        randomIndexes.insert(Int.random(in: 0..<array.count))
    }

    // 将索引排序，以确保选出的元素保持原数组的顺序
    let sortedIndexes = randomIndexes.sorted()

    // 按照排序后的索引选出对应的元素
    return sortedIndexes.map { array[$0] }
}

func fetchWikiEvents(completion: @escaping ([WikiEvent]) -> Void) {
    let language = getSystemLanguage()
    let currentDate = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MM/dd"
    let dateString = dateFormatter.string(from: currentDate)
    
    let urlString = "https://api.wikimedia.org/feed/v1/wikipedia/\(language)/onthisday/events/\(dateString)"
    guard let url = URL(string: urlString) else { return }
        
    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, error == nil else { return }

        let decoder = JSONDecoder()
        if let wikiResponse = try? decoder.decode(WikiResponse.self, from: data) {
            DispatchQueue.main.async {
                let events = wikiResponse.events.map { WikiEvent(year: $0.year, text: $0.text) }
            
                let shuffledEvents = selectRandomElements(from: events, count: 10)
                completion(shuffledEvents) // 10个事件
            }
        }
    }.resume()
}



struct optionButtonView: View {
    
//    @State private var showSettingsView = false
    
    var body: some View {
        HStack
        {
            Button{
                
            }  label: {
                Image(systemName: "list.bullet") // 添加系统图片
                    .font(.system(size: 25))
                    .foregroundColor(.black)
                    .shadow(color: .gray, radius: 10,x: 0,y: 10)
            }

            Spacer()
        }
        .padding()
    }
}

struct HistoryTodayView: View {
    @State private var currentEvent: WikiEvent? = nil
    @State private var events: [WikiEvent] = [] // 缓存所有历史事件
    @State private var timer: Timer? = nil
    @State private var showDetailView = false // 控制是否显示详情页
    @Namespace private var animationNamespace // 用于动画

    var body: some View {
        VStack {
            if let event = currentEvent {
                Text("\(String(event.year))   \(event.text)")
                    .font(.system(size: 16))
                    .lineLimit(2) // 限制为两行
                    .fixedSize(horizontal: false, vertical: true) // 垂直方向自适应大小
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 70) // 固定高度
                    .onTapGesture {
                        showDetailView = true // 点击时显示详情页
                    }
                    .transition(.opacity) // 使用渐隐渐显动画
                    .animation(.easeInOut(duration: 0.5), value: currentEvent) // 添加动画
            } else {
                Text("加载中...")
                    .font(.system(size: 16))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 70) // 同样固定为两行高度
            }
        }
        .fullScreenCover(isPresented: $showDetailView) { // 弹出详情页
            HistoryView(events: events)
        }
        .onAppear {
            if events.isEmpty {
                fetchEventsAndStartAutoUpdate()
            } else {
                startAutoUpdate()
            }
        }
    }
    
    // 获取事件并开始自动更新
    private func fetchEventsAndStartAutoUpdate() {
        fetchWikiEvents { fetchedEvents in
            events = fetchedEvents
            currentEvent = events.first
            startAutoUpdate()  // 启动自动更新
        }
    }
    
    // 启动定时器，每5秒更新一次事件
    private func startAutoUpdate() {
        timer?.invalidate() // 确保不会重复创建定时器
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if !events.isEmpty {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentEvent = events.randomElement()  // 随机选择一条事件并添加动画
                }
            }
        }
    }
    
    // 当视图销毁时，停止定时器
    private func stopAutoUpdate() {
        timer?.invalidate()
        timer = nil
    }
}

