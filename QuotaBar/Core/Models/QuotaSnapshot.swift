//
//  QuotaSnapshot.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

/// 统一额度快照模型，用于 App 与 Widget 间共享数据
public struct QuotaSnapshot: Codable, Equatable {
    public let timestamp: Date
    public let providers: [ProviderQuota]
    
    public init(timestamp: Date = Date(), providers: [ProviderQuota] = []) {
        self.timestamp = timestamp
        self.providers = providers
    }
}

public struct ProviderQuota: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let totalQuota: Double
    public let usedQuota: Double
    public let unit: String
    public let status: ProviderStatus
    
    public var remainingQuota: Double {
        max(0, totalQuota - usedQuota)
    }
    
    public var usagePercentage: Double {
        totalQuota > 0 ? (usedQuota / totalQuota) : 0
    }
    
    public init(
        id: String,
        name: String,
        totalQuota: Double,
        usedQuota: Double,
        unit: String,
        status: ProviderStatus = .unknown
    ) {
        self.id = id
        self.name = name
        self.totalQuota = totalQuota
        self.usedQuota = usedQuota
        self.unit = unit
        self.status = status
    }
}

public enum ProviderStatus: String, Codable, Equatable {
    case active
    case inactive
    case error
    case unknown
}
