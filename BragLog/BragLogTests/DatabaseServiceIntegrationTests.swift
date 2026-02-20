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

    func testFreshDatabaseCreatesProjectTable() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let projects = try db.fetchAllProjects()
        XCTAssertEqual(projects.count, 0)
    }

    func testSaveEntryInsertsProject() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "Did a thing", tags: nil, project: "Alpha")
        let projects = try db.fetchAllProjects()
        XCTAssertEqual(projects.map(\.name), ["Alpha"])
    }

    func testNilProjectPersistsAsNull() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "No project", tags: nil, project: nil)
        try db.saveEntry(message: "Empty project", tags: nil, project: "")
        let projects = try db.fetchAllProjects()
        XCTAssertEqual(projects.count, 0)
        let raw = try db.fetchLastLogRawProject()
        XCTAssertNil(raw)
    }

    func testFetchAllProjectsReturnsSortedCaseInsensitive() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "M1", tags: nil, project: "Zebra")
        try db.saveEntry(message: "M2", tags: nil, project: "apple")
        try db.saveEntry(message: "M3", tags: nil, project: "Banana")
        let projects = try db.fetchAllProjects()
        XCTAssertEqual(projects.map(\.name), ["apple", "Banana", "Zebra"])
    }

    func testMultipleSavesDeduplicateProjects() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "First", tags: nil, project: "Alpha")
        try db.saveEntry(message: "Second", tags: nil, project: "Alpha")
        let projects = try db.fetchAllProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.name, "Alpha")
    }

    func testSaveEntryWithTagsAndProject() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "Both", tags: ["X", "Y"], project: "MyProject")
        let tags = try db.fetchAllTags()
        let projects = try db.fetchAllProjects()
        XCTAssertEqual(Set(tags.map(\.name)), ["X", "Y"])
        XCTAssertEqual(projects.map(\.name), ["MyProject"])
        XCTAssertEqual(try db.fetchLastLogRawTags(), "X,Y")
        XCTAssertEqual(try db.fetchLastLogRawProject(), "MyProject")
    }
}
