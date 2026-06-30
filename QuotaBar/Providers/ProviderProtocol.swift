//
//  ProviderProtocol.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import WebKit

public protocol ProviderProtocol: AnyObject {
    var providerId: String { get }
    var displayName: String { get }

    func isConfigured() async -> Bool
    func login(using webView: WKWebView) async throws
    func logout() async throws
    func fetchSnapshot() async throws -> QuotaSnapshot
    func needsReauthentication(from snapshot: QuotaSnapshot) -> Bool
}

public enum ProviderError: Error, Equatable, LocalizedError {
    case notConfigured(providerId: String)
    case authenticationRequired(providerId: String)
    case unsupportedLogin(providerId: String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let providerId):
            return "\(providerId) is not configured"
        case .authenticationRequired(let providerId):
            return "\(providerId) requires authentication"
        case .unsupportedLogin(let providerId):
            return "\(providerId) does not support this login flow yet"
        }
    }
}
