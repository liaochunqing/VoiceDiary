import CoreGraphics

/// 统一间距与圆角 token（固定 pt，不再按机型等比缩放）。
enum Metric {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cardRadius: CGFloat = 14
    static let pillRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 14
    static let thumbRadius: CGFloat = 8
}
