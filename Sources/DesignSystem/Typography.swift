import SwiftUI

/// 字号层级（对照设计稿）。统一从这里取，避免散落 magic number。
extension Font {
    static let dPageTitle = Font.system(size: 17, weight: .bold)   // 页面标题（日记 / 设置）
    static let dLargeDate = Font.system(size: 32, weight: .bold)   // 写日记页大日期
    static let dTitle     = Font.system(size: 20, weight: .bold)
    static let dBody      = Font.system(size: 16)                  // 正文
    static let dCallout   = Font.system(size: 15)
    static let dSubhead   = Font.system(size: 13)                  // 列表正文 / 次要
    static let dCaption   = Font.system(size: 11)                  // meta / 小字
    static let dMicro     = Font.system(size: 10, weight: .semibold)
}
