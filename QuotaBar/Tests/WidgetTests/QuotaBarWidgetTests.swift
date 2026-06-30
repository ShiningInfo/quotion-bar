//
//  QuotaBarWidgetTests.swift
//  QuotaBarWidgetExtensionTests
//
//  Created by QuotaBar on 2026/06/30.
//

import XCTest

final class QuotaBarWidgetTests: XCTestCase {
    
    func testWidgetEntryCreation() {
        let snapshot = QuotaSnapshot(
            providers: [
                ProviderQuota(
                    id: "codex",
                    name: "Codex",
                    totalQuota: 100,
                    usedQuota: 25,
                    unit: "USD",
                    status: .synced
                )
            ]
        )
        let entry = QuotaWidgetEntry(date: Date(), snapshot: snapshot, loadMessage: nil)

        XCTAssertEqual(entry.providers.first?.id, "codex")
        XCTAssertFalse(entry.hasExpiredSession)
    }

    func testWidgetEntryDetectsExpiredSession() {
        let snapshot = QuotaSnapshot(
            providers: [
                ProviderQuota(
                    id: "deepseek",
                    name: "DeepSeek",
                    totalQuota: 0,
                    usedQuota: 0,
                    unit: "USD",
                    status: .sessionExpired
                )
            ]
        )
        let entry = QuotaWidgetEntry(date: Date(), snapshot: snapshot, loadMessage: nil)

        XCTAssertTrue(entry.hasExpiredSession)
    }
}
