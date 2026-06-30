//
//  DeepSeekProviderTests.swift
//  QuotaBarTests
//
//  Created by QuotaBar on 2026/06/30.
//

import XCTest
@testable import QuotaBar

final class DeepSeekProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolMock.requestHandler = nil
    }

    override func tearDown() {
        URLProtocolMock.requestHandler = nil
        super.tearDown()
    }

    func testFetchQuotaReturnsActiveQuotaForBalanceResponse() async throws {
        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/user/balance")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            let data = """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "USD",
                  "total_balance": "75.50",
                  "granted_balance": "25.50",
                  "topped_up_balance": "100.00"
                }
              ]
            }
            """.data(using: .utf8)!

            return (response, data)
        }

        let provider = makeProvider(apiKey: "test-key")
        let quota = try await provider.fetchQuota()

        XCTAssertEqual(quota.id, "deepseek")
        XCTAssertEqual(quota.name, "DeepSeek")
        XCTAssertEqual(quota.totalQuota, 125.5)
        XCTAssertEqual(quota.usedQuota, 50.0)
        XCTAssertEqual(quota.remainingQuota, 75.5)
        XCTAssertEqual(quota.unit, "USD")
        XCTAssertEqual(quota.status, .active)
        XCTAssertEqual(quota.period, "pay-as-you-go")
        XCTAssertEqual(quota.sourceType, "api")
        XCTAssertNil(quota.errorMessage)
    }

    func testFetchQuotaReturnsSessionExpiredForUnauthorizedResponse() async throws {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let provider = makeProvider(apiKey: "revoked-key")
        let quota = try await provider.fetchQuota()

        XCTAssertEqual(quota.status, .sessionExpired)
        XCTAssertEqual(quota.errorMessage, "DeepSeek 授权失败，请重新登录或重新授权 (HTTP 401)")
    }

    func testFetchQuotaReturnsSyncFailedForServerError() async throws {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let provider = makeProvider(apiKey: "test-key")
        let quota = try await provider.fetchQuota()

        XCTAssertEqual(quota.status, .syncFailed)
        XCTAssertEqual(quota.errorMessage, "DeepSeek 同步失败，HTTP 500")
    }

    func testFetchQuotaReturnsSessionExpiredWhenAPIKeyMissing() async throws {
        let provider = makeProvider(apiKey: nil)
        let quota = try await provider.fetchQuota()

        XCTAssertEqual(quota.status, .sessionExpired)
        XCTAssertEqual(quota.errorMessage, "DeepSeek API Key 未配置，请重新登录或重新授权")
    }

    func testFetchSnapshotWrapsProviderQuota() async throws {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            let data = """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "CNY",
                  "total_balance": "10.00",
                  "granted_balance": "0.00",
                  "topped_up_balance": "10.00"
                }
              ]
            }
            """.data(using: .utf8)!

            return (response, data)
        }

        let snapshot = try await makeProvider(apiKey: "test-key").fetchSnapshot()

        XCTAssertEqual(snapshot.providers.count, 1)
        XCTAssertEqual(snapshot.providers.first?.id, "deepseek")
        XCTAssertEqual(snapshot.providers.first?.unit, "CNY")
    }

    private func makeProvider(apiKey: String?) -> DeepSeekProvider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        return DeepSeekProvider(
            apiKeyProvider: { apiKey },
            session: session
        )
    }
}

private final class URLProtocolMock: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
