//
//  MiniMaxProviderTests.swift
//  QuotaBarTests
//
//  Created by QuotaBar on 2026/06/30.
//

import XCTest
@testable import QuotaBar

final class MiniMaxProviderTests: XCTestCase {

    func testParserParsesUsageJSON() throws {
        let json = """
        {
          "data": {
            "plan": { "name": "Token Plan" },
            "usage": {
              "used_tokens": 125000,
              "total_tokens": 500000,
              "remaining_tokens": 375000,
              "reset_at": "2026-07-01T00:00:00Z",
              "period": "monthly"
            }
          }
        }
        """

        let summary = try MiniMaxParser().parse(
            data: Data(json.utf8),
            responseURL: URL(string: "https://platform.minimaxi.com/console/api/v1/usage/summary")!
        )

        XCTAssertEqual(summary.used, 125000)
        XCTAssertEqual(summary.total, 500000)
        XCTAssertEqual(summary.remaining, 375000)
        XCTAssertEqual(summary.planType, "Token Plan")
        XCTAssertEqual(summary.period, "monthly")
        XCTAssertNotNil(summary.resetAt)
    }

    func testParserParsesUsageHTML() throws {
        let html = """
        <html>
          <body>
            <section>
              <h1>Token Plan</h1>
              <div>Used tokens: 12,345</div>
              <div>Remaining tokens: 87,655</div>
              <div>Total tokens: 100,000</div>
              <div>Reset: 2026-07-01</div>
            </section>
          </body>
        </html>
        """

        let summary = try MiniMaxParser().parseHTML(
            html,
            responseURL: URL(string: "https://platform.minimaxi.com/console/usage")!
        )

        XCTAssertEqual(summary.used, 12345)
        XCTAssertEqual(summary.total, 100000)
        XCTAssertEqual(summary.remaining, 87655)
        XCTAssertEqual(summary.planType, "Token Plan")
        XCTAssertEqual(summary.period, "monthly")
        XCTAssertNotNil(summary.resetAt)
    }

    func testParserReportsStructureChangeWithLocation() {
        let html = """
        <html><body><h1>Token Plan</h1><p>Usage widgets moved.</p></body></html>
        """
        let url = URL(string: "https://platform.minimaxi.com/console/usage")!

        XCTAssertThrowsError(try MiniMaxParser().parseHTML(html, responseURL: url)) { error in
            guard case let MiniMaxParserError.missingRequiredFields(failedURL, selectors, snippet) = error else {
                return XCTFail("Expected missingRequiredFields, got \(error)")
            }

            XCTAssertEqual(failedURL, url.absoluteString)
            XCTAssertTrue(selectors.contains("used tokens"))
            XCTAssertTrue(selectors.contains("total tokens"))
            XCTAssertTrue(snippet.contains("Token Plan"))
        }
    }

    func testParserExtractsUsageAPIHints() {
        let html = """
        <script>
        fetch("/console/api/v1/usage/summary")
        fetch('https://platform.minimaxi.com/console/api/v1/usage/token-plan')
        </script>
        """

        let urls = MiniMaxParser().extractAPIHints(
            from: html,
            baseURL: URL(string: "https://platform.minimaxi.com/console/usage")!
        )

        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://platform.minimaxi.com/console/api/v1/usage/summary",
            "https://platform.minimaxi.com/console/api/v1/usage/token-plan"
        ])
    }
}
