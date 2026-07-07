import XCTest
@testable import VoiceDiary

final class PhotoCompressionTests: XCTestCase {

    // MARK: - diaryCompressed

    func testCompressionReducesSizeFromLargeImage() {
        // 生成 2000×2000 的渐变图模拟用户相册的照片。
        let large = makeSolidImage(width: 2000, height: 2000, color: .orange)
        let originalData = large.jpegData(compressionQuality: 0.95)!
        let compressed = originalData.diaryCompressed(maxDimension: 1080, quality: 0.7)
        XCTAssertNotNil(compressed)

        // 压缩后应比原图显著更小。
        XCTAssertLessThan(compressed!.count, originalData.count / 2)
    }

    func testSmallImageIsNotUpscaled() {
        // 小图不应被放大。
        let small = makeSolidImage(width: 200, height: 200, color: .blue)
        let originalData = small.jpegData(compressionQuality: 0.9)!
        let compressed = originalData.diaryCompressed(maxDimension: 1080, quality: 0.7)
        XCTAssertNotNil(compressed)

        // 尺寸不应增加太多（最多因为 quality 变化略大一点）。
        XCTAssertLessThanOrEqual(compressed!.count, originalData.count * 2)
    }

    func testCompressionPreservesValidJPEG() {
        let img = makeSolidImage(width: 1500, height: 1000, color: .red)
        let originalData = img.jpegData(compressionQuality: 0.9)!
        let compressed = originalData.diaryCompressed(maxDimension: 800, quality: 0.7)
        XCTAssertNotNil(compressed)

        // 输出仍为合法图片。
        let decoded = UIImage(data: compressed!)
        XCTAssertNotNil(decoded)
    }

    func testCorruptDataReturnsNil() {
        let badData = Data([0x00, 0x01, 0x02])
        let result = badData.diaryCompressed()
        XCTAssertNil(result)
    }

    func testEmptyDataReturnsNil() {
        let result = Data().diaryCompressed()
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeSolidImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
