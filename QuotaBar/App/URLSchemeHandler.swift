//
//  URLSchemeHandler.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public enum ProviderRouteAction: Equatable {
    case details
    case reauthorize
}

public struct ProviderRoute: Equatable {
    public let providerID: String
    public let action: ProviderRouteAction
}

public final class URLSchemeHandler: ObservableObject {
    @Published public private(set) var currentRoute: ProviderRoute?

    public init() {}

    public func handle(_ url: URL) {
        guard let route = Self.route(from: url) else { return }
        currentRoute = route
    }

    public static func route(from url: URL) -> ProviderRoute? {
        guard url.scheme == "quotabar", url.host == "provider" else {
            return nil
        }

        let providerID = url.pathComponents.dropFirst().first ?? ""
        guard !providerID.isEmpty else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let actionValue = components?.queryItems?.first { $0.name == "action" }?.value
        let action: ProviderRouteAction = actionValue == "reauthorize" ? .reauthorize : .details

        return ProviderRoute(providerID: providerID, action: action)
    }
}
