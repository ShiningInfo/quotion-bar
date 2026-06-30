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
    public let planType: String?
    public let period: String?
    public let sourceType: String?
    public let errorMessage: String?
    
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
        status: ProviderStatus = .unknown,
        planType: String? = nil,
        period: String? = nil,
        sourceType: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.totalQuota = totalQuota
        self.usedQuota = usedQuota
        self.unit = unit
        self.status = status
        self.planType = planType
        self.period = period
        self.sourceType = sourceType
        self.errorMessage = errorMessage
    }
}

public enum ProviderStatus: String, Codable, Equatable {
    case active
    case inactive
    case error
    case sessionExpired
    case syncFailed
    case unknown
}
