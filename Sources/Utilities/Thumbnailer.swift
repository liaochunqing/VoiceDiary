import UIKit
import ImageIO

/// 缩略图降采样：用 ImageIO 按目标像素直接解出小图，避免把整张原图（动辄几十 MB 位图）
/// 解进内存只为画一个几十像素的小框。结果按内容指纹缓存，重复渲染不重复解码。
///
/// 仅用于「列表行 / 详情附件栏」这类小缩略图；全屏查看器仍用原图。
enum Thumbnailer {
    // NSCache 自身线程安全，但未标 Sendable；complete 并发检查下用 nonisolated(unsafe)。
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200          // 最多缓存 200 张缩略图，超出按 LRU 淘汰
        return c
    }()

    /// 取边长 `side`（点）的缩略图。按 @3x 上限解码，覆盖最高密度屏。
    static func thumbnail(_ data: Data, side: CGFloat) -> UIImage? {
        let maxPixel = max(1, side * 3)
        let key = cacheKey(data, maxPixel: maxPixel)
        if let hit = cache.object(forKey: key) { return hit }
        guard let img = downsample(data, maxPixel: maxPixel) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }

    static func clearCache() { cache.removeAllObjects() }

    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // 尊重 EXIF 方向
            kCGImageSourceShouldCacheImmediately: true,         // 立即解码，离开本函数即定型
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 内容指纹：count + 首尾各 64 字节 + 目标像素，O(1) 且能区分不同图。
    private static func cacheKey(_ data: Data, maxPixel: CGFloat) -> NSString {
        var hasher = Hasher()
        hasher.combine(data.count)
        hasher.combine(data.prefix(64))
        hasher.combine(data.suffix(64))
        hasher.combine(Int(maxPixel))
        return "\(hasher.finalize())" as NSString
    }
}
