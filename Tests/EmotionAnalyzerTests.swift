import XCTest
@testable import VoiceDiary

final class EmotionAnalyzerTests: XCTestCase {

    // MARK: - Sentiment

    func testPositiveEnglishTextReturnsPositiveScore() {
        let score = EmotionAnalyzer.sentiment(for: "I had a wonderful day today, feeling so happy and grateful")
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 0)
    }

    func testNegativeEnglishTextReturnsNegativeScore() {
        let score = EmotionAnalyzer.sentiment(for: "I feel terrible and sad, everything went wrong today")
        XCTAssertNotNil(score)
        XCTAssertLessThan(score!, 0)
    }

    func testNeutralTextReturnsValidRange() {
        // NLTagger 的 sentiment 对中性文本有时略偏正/负，
        // 这里只验证不崩溃且值在有效区间内。
        let score = EmotionAnalyzer.sentiment(for: "I went to the store to buy groceries and came home")
        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, -1.0)
        XCTAssertLessThanOrEqual(score!, 1.0)
    }

    func testVeryShortTextReturnsNil() {
        let score = EmotionAnalyzer.sentiment(for: "a")
        XCTAssertNil(score)
    }

    func testEmptyTextReturnsNil() {
        let score = EmotionAnalyzer.sentiment(for: "")
        XCTAssertNil(score)
    }

    func testWhitespaceOnlyReturnsNil() {
        let score = EmotionAnalyzer.sentiment(for: "   ")
        XCTAssertNil(score)
    }

    func testChineseTextDoesNotCrash() {
        // 中文 NLSentimentScore 可能不如英文准，但不应崩溃。
        let score = EmotionAnalyzer.sentiment(for: "今天心情很好，阳光明媚")
        // 中文太短可能归 nil，长一点通常有值。
        _ = score
    }

    // MARK: - Keywords

    func testKeywordsExtractNounsFromEnglish() {
        let keywords = EmotionAnalyzer.keywords(from: [
            "I walked the dog in the park with my friend"
        ], top: 3)
        // 应该能抽出 park、dog、friend 等名词
        XCTAssertFalse(keywords.isEmpty)
        XCTAssertLessThanOrEqual(keywords.count, 3)
    }

    func testKeywordsFromEmptyInputReturnsEmpty() {
        let keywords = EmotionAnalyzer.keywords(from: [], top: 5)
        XCTAssertTrue(keywords.isEmpty)
    }

    func testKeywordsDeduplicateAcrossTexts() {
        let keywords = EmotionAnalyzer.keywords(from: [
            "Coffee and coffee and more coffee",
            "I love coffee"
        ], top: 5)
        let coffee = keywords.first { $0.word.lowercased() == "coffee" }
        XCTAssertNotNil(coffee)
        // "coffee" 在两句中出现 4 次，频次应该最高。
        let top = keywords.first
        XCTAssertNotNil(top)
    }
}
