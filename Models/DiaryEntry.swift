//
//  DiaryEntry.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/28.
//

import Foundation
import SwiftUI
import SwiftData

@Model

class DiaryEntry {
    @Attribute(.unique) var id: UUID = UUID()  // 唯一标识符，默认生成新的 UUID
//    var title: String? = ""                   // 日记标题，默认为空字符串
    var content: String? = ""                 // 日记内容，默认为空字符串
    var date: Date = Date()                   // 创建日期，默认为当前日期
    var location: String? = ""                // 日记记录的位置信息，默认为空字符串
    var isNew: Bool = false                   // 是否新建页，默认为否

    // 初始化方法
    init(id: UUID = UUID(),
//         title: String? = "",
         content: String? = "",
         date: Date = Date(),
         location: String? = "",
         isNew: Bool = false)
    {
        self.id = id
//        self.title = title
        self.content = content
        self.date = date
        self.location = location
        self.isNew = isNew
    }
}
