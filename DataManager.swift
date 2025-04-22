import SwiftData
import Foundation

enum TimeRange {
    case month
    case year
    case all
}
struct DataManager {
    
    // MARK: - Create
    static func add(_ entry: DiaryEntry, in context: ModelContext) {
        context.insert(entry)
        try? context.save()
    }
    
    // MARK: - Delete
    static func delete(_ entry: DiaryEntry, from context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    // MARK: - Update
    static func update(in context: ModelContext) {
        // SwiftData 自动追踪变更，只需保存上下文
        try? context.save()
    }

    // MARK: - Fetch All
    static func fetchAll(in context: ModelContext, sortBy: [SortDescriptor<DiaryEntry>] = []) -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(sortBy: sortBy)
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Fetch By Predicate
    static func fetch(in context: ModelContext, predicate: Predicate<DiaryEntry>) -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Fetch Single by ID
    static func fetchByID(_ id: UUID, in context: ModelContext) -> DiaryEntry? {
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
    
    // MARK: -获取表情集合
    static func fetchEmojis(for range: TimeRange, in context: ModelContext) -> [String] {
            let calendar = Calendar.current
            let now = Date()
            var predicate: Predicate<DiaryEntry>? = nil

            switch range {
            case .month:
                if let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                   let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) {
                    predicate = #Predicate { entry in
                        entry.date >= startOfMonth && entry.date <= endOfMonth
                    }
                }
            case .year:
                if let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                   let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear) {
                    predicate = #Predicate { entry in
                        entry.date >= startOfYear && entry.date <= endOfYear
                    }
                }
            case .all:
                predicate = nil
            }

            let descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)
            let entries = (try? context.fetch(descriptor)) ?? []
        return entries.map { $0.emojiString }.filter { !$0.isEmpty }
            
        }
}
