//
//  TagFilteringTests.swift
//  BragLogTests
//

import XCTest
@testable import BragLog

final class TagFilteringTests: XCTestCase {

    func testCaseInsensitiveSubstringFilter() {
        let tags = [Tag(name: "Audit"), Tag(name: "BA"), Tag(name: "Code Review"), Tag(name: "Brag")]
        let filtered = tags.map(\.name).filter { $0.localizedCaseInsensitiveContains("ba") }
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first, "BA")
    }

    func testFilterExcludesAlreadySelected() {
        let all = ["A", "B", "C"]
        let selected = Set(["A"].map { $0.lowercased() })
        let available = all.filter { !selected.contains($0.lowercased()) }
        XCTAssertEqual(available, ["B", "C"])
    }
}
