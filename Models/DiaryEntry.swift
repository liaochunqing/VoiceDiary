//
//  DiaryEntry.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/28.
//

import Foundation
import SwiftUI

struct DiaryEntry: Identifiable, Codable {
    var id = UUID()                       // 唯一标识符
    var title: String                     // 日记标题
    var content: String                   // 日记内容
    var date: Date                        // 创建日期
    var image: Data?                      // 图片，存储为 Data 格式
    var tags: [String]                    // 日记标签
    var location: String?                 // 日记记录的位置信息
    var isFavorite: Bool                  // 是否为收藏
    
    // 初始化方法，可以根据需要初始化默认值
    init(title: String, content: String, date: Date = Date(), image: UIImage? = nil, tags: [String] = [], location: String? = nil, isFavorite: Bool = false) {
        self.title = title
        self.content = content
        self.date = date
        self.image = image?.jpegData(compressionQuality: 0.8) // 将UIImage转换为Data
        self.tags = tags
        self.location = location
        self.isFavorite = isFavorite
    }
    
    // 获取UIImage格式的图片
    func getImage() -> UIImage? {
        if let imageData = image {
            return UIImage(data: imageData)
        }
        return nil
    }
}
