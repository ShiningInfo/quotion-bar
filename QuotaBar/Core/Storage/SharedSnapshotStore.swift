//
//  SharedSnapshotStore.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

/// 通过 App Group 在主 App 与 Widget Extension 间读写额度快照 JSON
public final class SharedSnapshotStore {
    
    public static let shared = SharedSnapshotStore()
    
    private let appGroupIdentifier: String
    private let filename: String
    private let containerURLOverride: URL?
    
    private var containerURL: URL? {
        if let containerURLOverride {
            return containerURLOverride
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    private var snapshotURL: URL? {
        containerURL?.appendingPathComponent(filename)
    }
    
    public init(
        appGroupIdentifier: String = ConfigKeys.appGroupIdentifier,
        filename: String = ConfigKeys.snapshotFilename,
        containerURL: URL? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.filename = filename
        self.containerURLOverride = containerURL
    }
    
    // MARK: - Save
    
    public func save(snapshot: QuotaSnapshot) throws {
        guard let url = snapshotURL else {
            throw SnapshotStoreError.containerNotFound
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
    
    // MARK: - Load
    
    public func load() throws -> QuotaSnapshot? {
        guard let url = snapshotURL else {
            throw SnapshotStoreError.containerNotFound
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QuotaSnapshot.self, from: data)
    }
    
    // MARK: - Delete
    
    public func delete() throws {
        guard let url = snapshotURL else {
            throw SnapshotStoreError.containerNotFound
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Write Raw String (for testing App Group connectivity)
    
    public func writeRawString(_ string: String) throws {
        guard let url = snapshotURL else {
            throw SnapshotStoreError.containerNotFound
        }
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public func readRawString() throws -> String? {
        guard let url = snapshotURL else {
            throw SnapshotStoreError.containerNotFound
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

public enum SnapshotStoreError: Error, LocalizedError {
    case containerNotFound
    
    public var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "App Group 容器目录未找到，请检查 App Group 配置"
        }
    }
}
