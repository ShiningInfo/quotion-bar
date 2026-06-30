//
//  CredentialManager.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public struct ProviderCredentialDescriptor: Equatable {
    public let providerId: String
    public let service: String
    public let account: String

    public init(providerId: String, service: String, account: String) {
        self.providerId = providerId
        self.service = service
        self.account = account
    }
}

public final class CredentialManager {
    public static let shared = CredentialManager()

    public static let defaultAccount = "local-session"

    private let keychainStore: KeychainStore

    public init(keychainStore: KeychainStore = .shared) {
        self.keychainStore = keychainStore
    }

    public func descriptor(for providerId: String) -> ProviderCredentialDescriptor? {
        switch providerId {
        case ProviderIdentifier.codex:
            return ProviderCredentialDescriptor(
                providerId: providerId,
                service: "quota-bar.codex",
                account: Self.defaultAccount
            )
        case ProviderIdentifier.minimax:
            return ProviderCredentialDescriptor(
                providerId: providerId,
                service: "quota-bar.minimax",
                account: Self.defaultAccount
            )
        case ProviderIdentifier.deepseek:
            return ProviderCredentialDescriptor(
                providerId: providerId,
                service: "quota-bar.deepseek",
                account: Self.defaultAccount
            )
        default:
            return nil
        }
    }

    public func hasCredential(for providerId: String) -> Bool {
        guard let descriptor = descriptor(for: providerId) else { return false }
        return keychainStore.load(service: descriptor.service, account: descriptor.account) != nil
    }

    @discardableResult
    public func saveAuthenticatedSession(for providerId: String, account: String? = nil) -> Bool {
        guard let descriptor = descriptor(for: providerId) else { return false }
        let token = "authenticated:\(Int(Date().timeIntervalSince1970))"
        return keychainStore.save(
            token: token,
            service: descriptor.service,
            account: account ?? descriptor.account
        )
    }

    @discardableResult
    public func deleteCredential(for providerId: String) -> Bool {
        guard let descriptor = descriptor(for: providerId) else { return false }
        return keychainStore.delete(service: descriptor.service, account: descriptor.account)
    }
}
