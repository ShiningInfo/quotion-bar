//
//  ProviderConfigurationStore.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

struct ProviderDefinition: Identifiable, Equatable {
    let id: String
    let displayName: String
    let loginURL: URL
    let serviceName: String

    static let all: [ProviderDefinition] = [
        ProviderDefinition(
            id: ProviderIdentifier.codex,
            displayName: "Codex",
            loginURL: URL(string: "https://chatgpt.com/")!,
            serviceName: "quota-bar.codex"
        ),
        ProviderDefinition(
            id: ProviderIdentifier.minimax,
            displayName: "MiniMax",
            loginURL: URL(string: "https://platform.minimaxi.com/")!,
            serviceName: "quota-bar.minimax"
        ),
        ProviderDefinition(
            id: ProviderIdentifier.deepseek,
            displayName: "DeepSeek",
            loginURL: URL(string: "https://platform.deepseek.com/")!,
            serviceName: "quota-bar.deepseek"
        )
    ]
}

struct ProviderViewState: Identifiable, Equatable {
    let definition: ProviderDefinition
    var status: ProviderStatus
    var lastSyncedAt: Date?
    var errorMessage: String?

    var id: String { definition.id }
    var displayName: String { definition.displayName }
    var loginURL: URL { definition.loginURL }
}

@MainActor
final class ProviderConfigurationStore: ObservableObject {
    @Published private(set) var providers: [ProviderViewState]
    @Published var selectedProviderId: String
    @Published var activeLoginProvider: ProviderViewState?
    @Published var pendingCredentialDeletion: ProviderViewState?

    private let registry: ProviderRegistry
    private let credentialManager: CredentialManager

    init(
        registry: ProviderRegistry = .shared,
        credentialManager: CredentialManager = .shared
    ) {
        self.registry = registry
        self.credentialManager = credentialManager
        self.providers = ProviderDefinition.all.map {
            ProviderViewState(definition: $0, status: .notConfigured)
        }
        self.selectedProviderId = ProviderDefinition.all[0].id
        registerDefaultProvidersIfNeeded()
        refreshCredentialState()
    }

    var selectedProvider: ProviderViewState? {
        providers.first { $0.id == selectedProviderId }
    }

    func select(providerId: String) {
        guard providers.contains(where: { $0.id == providerId }) else { return }
        selectedProviderId = providerId
    }

    func openLogin(for providerId: String) {
        guard let provider = providers.first(where: { $0.id == providerId }) else { return }
        updateProvider(providerId) {
            $0.status = ($0.status == .notConfigured) ? .needsLogin : $0.status
            $0.errorMessage = nil
        }
        activeLoginProvider = provider
    }

    func completeLogin(for providerId: String) {
        if credentialManager.saveAuthenticatedSession(for: providerId) {
            updateProvider(providerId) {
                $0.status = .authenticated
                $0.errorMessage = nil
            }
        } else {
            updateProvider(providerId) {
                $0.status = .syncFailed
                $0.errorMessage = "Unable to save login state in Keychain."
            }
        }
        activeLoginProvider = nil
    }

    func cancelLogin() {
        activeLoginProvider = nil
        refreshCredentialState()
    }

    func requestCredentialDeletion(for providerId: String) {
        pendingCredentialDeletion = providers.first { $0.id == providerId }
    }

    func deleteCredentials(for providerId: String) {
        let deleted = credentialManager.deleteCredential(for: providerId)
        updateProvider(providerId) {
            $0.status = .notConfigured
            $0.lastSyncedAt = nil
            $0.errorMessage = deleted ? nil : "Unable to delete Keychain credential."
        }
        pendingCredentialDeletion = nil

        Task {
            try? await registry.provider(for: providerId)?.logout()
        }
    }

    func sync(providerId: String) {
        guard let provider = registry.provider(for: providerId) else {
            updateProvider(providerId) {
                $0.status = .syncFailed
                $0.errorMessage = "Provider implementation is not registered."
            }
            return
        }

        updateProvider(providerId) {
            $0.status = .syncing
            $0.errorMessage = nil
        }

        Task {
            do {
                let snapshot = try await provider.fetchSnapshot()
                await MainActor.run {
                    updateProvider(providerId) {
                        $0.status = snapshot.status
                        $0.lastSyncedAt = snapshot.lastSyncedAt
                        $0.errorMessage = snapshot.errorMessage
                    }
                }
            } catch {
                await MainActor.run {
                    updateProvider(providerId) {
                        $0.status = .syncFailed
                        $0.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func openProvider(from url: URL) {
        guard let providerId = URLSchemeHandler.providerId(from: url) else { return }
        select(providerId: providerId)
        openLogin(for: providerId)
    }

    private func refreshCredentialState() {
        for provider in providers {
            let status: ProviderStatus = credentialManager.hasCredential(for: provider.id)
                ? .authenticated
                : .notConfigured
            updateProvider(provider.id) {
                $0.status = status
                if status == .notConfigured {
                    $0.lastSyncedAt = nil
                }
            }
        }
    }

    private func updateProvider(_ providerId: String, update: (inout ProviderViewState) -> Void) {
        guard let index = providers.firstIndex(where: { $0.id == providerId }) else { return }
        update(&providers[index])
    }

    private func registerDefaultProvidersIfNeeded() {
        let defaultProviders: [ProviderProtocol] = [CodexProvider(), MiniMaxProvider(), DeepSeekProvider()]
        for provider in defaultProviders {
            if registry.provider(for: provider.providerId) == nil {
                registry.register(provider: provider)
            }
        }
    }
}
