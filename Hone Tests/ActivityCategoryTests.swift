//
//  ActivityCategoryTests.swift
//  Practice Timer Tests
//
//  Created by Claude on 3/3/26.
//

import XCTest
@testable import Hone

final class ActivityCategoryTests: XCTestCase {

    // MARK: - Test Cases

    func testAllCasesCount() {
        XCTAssertEqual(ActivityCategory.allCases.count, 6, "Should have exactly 6 categories")
    }

    func testRawValues() {
        XCTAssertEqual(ActivityCategory.instrument.rawValue, "Instrument")
        XCTAssertEqual(ActivityCategory.piece.rawValue, "Piece")
        XCTAssertEqual(ActivityCategory.technique.rawValue, "Technique")
        XCTAssertEqual(ActivityCategory.theory.rawValue, "Theory")
        XCTAssertEqual(ActivityCategory.warmup.rawValue, "Warm-up")
        XCTAssertEqual(ActivityCategory.other.rawValue, "Other")
    }

    func testCodableEncodeDecode() throws {
        // Test encoding
        let category = ActivityCategory.technique
        let encoder = JSONEncoder()
        let data = try encoder.encode(category)

        // Verify it encodes as a string
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"Technique\"", "Should encode as JSON string")

        // Test decoding
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(ActivityCategory.self, from: data)
        XCTAssertEqual(decodedCategory, category, "Should decode back to original value")
    }

    func testIdentifiable() {
        let category = ActivityCategory.warmup
        XCTAssertEqual(category.id, "Warm-up", "id should return rawValue")
        XCTAssertEqual(category.id, category.rawValue, "id should match rawValue")
    }

    func testIcons() {
        // Verify each category has a non-empty icon string
        for category in ActivityCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category.rawValue) should have an icon")
        }

        // Verify specific icons
        XCTAssertEqual(ActivityCategory.instrument.icon, "guitars")
        XCTAssertEqual(ActivityCategory.piece.icon, "music.note.list")
        XCTAssertEqual(ActivityCategory.technique.icon, "hand.raised.fill")
        XCTAssertEqual(ActivityCategory.theory.icon, "book.closed.fill")
        XCTAssertEqual(ActivityCategory.warmup.icon, "flame.fill")
        XCTAssertEqual(ActivityCategory.other.icon, "ellipsis.circle.fill")
    }

    func testHashable() {
        // Verify enum can be used in Set (requires Hashable)
        let categories: Set<ActivityCategory> = [.instrument, .piece, .technique]
        XCTAssertEqual(categories.count, 3, "Set should contain unique values")

        // Verify contains works
        XCTAssertTrue(categories.contains(.instrument))
        XCTAssertFalse(categories.contains(.other))
    }

    func testCaseIterableOrder() {
        let allCases = ActivityCategory.allCases

        // Verify all 6 categories are present
        XCTAssertEqual(allCases.count, 6)

        // Verify expected order
        XCTAssertEqual(allCases[0], .instrument)
        XCTAssertEqual(allCases[1], .piece)
        XCTAssertEqual(allCases[2], .technique)
        XCTAssertEqual(allCases[3], .theory)
        XCTAssertEqual(allCases[4], .warmup)
        XCTAssertEqual(allCases[5], .other)
    }
}
