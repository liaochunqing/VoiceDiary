import Foundation
import NaturalLanguage

/// 端侧情绪 / 关键词分析。全部用 Apple NaturalLanguage，离线运行，内容不出设备。
/// 英语支持最好（贴合海外定位），中文亦可用。
enum EmotionAnalyzer {

    /// 单篇文本情绪分：-1.0（低落）… +1.0（明亮）。文本太短返回 nil。
    static func sentiment(for text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return nil }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = t
        let (tag, _) = tagger.tag(at: t.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let raw = tag?.rawValue, let v = Double(raw) else { return nil }
        return v
    }

    /// 一篇日记的可分析文本：正文 + 所有语音转写拼接。
    static func text(of entry: DiaryEntry) -> String {
        var parts = [entry.content]
        parts.append(contentsOf: entry.memos.map(\.transcript))
        return parts.joined(separator: "\n")
    }

    /// 关键词：只抽**名词**，按出现频次取 top N。仅用于本机展示，不上传。
    /// 关键：显式设定主语言（中文分词/词性才准），并丢弃 `.otherWord` 这个易混入噪声的词类。
    static func keywords(from texts: [String], top: Int = 8) -> [Keyword] {
        var freq: [String: Int] = [:]
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        let opts: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]
        for text in texts where !text.isEmpty {
            tagger.string = text
            let range = text.startIndex..<text.endIndex
            // 设主语言，CJK 才能正确分词；不设的话中文会被乱切、混出无意义词。
            if let lang = NLLanguageRecognizer.dominantLanguage(for: text) {
                tagger.setLanguage(lang, range: range)
            }
            tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: opts) { tag, r in
                guard tag == .noun else { return true }   // 只要名词，丢掉 otherWord 垃圾桶
                let w = String(text[r]).lowercased()
                if w.count >= 2, !w.allSatisfy(\.isNumber), !stopwords.contains(w) {
                    freq[w, default: 0] += 1
                }
                return true
            }
        }
        return freq
            .sorted { $0.value > $1.value }
            .prefix(top)
            .map { Keyword(word: $0.key, count: $0.value) }
    }

    /// 高频但无信息量的词，过滤掉避免污染关键词云。
    private static let stopwords: Set<String> = [
        // 英文功能词 / 泛词
        "today", "day", "time", "thing", "things", "something", "someone",
        "people", "way", "lot", "bit", "kind", "sort", "stuff",
        // 中文泛词
        "今天", "时候", "事情", "东西", "人们", "什么", "自己", "地方", "感觉",
    ]

    struct Keyword: Identifiable, Hashable {
        let word: String
        let count: Int
        var id: String { word }
    }
}
