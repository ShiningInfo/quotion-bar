//
//  CodexProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import WebKit

public enum CodexProviderError: Error, LocalizedError, Equatable {
    case sessionExpired
    case syncFailed(url: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "Codex 登录态已过期，请重新授权"
        case let .syncFailed(url, detail):
            return "Codex 同步失败: \(url). \(detail)"
        }
    }
}

public protocol CodexCookieProviding {
    func cookies() async -> [HTTPCookie]
}

public struct CodexWebsiteDataStoreCookieProvider: CodexCookieProviding {
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

public final class CodexProvider: ProviderProtocol {
    public static let service = "quota-bar.codex"
    public static let credentialAccount = CredentialManager.defaultAccount
    public static let loginURL = URL(string: "https://chatgpt.com/")!
    public static let billingURL = URL(string: "https://chatgpt.com/#settings/Billing")!
    public static let usageURL = URL(string: "https://chatgpt.com/codex/settings/usage")!

    public let providerId = ProviderIdentifier.codex
    public let displayName = "Codex (ChatGPT)"

    private let cookieProvider: CodexCookieProviding
    private let parser: CodexParser
    private let urlSession: URLSession
    private let credentialManager: CredentialManager

    public init(
        cookieProvider: CodexCookieProviding = CodexWebsiteDataStoreCookieProvider(),
        parser: CodexParser = CodexParser(),
        urlSession: URLSession = .shared,
        credentialManager: CredentialManager = .shared
    ) {
        self.cookieProvider = cookieProvider
        self.parser = parser
        self.urlSession = urlSession
        self.credentialManager = credentialManager
    }

    public func isConfigured() async -> Bool {
        if credentialManager.hasCredential(for: providerId) {
            return true
        }
        return !(await sessionCookies()).isEmpty
    }

    public func login(using webView: WKWebView) async throws {
        await webView.load(URLRequest(url: Self.loginURL))
    }

    public func logout() async throws {
        credentialManager.deleteCredential(for: providerId)
    }

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        do {
            let cookies = await sessionCookies()
            guard !cookies.isEmpty else {
                return failureSnapshot(status: .sessionExpired, message: CodexProviderError.sessionExpired.localizedDescription)
            }

            credentialManager.saveAuthenticatedSession(for: providerId)

            let pages = try await fetchPages(cookies: cookies)
            let hintedAPIs = pages.flatMap { parser.extractAPIHints(from: $0.html, baseURL: $0.url) }
            let apiURLs = unique(hintedAPIs + defaultAPIURLs())

            for url in apiURLs {
                do {
                    let data = try await fetch(url, cookies: cookies)
                    let summary = try parser.parse(data: data, responseURL: url)
                    return snapshot(from: summary)
                } catch CodexProviderError.sessionExpired {
                    return failureSnapshot(status: .sessionExpired, message: CodexProviderError.sessionExpired.localizedDescription)
                } catch CodexParserError.missingRequiredFields {
                    continue
                } catch CodexParserError.invalidResponse {
                    continue
                } catch {
                    continue
                }
            }

            for page in pages {
                do {
                    let summary = try parser.parseHTML(page.html, responseURL: page.url)
                    return snapshot(from: summary)
                } catch CodexParserError.missingRequiredFields {
                    continue
                } catch CodexParserError.invalidResponse {
                    continue
                }
            }

            return failureSnapshot(
                status: .syncFailed,
                message: CodexProviderError.syncFailed(
                    url: Self.usageURL.absoluteString,
                    detail: "Codex Billing/Usage 页面结构变化，无法识别 used/remaining 字段"
                ).localizedDescription
            )
        } catch CodexProviderError.sessionExpired {
            return failureSnapshot(status: .sessionExpired, message: CodexProviderError.sessionExpired.localizedDescription)
        } catch let error as CodexProviderError {
            return failureSnapshot(status: .syncFailed, message: error.localizedDescription)
        } catch {
            return failureSnapshot(status: .syncFailed, message: "Codex 同步失败：\(error.localizedDescription)")
        }
    }

    public func needsReauthentication(from snapshot: QuotaSnapshot) -> Bool {
        snapshot.status == .needsLogin || snapshot.status == .sessionExpired
    }

    private func fetchPages(cookies: [HTTPCookie]) async throws -> [(url: URL, html: String)] {
        var pages: [(url: URL, html: String)] = []

        for url in [Self.usageURL, Self.billingURL] {
            let data = try await fetch(url, cookies: cookies)
            guard let html = String(data: data, encoding: .utf8) else {
                throw CodexProviderError.syncFailed(url: url.absoluteString, detail: "Response is not UTF-8 HTML")
            }

            guard !looksLikeLoginOrChallengePage(html) else {
                throw CodexProviderError.sessionExpired
            }

            pages.append((url: url, html: html))
        }

        return pages
    }

    private func snapshot(from summary: CodexUsageSummary) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: providerId,
            displayName: displayName,
            planType: summary.planType,
            used: summary.used,
            remaining: summary.remaining,
            total: summary.total,
            unit: summary.unit,
            resetAt: summary.resetAt,
            period: summary.period,
            sourceType: ProviderSourceType.webviewSession,
            status: .synced
        )
    }

    private func failureSnapshot(status: ProviderStatus, message: String) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: providerId,
            displayName: displayName,
            planType: "ChatGPT Codex",
            unit: "credits",
            sourceType: ProviderSourceType.webviewSession,
            status: status,
            errorMessage: message
        )
    }

    private func sessionCookies() async -> [HTTPCookie] {
        await cookieProvider.cookies().filter { cookie in
            cookie.domain == "chatgpt.com"
                || cookie.domain == ".chatgpt.com"
                || cookie.domain.hasSuffix(".chatgpt.com")
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
            throw CodexProviderError.syncFailed(url: url.absoluteString, detail: "Missing HTTP response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CodexProviderError.sessionExpired
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CodexProviderError.syncFailed(url: url.absoluteString, detail: "HTTP \(httpResponse.statusCode)")
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
            "https://chatgpt.com/backend-api/codex/usage",
            "https://chatgpt.com/backend-api/billing/credit_summary",
            "https://chatgpt.com/api/codex/usage",
            "https://chatgpt.com/api/billing/credit_summary",
            "https://chatgpt.com/codex/settings/usage"
        ].compactMap(URL.init(string:))
    }

    private func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }

    private func looksLikeLoginOrChallengePage(_ html: String) -> Bool {
        let lowercased = html.lowercased()
        return lowercased.contains("login")
            || lowercased.contains("log in")
            || lowercased.contains("sign in")
            || lowercased.contains("cloudflare")
            || lowercased.contains("cf-challenge")
            || lowercased.contains("二次验证")
            || lowercased.contains("登录")
    }
}
