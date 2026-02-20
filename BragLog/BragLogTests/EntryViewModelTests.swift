//
//  EntryViewModelTests.swift
//  BragLogTests
//

import XCTest
@testable import BragLog

@MainActor
final class EntryViewModelTests: XCTestCase {

    func testCanSaveIsFalseWhenMessageEmpty() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = "   "
        XCTAssertFalse(vm.canSave)
    }

    func testCanSaveIsFalseWhenMessageOnlyWhitespace() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = "\t\n"
        XCTAssertFalse(vm.canSave)
    }

    func testCanSaveIsTrueWhenMessageHasContent() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = "  hello  "
        XCTAssertTrue(vm.canSave)
    }

    func testSaveClearsMessageAndTagsAndSetsCloseFlag() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = "Test entry"
        vm.selectedTags = ["A", "B"]
        vm.selectedProject = "MyProject"
        vm.save()
        XCTAssertEqual(vm.message, "")
        XCTAssertEqual(vm.selectedTags, [])
        XCTAssertNil(vm.selectedProject)
        XCTAssertTrue(vm.shouldClosePopover)
    }

    func testSaveWithEmptyMessageDoesNotClose() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = ""
        vm.save()
        XCTAssertFalse(vm.shouldClosePopover)
    }

    func testTagJoinFormatIsCommaSeparated() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        try db.saveEntry(message: "X", tags: ["A", "B", "C"])
        let rawTags = try db.fetchLastLogRawTags()
        XCTAssertEqual(rawTags, "A,B,C")
    }

    func testSaveFailurePreservesStateAndSurfacesError() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        db.close()
        let vm = EntryViewModel(database: db)
        vm.message = "Should persist"
        vm.selectedTags = ["Tag1"]
        vm.selectedProject = "Proj"
        vm.save()
        XCTAssertEqual(vm.message, "Should persist")
        XCTAssertEqual(vm.selectedTags, ["Tag1"])
        XCTAssertEqual(vm.selectedProject, "Proj")
        XCTAssertFalse(vm.shouldClosePopover)
        XCTAssertNotNil(vm.saveError)
    }

    func testProjectPersistedInLog() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = "With project"
        vm.selectedProject = "MyProject"
        vm.save()
        let raw = try db.fetchLastLogRawProject()
        XCTAssertEqual(raw, "MyProject")
    }

    func testSaveWithNilProjectStoresNull() throws {
        let db = try DatabaseService(dbPath: ":memory:")
        let vm = EntryViewModel(database: db)
        vm.message = "No project"
        vm.save()
        let raw = try db.fetchLastLogRawProject()
        XCTAssertNil(raw)
    }
}
