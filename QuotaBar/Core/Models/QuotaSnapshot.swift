//
//  QuotaSnapshot.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public enum ProviderStatus: String, Codable, Equatable, CaseIterable {
    case notConfigured
    case needsLogin
    case authenticated
    case syncing
    case synced
    case sessionExpired
    case syncFailed
}

public enum ProviderStatusEvent: Equatable {
    case configure
    case loginRequired
    case loginSucceeded
    case syncStarted
    case syncSucceeded
    case syncFailed
    case sessionExpired
    case logout
}

public extension ProviderStatus {
    var allowedNextStatuses: Set<ProviderStatus> {
        switch self {
        case .notConfigured:
            return [.needsLogin, .authenticated]
        case .needsLogin:
            return [.authenticated, .notConfigured]
        case .authenticated:
            return [.syncing, .needsLogin, .sessionExpired, .notConfigured]
        case .syncing:
            return [.synced, .syncFailed, .sessionExpired]
        case .synced:
            return [.syncing, .sessionExpired, .needsLogin, .notConfigured]
        case .sessionExpired:
            return [.needsLogin, .authenticated, .notConfigured]
        case .syncFailed:
            return [.syncing, .needsLogin, .sessionExpired, .notConfigured]
        }
    }

    func canTransition(to nextStatus: ProviderStatus) -> Bool {
        allowedNextStatuses.contains(nextStatus)
    }

    func transition(on event: ProviderStatusEvent) -> ProviderStatus? {
        let nextStatus: ProviderStatus

        switch event {
        case .configure:
            nextStatus = .needsLogin
        case .loginRequired:
            nextStatus = .needsLogin
        case .loginSucceeded:
            nextStatus = .authenticated
        case .syncStarted:
            nextStatus = .syncing
        case .syncSucceeded:
            nextStatus = .synced
        case .syncFailed:
            nextStatus = .syncFailed
        case .sessionExpired:
            nextStatus = .sessionExpired
        case .logout:
            nextStatus = .notConfigured
        }

        return canTransition(to: nextStatus) ? nextStatus : nil
    }
}

public enum ProviderIdentifier {
    public static let codex = "codex"
    public static let minimax = "minimax"
    public static let deepseek = "deepseek"
}

public enum ProviderSourceType {
    public static let api = "api"
    public static let webviewSession = "webview_session"
}

/// Unified quota snapshot shared by App, Widget, scheduler, and providers.
public struct QuotaSnapshot: Codable, Equatable {
    public let provider: String
    public let displayName: String
    public let planType: String
    public let used: Double?
    public let remaining: Double?
    public let total: Double?
    public let unit: String
    public let resetAt: Date?
    public let period: String?
    public let lastSyncedAt: Date
    public let sourceType: String
    public let status: ProviderStatus
    public let errorMessage: String?

    public init(
        provider: String,
        displayName: String,
        planType: String,
        used: Double? = nil,
        remaining: Double? = nil,
        total: Double? = nil,
        unit: String,
        resetAt: Date? = nil,
        period: String? = nil,
        lastSyncedAt: Date = Date(),
        sourceType: String,
        status: ProviderStatus,
        errorMessage: String? = nil
    ) {
        self.provider = provider
        self.displayName = displayName
        self.planType = planType
        self.used = used
        self.remaining = remaining
        self.total = total
        self.unit = unit
        self.resetAt = resetAt
        self.period = period
        self.lastSyncedAt = lastSyncedAt
        self.sourceType = sourceType
        self.status = status
        self.errorMessage = errorMessage
    }
}
