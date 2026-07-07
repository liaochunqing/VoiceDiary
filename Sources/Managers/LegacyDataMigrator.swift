import Foundation
import SwiftData

/// 从旧版「翻页日记」数据库恢复日记。
///
/// 旧版先后使用过 `VoiceDiaryModel.store` 和 `default.store`，新版改为
/// `Main.store`，因此系统升级不会自动把旧数据带到新库。迁移器始终在旧库
/// 的临时副本上做 SwiftData 轻量迁移，再把缺失 UUID 的日记插入新库：
/// 不覆盖新数据、不删除旧库，并且可以安全重试。
@MainActor
struct LegacyDataMigrator {
    struct Report: Equatable {
        var importedCount = 0
        var duplicateCount = 0
        var failedStoreNames: [String] = []
    }

    private struct Snapshot {
        let id: UUID
        let content: String
        let date: Date
        let location: String
        let showLocation: Bool
        let emoji: String
        let pageNumber: Int
        let fontName: String
        let fontSize: Double
        let fontColorHex: String
    }

    private static let migrationVersion = 1

    private let legacyStoreURLs: [URL]
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let temporaryRootURL: URL

    init(
        applicationSupportURL: URL? = nil,
        legacyStoreURLs: [URL]? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        temporaryRootURL: URL? = nil
    ) {
        let supportURL = applicationSupportURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        self.legacyStoreURLs = legacyStoreURLs ?? [
            supportURL.appendingPathComponent("default.store"),
            supportURL.appendingPathComponent("VoiceDiaryModel.store")
        ]
        self.defaults = defaults
        self.fileManager = fileManager
        self.temporaryRootURL = temporaryRootURL ?? fileManager.temporaryDirectory
    }

    func migrateIfNeeded(into destination: ModelContainer) -> Report {
        var report = Report()
        let destinationContext = destination.mainContext

        let existingEntries: [DiaryEntry]
        do {
            existingEntries = try destinationContext.fetch(FetchDescriptor<DiaryEntry>())
        } catch {
            report.failedStoreNames = legacyStoreURLs.map(\.lastPathComponent)
            return report
        }
        var knownIDs = Set(existingEntries.map(\.id))

        for sourceURL in legacyStoreURLs where fileManager.fileExists(atPath: sourceURL.path) {
            let marker = migrationMarker(for: sourceURL)
            guard !defaults.bool(forKey: marker) else { continue }

            do {
                let snapshots = try readSnapshots(fromCopyOf: sourceURL)
                var insertedCount = 0

                for snapshot in snapshots {
                    guard knownIDs.insert(snapshot.id).inserted else {
                        report.duplicateCount += 1
                        continue
                    }

                    let entry = DiaryEntry(
                        content: snapshot.content,
                        date: snapshot.date,
                        location: snapshot.location,
                        showLocation: snapshot.showLocation,
                        emoji: snapshot.emoji
                    )
                    entry.id = snapshot.id
                    entry.pageNumber = snapshot.pageNumber
                    entry.fontName = snapshot.fontName
                    entry.fontSize = snapshot.fontSize
                    entry.fontColorHex = snapshot.fontColorHex
                    destinationContext.insert(entry)
                    insertedCount += 1
                }

                if destinationContext.hasChanges {
                    try destinationContext.save()
                }
                report.importedCount += insertedCount
                defaults.set(true, forKey: marker)
            } catch {
                destinationContext.rollback()
                // rollback 后本轮加入 knownIDs 的值也要撤销，避免后续旧库被误判为重复。
                knownIDs = Set((try? destinationContext.fetch(FetchDescriptor<DiaryEntry>()))?.map(\.id) ?? [])
                report.failedStoreNames.append(sourceURL.lastPathComponent)
                #if DEBUG
                print("[LegacyDataMigrator] Failed to import \(sourceURL.lastPathComponent): \(error)")
                #endif
            }
        }

        return report
    }

    private func readSnapshots(fromCopyOf sourceURL: URL) throws -> [Snapshot] {
        let copyDirectory = temporaryRootURL
            .appendingPathComponent("VoiceDiaryLegacyMigration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: copyDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: copyDirectory) }

        let copiedStoreURL = copyDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        try copyStoreFamily(from: sourceURL, to: copiedStoreURL)

        let schema = Schema([DiaryEntry.self, VoiceMemo.self])
        let configuration = ModelConfiguration(
            "LegacyImport",
            schema: schema,
            url: copiedStoreURL,
            cloudKitDatabase: .none
        )
        let legacyContainer = try ModelContainer(for: schema, configurations: [configuration])
        let entries = try legacyContainer.mainContext.fetch(FetchDescriptor<DiaryEntry>())

        return entries.map {
            Snapshot(
                id: $0.id,
                content: $0.content,
                date: $0.date,
                location: $0.location,
                showLocation: $0.showLocation,
                emoji: $0.emoji,
                pageNumber: $0.pageNumber,
                fontName: $0.fontName,
                fontSize: $0.fontSize,
                fontColorHex: $0.fontColorHex
            )
        }
    }

    private func copyStoreFamily(from sourceURL: URL, to destinationURL: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: sourceURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: destinationURL.path + suffix)
            try fileManager.copyItem(at: source, to: destination)
        }

        // SwiftData 的 externalStorage 文件位于隐藏的 .<store>_SUPPORT 目录。
        let sourceSupport = sourceURL.deletingLastPathComponent()
            .appendingPathComponent(".\(sourceURL.lastPathComponent)_SUPPORT", isDirectory: true)
        if fileManager.fileExists(atPath: sourceSupport.path) {
            let destinationSupport = destinationURL.deletingLastPathComponent()
                .appendingPathComponent(".\(destinationURL.lastPathComponent)_SUPPORT", isDirectory: true)
            try fileManager.copyItem(at: sourceSupport, to: destinationSupport)
        }
    }

    private func migrationMarker(for sourceURL: URL) -> String {
        "legacyDataMigration.v\(Self.migrationVersion).\(sourceURL.lastPathComponent)"
    }
}
