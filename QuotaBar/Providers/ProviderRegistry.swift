//
//  ProviderRegistry.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public final class ProviderRegistry {
    public static let shared = ProviderRegistry()

    private let lock = NSLock()
    private var providers: [String: ProviderProtocol]

    public init(providers: [ProviderProtocol] = []) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.providerId, $0) })
    }

    public func register(provider: ProviderProtocol) {
        lock.lock()
        providers[provider.providerId] = provider
        lock.unlock()
    }

    public func provider(for providerId: String) -> ProviderProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return providers[providerId]
    }

    public func allProviders() -> [ProviderProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return providers.values.sorted { $0.providerId < $1.providerId }
    }

    public func removeAll() {
        lock.lock()
        providers.removeAll()
        lock.unlock()
    }
}
