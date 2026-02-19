//
//  DatabaseServiceIntegrationTests.swift
//  BragLogTests
//

import XCTest
@testable import BragLog

final class DatabaseServiceIntegrationTests: XCTestCase {

    func testFreshDatabaseRunsMigrationAndCreatesTables() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let tags = try db.fetchAllTags()
        XCTAssertEqual(tags.count, 0)
    }

    func testSaveEntryInsertsLogAndTags() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "Did a thing", tags: ["Audit", "BA"])
        let tags = try db.fetchAllTags()
        XCTAssertEqual(tags.map(\.name).sorted(), ["Audit", "BA"])
    }

    func testEmptyTagsPersistAsNull() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "No tags", tags: nil)
        try db.saveEntry(message: "Empty tags", tags: [])
        let tags = try db.fetchAllTags()
        XCTAssertEqual(tags.count, 0)
    }

    func testFetchAllTagsReturnsSortedCaseInsensitive() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "M1", tags: ["Zebra", "apple", "Banana"])
        let tags = try db.fetchAllTags()
        XCTAssertEqual(tags.map(\.name), ["apple", "Banana", "Zebra"])
    }

    func testMultipleSavesPreserveConsistencyAndAvoidDuplicateTags() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "First", tags: ["Code", "Review"])
        try db.saveEntry(message: "Second", tags: ["Code", "Audit"])
        let tags = try db.fetchAllTags()
        XCTAssertEqual(Set(tags.map(\.name)), ["Code", "Review", "Audit"])
        XCTAssertEqual(tags.count, 3)
    }
}
