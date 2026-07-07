import XCTest
import SwiftData
@testable import VoiceDiary

@MainActor
final class LegacyDataMigratorTests: XCTestCase {
    private var rootURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyDataMigratorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        defaultsSuiteName = "LegacyDataMigratorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: rootURL)
        defaults = nil
        defaultsSuiteName = nil
        rootURL = nil
        try super.tearDownWithError()
    }

    func testMigrationImportsMissingEntriesWithoutOverwritingCurrentEntry() throws {
        let legacyURL = rootURL.appendingPathComponent("default.store")
        let existingID = UUID()
        let restoredID = UUID()

        try writeStore(at: legacyURL) { context in
            let duplicate = DiaryEntry(content: "旧库内容不应覆盖新版", date: Date(timeIntervalSince1970: 10))
            duplicate.id = existingID
            context.insert(duplicate)

            let restored = DiaryEntry(
                content: "需要恢复的旧日记",
                date: Date(timeIntervalSince1970: 20),
                location: "上海",
                showLocation: true,
                emoji: "😊"
            )
            restored.id = restoredID
            restored.pageNumber = 8
            restored.fontName = "LongCang-Regular"
            restored.fontSize = 22
            restored.fontColorHex = "#112233"
            context.insert(restored)
        }
        let sourceBeforeMigration = try Data(contentsOf: legacyURL)

        let destination = try makeContainer(at: rootURL.appendingPathComponent("Main.store"))
        let current = DiaryEntry(content: "新版内容必须保留", date: Date(timeIntervalSince1970: 30))
        current.id = existingID
        destination.mainContext.insert(current)
        try destination.mainContext.save()

        let report = makeMigrator(legacyURL: legacyURL).migrateIfNeeded(into: destination)

        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertTrue(report.failedStoreNames.isEmpty)

        let entries = try destination.mainContext.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first(where: { $0.id == existingID })?.content, "新版内容必须保留")

        let restored = try XCTUnwrap(entries.first(where: { $0.id == restoredID }))
        XCTAssertEqual(restored.content, "需要恢复的旧日记")
        XCTAssertEqual(restored.location, "上海")
        XCTAssertTrue(restored.showLocation)
        XCTAssertEqual(restored.emoji, "😊")
        XCTAssertEqual(restored.pageNumber, 8)
        XCTAssertEqual(restored.fontName, "LongCang-Regular")
        XCTAssertEqual(restored.fontSize, 22)
        XCTAssertEqual(restored.fontColorHex, "#112233")

        // 迁移只读取副本，原始旧库字节不应发生变化。
        XCTAssertEqual(try Data(contentsOf: legacyURL), sourceBeforeMigration)
    }

    func testMigrationRunsOnlyOnceAndDoesNotDuplicateEntries() throws {
        let legacyURL = rootURL.appendingPathComponent("default.store")
        try writeStore(at: legacyURL) { context in
            context.insert(DiaryEntry(content: "只恢复一次"))
        }
        let destination = try makeContainer(at: rootURL.appendingPathComponent("Main.store"))
        let migrator = makeMigrator(legacyURL: legacyURL)

        let firstReport = migrator.migrateIfNeeded(into: destination)
        let secondReport = migrator.migrateIfNeeded(into: destination)

        XCTAssertEqual(firstReport.importedCount, 1)
        XCTAssertEqual(secondReport.importedCount, 0)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()), 1)
    }

    func testCorruptLegacyStoreLeavesCurrentDataUntouchedAndCanRetry() throws {
        let legacyURL = rootURL.appendingPathComponent("default.store")
        try Data("not a sqlite store".utf8).write(to: legacyURL)

        let destination = try makeContainer(at: rootURL.appendingPathComponent("Main.store"))
        destination.mainContext.insert(DiaryEntry(content: "现有新版日记"))
        try destination.mainContext.save()
        let migrator = makeMigrator(legacyURL: legacyURL)

        let firstReport = migrator.migrateIfNeeded(into: destination)
        let secondReport = migrator.migrateIfNeeded(into: destination)

        XCTAssertEqual(firstReport.failedStoreNames, ["default.store"])
        XCTAssertEqual(secondReport.failedStoreNames, ["default.store"], "失败后不能写完成标记，应允许重试")
        let entries = try destination.mainContext.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(entries.map(\.content), ["现有新版日记"])
    }

    func testMissingLegacyStoreDoesNothing() throws {
        let missingURL = rootURL.appendingPathComponent("missing.store")
        let destination = try makeContainer(at: rootURL.appendingPathComponent("Main.store"))

        let report = makeMigrator(legacyURL: missingURL).migrateIfNeeded(into: destination)

        XCTAssertEqual(report, LegacyDataMigrator.Report())
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()), 0)
    }

    private func makeMigrator(legacyURL: URL) -> LegacyDataMigrator {
        LegacyDataMigrator(
            legacyStoreURLs: [legacyURL],
            defaults: defaults,
            temporaryRootURL: rootURL
        )
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([DiaryEntry.self, VoiceMemo.self])
        let configuration = ModelConfiguration(
            "MigrationTest-\(UUID().uuidString)",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func writeStore(at url: URL, populate: (ModelContext) throws -> Void) throws {
        var container: ModelContainer? = try makeContainer(at: url)
        let context = try XCTUnwrap(container?.mainContext)
        try populate(context)
        try context.save()
        container = nil
    }
}
