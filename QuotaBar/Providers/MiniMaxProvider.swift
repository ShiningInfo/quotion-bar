//
//  MiniMaxProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import WebKit

public enum MiniMaxProviderError: Error, LocalizedError, Equatable {
    case sessionExpired
    case syncFailed(url: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "MiniMax 登录态已过期，请重新授权"
        case let .syncFailed(url, detail):
            return "MiniMax 同步失败: \(url). \(detail)"
        }
    }
}

public protocol MiniMaxCookieProviding {
    func cookies() async -> [HTTPCookie]
}

public struct WKWebsiteDataStoreCookieProvider: MiniMaxCookieProviding {
    private let dataStore: WKWebsiteDataStore

    public init(dataStore: WKWebsiteDataStore = .default()) {
        self.dataStore = dataStore
    }

    public func cookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}

public final class MiniMaxProvider: ProviderProtocol {
    public static let service = "quota-bar.minimax"
    public static let usageURL = URL(string: "https://platform.minimaxi.com/console/usage")!

    public let id = "minimax"
    public let name = "MiniMax"

    private let cookieProvider: MiniMaxCookieProviding
    private let parser: MiniMaxParser
    private let urlSession: URLSession
    private let keychainStore: KeychainStore

    public init(
        cookieProvider: MiniMaxCookieProviding = WKWebsiteDataStoreCookieProvider(),
        parser: MiniMaxParser = MiniMaxParser(),
        urlSession: URLSession = .shared,
        keychainStore: KeychainStore = .shared
    ) {
        self.cookieProvider = cookieProvider
        self.parser = parser
        self.urlSession = urlSession
        self.keychainStore = keychainStore
    }

    public func fetchQuota() async throws -> ProviderQuota {
        let cookies = await sessionCookies()
        guard !cookies.isEmpty else {
            throw MiniMaxProviderError.sessionExpired
        }

        keychainStore.save(
            token: "wkwebview-session:\(Self.usageURL.host ?? "platform.minimaxi.com")",
            service: Self.service,
            account: "session"
        )

        let usageData = try await fetch(Self.usageURL, cookies: cookies)
        guard let usageHTML = String(data: usageData, encoding: .utf8) else {
            throw MiniMaxProviderError.syncFailed(url: Self.usageURL.absoluteString, detail: "Usage page is not UTF-8 HTML")
        }

        guard !looksLikeLoginPage(usageHTML) else {
            throw MiniMaxProviderError.sessionExpired
        }

        let apiURLs = parser.extractAPIHints(from: usageHTML, baseURL: Self.usageURL) + defaultAPIURLs()
        for url in unique(apiURLs) {
            do {
                let data = try await fetch(url, cookies: cookies)
                let summary = try parser.parse(data: data, responseURL: url)
                return quota(from: summary)
            } catch MiniMaxParserError.missingRequiredFields {
                continue
            } catch MiniMaxParserError.invalidResponse {
                continue
            } catch {
                continue
            }
        }

        do {
            let summary = try parser.parseHTML(usageHTML, responseURL: Self.usageURL)
            return quota(from: summary)
        } catch {
            throw MiniMaxProviderError.syncFailed(url: Self.usageURL.absoluteString, detail: error.localizedDescription)
        }
    }

    private func quota(from summary: MiniMaxUsageSummary) -> ProviderQuota {
        ProviderQuota(
            id: id,
            name: name,
            totalQuota: summary.total,
            usedQuota: summary.used,
            unit: "tokens",
            status: .active,
            planType: summary.planType,
            resetAt: summary.resetAt,
            period: summary.period,
            sourceType: "webview_session"
        )
    }

    private func sessionCookies() async -> [HTTPCookie] {
        await cookieProvider.cookies().filter { cookie in
            cookie.domain == "platform.minimaxi.com"
                || cookie.domain == ".platform.minimaxi.com"
                || cookie.domain == "minimaxi.com"
                || cookie.domain == ".minimaxi.com"
                || cookie.domain.hasSuffix(".minimaxi.com")
        }
    }

    private func fetch(_ url: URL, cookies: [HTTPCookie]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("text/html,application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaBar/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(cookieHeader(from: cookies), forHTTPHeaderField: "Cookie")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxProviderError.syncFailed(url: url.absoluteString, detail: "Missing HTTP response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw MiniMaxProviderError.sessionExpired
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MiniMaxProviderError.syncFailed(url: url.absoluteString, detail: "HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    private func cookieHeader(from cookies: [HTTPCookie]) -> String {
        cookies
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    private func defaultAPIURLs() -> [URL] {
        [
            "https://platform.minimaxi.com/console/api/v1/usage/summary",
            "https://platform.minimaxi.com/console/api/v1/usage/token-plan",
            "https://platform.minimaxi.com/console/api/v1/token-plan/usage"
        ].compactMap(URL.init(string:))
    }

    private func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }

    private func looksLikeLoginPage(_ html: String) -> Bool {
        let lowercased = html.lowercased()
        return lowercased.contains("login") || lowercased.contains("sign in") || lowercased.contains("登录")
    }
}
