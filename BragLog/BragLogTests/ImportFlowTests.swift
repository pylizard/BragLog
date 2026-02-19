//
//  ImportFlowTests.swift
//  BragLogTests
//

import XCTest
@testable import BragLog

final class ImportFlowTests: XCTestCase {

    func testBackupNamingFormat() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let date = Date(timeIntervalSince1970: 1234567890)
        let str = formatter.string(from: date)
        XCTAssertTrue(str.hasPrefix("2009"))
        XCTAssertTrue(str.contains("-"))
    }

    func testImportReplacesAndReloads() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let dbPath = tempDir.appendingPathComponent("log.db").path
        let db1 = try DatabaseService(dbPath: dbPath)
        try db1.saveEntry(message: "Original", tags: ["X"])
        db1.close()
        let importPath = tempDir.appendingPathComponent("import.db").path
        let db2 = try DatabaseService(dbPath: importPath)
        try db2.saveEntry(message: "Imported", tags: ["Y"])
        db2.close()
        try DatabaseService(dbPath: dbPath).importDatabase(from: URL(fileURLWithPath: importPath))
        let db3 = try DatabaseService(dbPath: dbPath)
        let tags = try db3.fetchAllTags()
        XCTAssertEqual(Set(tags.map(\.name)), ["Y"])
    }
}
