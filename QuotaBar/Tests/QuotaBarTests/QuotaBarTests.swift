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
        
        // Clean up first
        store.delete(service: service, account: account)
        
        // Save
        let saveResult = store.save(token: token, service: service, account: account)
        XCTAssertTrue(saveResult, "Keychain save should succeed")
        
        // Load
        let loaded = store.load(service: service, account: account)
        XCTAssertEqual(loaded, token, "Loaded token should match saved token")
        
        // Delete
        let deleteResult = store.delete(service: service, account: account)
        XCTAssertTrue(deleteResult, "Keychain delete should succeed")
        
        // Load after delete
        let afterDelete = store.load(service: service, account: account)
        XCTAssertNil(afterDelete, "Token should be nil after delete")
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
        let store = KeychainStore.shared
        let loaded = store.load(service: "non-existent-service", account: "non-existent-account")
        XCTAssertNil(loaded, "Loading non-existent item should return nil")
    }
    
    // MARK: - SharedSnapshotStore Tests
    
    func testSharedSnapshotStoreSaveAndLoad() throws {
        let directory = try makeTemporaryDirectory()
        let store = SharedSnapshotStore(containerURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        
        // Clean up
        try? store.delete()
        
        let snapshot = QuotaSnapshot(
            timestamp: Date(),
            providers: [
                ProviderQuota(
                    id: "codex",
                    name: "Codex",
                    totalQuota: 1000,
                    usedQuota: 250,
                    unit: "USD",
                    status: .active
                )
            ]
        )
        
        // Save
        try store.save(snapshot: snapshot)
        
        // Load
        let loaded = try store.load()
        XCTAssertNotNil(loaded, "Loaded snapshot should not be nil")
        XCTAssertEqual(loaded?.providers.count, 1)
        XCTAssertEqual(loaded?.providers.first?.id, "codex")
        XCTAssertEqual(loaded?.providers.first?.name, "Codex")
        
        // Delete
        try store.delete()
        
        // Load after delete
        let afterDelete = try store.load()
        XCTAssertNil(afterDelete, "Snapshot should be nil after delete")
    }
    
    func testSharedSnapshotStoreRawString() throws {
        let directory = try makeTemporaryDirectory()
        let store = SharedSnapshotStore(containerURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        
        // Clean up
        try? store.delete()
        
        let testString = "AppGroupConnectivityTest"
        try store.writeRawString(testString)
        
        let loaded = try store.readRawString()
        XCTAssertEqual(loaded, testString, "Raw string should match after round-trip")
        
        try store.delete()
    }
    
    // MARK: - QuotaSnapshot Model Tests
    
    func testProviderQuotaCalculations() {
        let quota = ProviderQuota(
            id: "test",
            name: "Test",
            totalQuota: 100,
            usedQuota: 30,
            unit: "USD",
            status: .active
        )
        
        XCTAssertEqual(quota.remainingQuota, 70)
        XCTAssertEqual(quota.usagePercentage, 0.3)
    }
    
    func testProviderQuotaZeroTotal() {
        let quota = ProviderQuota(
            id: "test",
            name: "Test",
            totalQuota: 0,
            usedQuota: 10,
            unit: "USD",
            status: .active
        )
        
        XCTAssertEqual(quota.remainingQuota, 0)
        XCTAssertEqual(quota.usagePercentage, 0)
    }
    
    func testQuotaSnapshotCoding() throws {
        let snapshot = QuotaSnapshot(
            timestamp: Date(),
            providers: [
                ProviderQuota(
                    id: "codex",
                    name: "Codex",
                    totalQuota: 1000,
                    usedQuota: 250,
                    unit: "USD",
                    status: .active
                )
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(QuotaSnapshot.self, from: data)
        
        XCTAssertEqual(decoded.providers.count, snapshot.providers.count)
        XCTAssertEqual(decoded.providers.first?.id, snapshot.providers.first?.id)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
