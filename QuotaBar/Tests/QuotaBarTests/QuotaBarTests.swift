//
//  QuotaBarTests.swift
//  QuotaBarTests
//
//  Created by QuotaBar on 2026/06/30.
//

import XCTest
@testable import QuotaBar

final class QuotaBarTests: XCTestCase {

    // MARK: - KeychainStore Tests

    func testKeychainSaveAndLoad() {
        let store = KeychainStore.shared
        let service = "quota-bar.test"
        let account = "u1"
        let token = "test-xxx"

        store.delete(service: service, account: account)

        XCTAssertTrue(store.save(token: token, service: service, account: account))
        XCTAssertEqual(store.load(service: service, account: account), token)
        XCTAssertTrue(store.delete(service: service, account: account))
        XCTAssertNil(store.load(service: service, account: account))
    }

    func testKeychainUpdate() {
        let store = KeychainStore.shared
        let service = "quota-bar.test.update"
        let account = "u2"
        let token1 = "token-v1"
        let token2 = "token-v2"

        store.delete(service: service, account: account)

        store.save(token: token1, service: service, account: account)
        XCTAssertEqual(store.load(service: service, account: account), token1)

        store.update(token: token2, service: service, account: account)
        XCTAssertEqual(store.load(service: service, account: account), token2)

        store.delete(service: service, account: account)
    }

    func testKeychainLoadNonExistent() {
        XCTAssertNil(KeychainStore.shared.load(service: "non-existent-service", account: "non-existent-account"))
    }

    func testCredentialManagerUsesExpectedServices() throws {
        let manager = CredentialManager()

        let codex = try XCTUnwrap(manager.descriptor(for: ProviderIdentifier.codex))
        let minimax = try XCTUnwrap(manager.descriptor(for: ProviderIdentifier.minimax))
        let deepseek = try XCTUnwrap(manager.descriptor(for: ProviderIdentifier.deepseek))

        XCTAssertEqual(codex.service, "quota-bar.codex")
        XCTAssertEqual(minimax.service, "quota-bar.minimax")
        XCTAssertEqual(deepseek.service, "quota-bar.deepseek")
        XCTAssertEqual(codex.account, CredentialManager.defaultAccount)
    }

    func testCredentialManagerSaveAndDeleteAuthenticatedSession() {
        let manager = CredentialManager()

        manager.deleteCredential(for: ProviderIdentifier.codex)

        XCTAssertFalse(manager.hasCredential(for: ProviderIdentifier.codex))
        XCTAssertTrue(manager.saveAuthenticatedSession(for: ProviderIdentifier.codex))
        XCTAssertTrue(manager.hasCredential(for: ProviderIdentifier.codex))
        XCTAssertTrue(manager.deleteCredential(for: ProviderIdentifier.codex))
        XCTAssertFalse(manager.hasCredential(for: ProviderIdentifier.codex))
    }

    func testURLSchemeHandlerParsesProviderDeepLink() throws {
        let url = try XCTUnwrap(URL(string: "quotabar://provider/codex"))

        XCTAssertEqual(URLSchemeHandler.providerId(from: url), ProviderIdentifier.codex)
        XCTAssertNil(URLSchemeHandler.providerId(from: URL(string: "quotabar://provider/missing")!))
        XCTAssertNil(URLSchemeHandler.providerId(from: URL(string: "https://provider/codex")!))
    }

    // MARK: - SharedSnapshotStore Tests

    func testSharedSnapshotStoreWriteAndReadSnapshots() throws {
        let directory = try makeTemporaryDirectory()
        let store = SharedSnapshotStore(containerURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshots = [makeSnapshot(provider: ProviderIdentifier.codex)]

        try store.write(snapshots)

        let loaded = try store.read()
        XCTAssertEqual(loaded, snapshots)
    }

    func testSharedSnapshotStoreSaveAndLoadCompatibility() throws {
        let directory = try makeTemporaryDirectory()
        let store = SharedSnapshotStore(containerURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = makeSnapshot(provider: ProviderIdentifier.minimax)

        try store.save(snapshot: snapshot)

        XCTAssertEqual(try store.load(), snapshot)

        try store.delete()
        XCTAssertNil(try store.load())
        XCTAssertEqual(try store.read(), [])
    }

    func testSharedSnapshotStoreRawString() throws {
        let directory = try makeTemporaryDirectory()
        let store = SharedSnapshotStore(containerURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let testString = "AppGroupConnectivityTest"
        try store.writeRawString(testString)

        XCTAssertEqual(try store.readRawString(), testString)

        try store.delete()
    }

    // MARK: - QuotaSnapshot Model Tests

    func testQuotaSnapshotCodingUsesUnifiedFieldNames() throws {
        let snapshot = makeSnapshot(provider: ProviderIdentifier.codex)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["provider"] as? String, ProviderIdentifier.codex)
        XCTAssertEqual(object["displayName"] as? String, "Codex")
        XCTAssertEqual(object["planType"] as? String, "ChatGPT Plus/Codex")
        XCTAssertEqual(object["used"] as? Double, 25)
        XCTAssertEqual(object["remaining"] as? Double, 75)
        XCTAssertEqual(object["total"] as? Double, 100)
        XCTAssertEqual(object["unit"] as? String, "requests")
        XCTAssertEqual(object["sourceType"] as? String, ProviderSourceType.webviewSession)
        XCTAssertEqual(object["status"] as? String, ProviderStatus.synced.rawValue)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(QuotaSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    // MARK: - ProviderStatus Tests

    func testProviderStatusLoginSuccessTransition() {
        XCTAssertEqual(ProviderStatus.needsLogin.transition(on: .loginSucceeded), .authenticated)
    }

    func testProviderStatusFetchSuccessTransition() {
        XCTAssertEqual(ProviderStatus.authenticated.transition(on: .syncStarted), .syncing)
        XCTAssertEqual(ProviderStatus.syncing.transition(on: .syncSucceeded), .synced)
    }

    func testProviderStatusRejectsInvalidTransition() {
        XCTAssertNil(ProviderStatus.notConfigured.transition(on: .syncSucceeded))
        XCTAssertFalse(ProviderStatus.needsLogin.canTransition(to: .synced))
    }

    // MARK: - ProviderRegistry Tests

    func testProviderRegistryRegisterAndLookup() {
        let registry = ProviderRegistry()
        let provider = CodexProvider()

        registry.register(provider: provider)

        XCTAssertTrue(registry.provider(for: ProviderIdentifier.codex) === provider)
        XCTAssertNil(registry.provider(for: "missing"))
    }

    // MARK: - Placeholder Provider Tests

    func testPlaceholderProvidersReturnNotConfiguredSnapshots() async throws {
        let providers: [ProviderProtocol] = [
            CodexProvider(),
            MiniMaxProvider(),
            DeepSeekProvider()
        ]

        for provider in providers {
            let snapshot = try await provider.fetchSnapshot()
            let isConfigured = await provider.isConfigured()

            XCTAssertFalse(isConfigured)
            XCTAssertEqual(snapshot.provider, provider.providerId)
            XCTAssertEqual(snapshot.displayName, provider.displayName)
            XCTAssertEqual(snapshot.status, .notConfigured)
            XCTAssertFalse(provider.needsReauthentication(from: snapshot))
        }
    }

    private func makeSnapshot(provider: String) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: provider,
            displayName: "Codex",
            planType: "ChatGPT Plus/Codex",
            used: 25,
            remaining: 75,
            total: 100,
            unit: "requests",
            resetAt: Date(timeIntervalSince1970: 1_783_000_000),
            period: "5h",
            lastSyncedAt: Date(timeIntervalSince1970: 1_782_982_800),
            sourceType: ProviderSourceType.webviewSession,
            status: .synced,
            errorMessage: nil
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
