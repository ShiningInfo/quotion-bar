//
//  QuotaBarWidgetTests.swift
//  QuotaBarWidgetExtensionTests
//
//  Created by QuotaBar on 2026/06/30.
//

import XCTest
@testable import QuotaBarWidgetExtension

final class QuotaBarWidgetTests: XCTestCase {
    
    func testWidgetEntryCreation() {
        let entry = SimpleEntry(date: Date(), text: "Test Widget")
        XCTAssertEqual(entry.text, "Test Widget")
    }
}
