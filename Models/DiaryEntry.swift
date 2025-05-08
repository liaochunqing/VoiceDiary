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
//    var timestamp: Date = Date() // 这里加个默认值 用于iCloud同步

    var id: UUID = UUID()  // 唯一标识符，默认生成新的 UUID
    var content: String? = ""                 // 日记内容，默认为空字符串
    var date: Date = Date()                   // 创建日期，默认为当前日期
    var location: String? = ""                // 日记记录的位置信息，默认为空字符串
    var isNew: Bool = false                   // 是否新建页，默认为否
    var emojiString: String = ""                // 日记心情
    var pageNumber: Int = -1                // 页码
    var showLocation: Bool = false                   // 是否显示地址
//    var fontColor: Color = .primary                   // 字体颜色
    var fontStyle: String = ""                   // 字体类型

    
    
    // 初始化方法
    init(id: UUID = UUID(),
         content: String? = "",
         date: Date = Date(),
         location: String? = "",
         isNew: Bool = false,
         emojiString:String = "",
         showLocation: Bool = false,
//         fontColor: Color ,
         fontStyle:String = ""
    )
    {
        self.id = id
        self.content = content
        self.date = date
        self.location = location
        self.isNew = isNew
        self.emojiString = emojiString
        self.showLocation = showLocation
//        self.fontColor = fontColor
        self.fontStyle = fontStyle
    }
}



class IdentifiedHostingController<Content: View>: UIHostingController<Content> {
    let id: UUID

    init(id: UUID, rootView: Content) {
        self.id = id
        super.init(rootView: rootView)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
