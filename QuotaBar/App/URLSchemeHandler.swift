//
//  URLSchemeHandler.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

enum URLSchemeHandler {
    static let scheme = "quotabar"

    static func providerId(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "provider" else { return nil }
        let providerId = url.pathComponents.dropFirst().first
        guard let providerId, ProviderDefinition.all.contains(where: { $0.id == providerId }) else {
            return nil
        }
        return providerId
    }
}
