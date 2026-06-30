//
//  CodexProviderTests.swift
//  QuotaBarTests
//
//  Created by QuotaBar on 2026/06/30.
//

import XCTest
@testable import QuotaBar

final class CodexProviderTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.handler = nil
        CredentialManager.shared.deleteCredential(for: ProviderIdentifier.codex)
    }

    func testParserParsesUsageJSON() throws {
        let json = """
        {
          "data": {
            "plan": { "name": "ChatGPT Plus" },
            "codex": {
              "credits_used": 120,
              "credits_remaining": 380,
              "credit_limit": 500,
              "unit": "credits",
              "next_refresh": "2026-07-01T00:00:00Z",
              "period": "5h"
            }
          }
        }
        """

        let summary = try CodexParser().parse(
            data: Data(json.utf8),
            responseURL: URL(string: "https://chatgpt.com/backend-api/codex/usage")!
        )

        XCTAssertEqual(summary.used, 120)
        XCTAssertEqual(summary.remaining, 380)
        XCTAssertEqual(summary.total, 500)
        XCTAssertEqual(summary.unit, "credits")
        XCTAssertEqual(summary.planType, "ChatGPT Plus")
        XCTAssertEqual(summary.period, "5h")
        XCTAssertNotNil(summary.resetAt)
    }

    func testParserParsesBillingHTML() throws {
        let html = """
        <html>
          <body>
            <section>
              <h1>Codex usage</h1>
              <div>Plan: ChatGPT Pro</div>
              <div>Credits used: 25</div>
              <div>Credits remaining: 75</div>
              <div>Total credits: 100</div>
              <div>Next refresh: 2026-07-01T00:00:00Z</div>
              <div>Refresh window: 5h</div>
            </section>
          </body>
        </html>
        """

        let summary = try CodexParser().parseHTML(
            html,
            responseURL: URL(string: "https://chatgpt.com/codex/settings/usage")!
        )

        XCTAssertEqual(summary.used, 25)
        XCTAssertEqual(summary.remaining, 75)
        XCTAssertEqual(summary.total, 100)
        XCTAssertEqual(summary.unit, "credits")
        XCTAssertEqual(summary.planType, "ChatGPT Pro")
        XCTAssertEqual(summary.period, "5h")
        XCTAssertNotNil(summary.resetAt)
    }

    func testParserReportsStructureChangeWithLocation() {
        let html = """
        <html><body><h1>Codex usage</h1><p>Quota widgets moved.</p></body></html>
        """
        let url = URL(string: "https://chatgpt.com/codex/settings/usage")!

        XCTAssertThrowsError(try CodexParser().parseHTML(html, responseURL: url)) { error in
            guard case let CodexParserError.missingRequiredFields(failedURL, selectors, snippet) = error else {
                return XCTFail("Expected missingRequiredFields, got \(error)")
            }

            XCTAssertEqual(failedURL, url.absoluteString)
            XCTAssertTrue(selectors.contains("used"))
            XCTAssertTrue(selectors.contains("remaining"))
            XCTAssertTrue(snippet.contains("Codex usage"))
        }
    }

    func testParserExtractsUsageAPIHints() {
        let html = """
        <script>
        fetch("/backend-api/codex/usage")
        fetch('https://chatgpt.com/api/billing/credit_summary')
        </script>
        """

        let urls = CodexParser().extractAPIHints(
            from: html,
            baseURL: URL(string: "https://chatgpt.com/codex/settings/usage")!
        )

        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://chatgpt.com/backend-api/codex/usage",
            "https://chatgpt.com/api/billing/credit_summary"
        ])
    }

    func testProviderMapsUnauthorizedResponseToSessionExpiredSnapshot() async throws {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let provider = CodexProvider(
            cookieProvider: StaticCodexCookieProvider(cookies: [Self.chatGPTCookie()]),
            urlSession: Self.mockSession()
        )

        let snapshot = try await provider.fetchSnapshot()

        XCTAssertEqual(snapshot.provider, ProviderIdentifier.codex)
        XCTAssertEqual(snapshot.displayName, "Codex (ChatGPT)")
        XCTAssertEqual(snapshot.status, .sessionExpired)
        XCTAssertTrue(provider.needsReauthentication(from: snapshot))
        XCTAssertTrue(snapshot.errorMessage?.contains("重新授权") == true)
    }

    private static func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func chatGPTCookie() -> HTTPCookie {
        HTTPCookie(properties: [
            .domain: ".chatgpt.com",
            .path: "/",
            .name: "quota_bar_test_session",
            .value: "test-value",
            .secure: "TRUE"
        ])!
    }
}

private struct StaticCodexCookieProvider: CodexCookieProviding {
    let cookies: [HTTPCookie]

    func cookies() async -> [HTTPCookie] {
        cookies
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
