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

