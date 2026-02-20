//
//  ProjectFilteringTests.swift
//  BragLogTests
//

import XCTest
@testable import BragLog

final class ProjectFilteringTests: XCTestCase {

    func testCaseInsensitiveSubstringFilter() {
        let projects = [Project(name: "Alpha"), Project(name: "Beta"), Project(name: "alphabet")]
        let filtered = projects.map(\.name).filter { $0.localizedCaseInsensitiveContains("alph") }
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains("Alpha"))
        XCTAssertTrue(filtered.contains("alphabet"))
    }

    func testFilterExcludesSelectedProject() {
        let all = ["A", "B", "C"]
        let selectedProject = "A"
        let available = all.filter { $0.caseInsensitiveCompare(selectedProject) != .orderedSame }
        XCTAssertEqual(available, ["B", "C"])
    }
}
