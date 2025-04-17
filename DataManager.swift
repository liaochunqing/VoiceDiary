//
//  DataManager.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/4/17.
//

import SwiftData
import Foundation

struct DataManager {
    
    // MARK: - Create
    static func add<T: PersistentModel>(_ model: T, in context: ModelContext) {
        context.insert(model)
        try? context.save()
    }
    
    // MARK: - Delete
    static func delete<T: PersistentModel>(_ model: T, from context: ModelContext) {
        context.delete(model)
        try? context.save()
    }

    // MARK: - Update
    static func update(in context: ModelContext) {
        // SwiftData 自动追踪变更，只需保存上下文
        try? context.save()
    }

    // MARK: - Fetch All
    static func fetchAll<T: PersistentModel>(
        ofType type: T.Type,
        in context: ModelContext,
        sortBy: [SortDescriptor<T>] = []
    ) -> [T] {
        let descriptor = FetchDescriptor<T>(sortBy: sortBy)
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Fetch By Predicate
    static func fetch<T: PersistentModel>(
        ofType type: T.Type,
        in context: ModelContext,
        predicate: Predicate<T>
    ) -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Fetch Single by ID
    static func fetchByID(_ id: UUID, in context: ModelContext) -> DiaryEntry? {
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.id == id
            }
        )
        return try? context.fetch(descriptor).first
    }
}
