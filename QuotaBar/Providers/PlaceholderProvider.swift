//
//  PlaceholderProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import WebKit

public class PlaceholderProvider: ProviderProtocol {
    public let providerId: String
    public let displayName: String

    private let planType: String
    private let sourceType: String

    public init(providerId: String, displayName: String, planType: String, sourceType: String) {
        self.providerId = providerId
        self.displayName = displayName
        self.planType = planType
        self.sourceType = sourceType
    }

    public func isConfigured() async -> Bool {
        false
    }

    public func login(using webView: WKWebView) async throws {
        throw ProviderError.unsupportedLogin(providerId: providerId)
    }

    public func logout() async throws {}

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        QuotaSnapshot(
            provider: providerId,
            displayName: displayName,
            planType: planType,
            unit: "requests",
            sourceType: sourceType,
            status: .notConfigured,
            errorMessage: "Provider is not configured yet"
        )
    }

    public func needsReauthentication(from snapshot: QuotaSnapshot) -> Bool {
        snapshot.status == .needsLogin || snapshot.status == .sessionExpired
    }
}
