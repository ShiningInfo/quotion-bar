//
//  QuotaTimelineProvider.swift
//  QuotaBarWidgetExtension
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import WidgetKit

struct QuotaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: QuotaSnapshot
    let loadMessage: String?

    var providers: [ProviderQuota] {
        snapshot.providers
    }

    var hasExpiredSession: Bool {
        providers.contains { $0.status == .sessionExpired }
    }
}

struct QuotaTimelineProvider: TimelineProvider {
    private let store: SharedSnapshotStore
    private let refreshInterval: TimeInterval

    init(
        store: SharedSnapshotStore = .shared,
        refreshInterval: TimeInterval = 15 * 60
    ) {
        self.store = store
        self.refreshInterval = refreshInterval
    }

    func placeholder(in context: Context) -> QuotaWidgetEntry {
        QuotaWidgetEntry(
            date: Date(),
            snapshot: QuotaSnapshot(timestamp: Date(), providers: Self.placeholderProviders),
            loadMessage: "等待首次同步"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaWidgetEntry) -> Void) {
        completion(loadEntry(date: Date(), fallbackProviders: Self.placeholderProviders))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaWidgetEntry>) -> Void) {
        let now = Date()
        let entry = loadEntry(date: now, fallbackProviders: Self.notConfiguredProviders)
        let nextRefresh = Calendar.current.date(byAdding: .second, value: Int(refreshInterval), to: now)
            ?? now.addingTimeInterval(refreshInterval)

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry(date: Date, fallbackProviders: [ProviderQuota]) -> QuotaWidgetEntry {
        do {
            if let snapshot = try store.load(), !snapshot.providers.isEmpty {
                return QuotaWidgetEntry(date: date, snapshot: snapshot, loadMessage: nil)
            }

            return QuotaWidgetEntry(
                date: date,
                snapshot: QuotaSnapshot(timestamp: date, providers: fallbackProviders),
                loadMessage: "未配置"
            )
        } catch {
            return QuotaWidgetEntry(
                date: date,
                snapshot: QuotaSnapshot(
                    timestamp: date,
                    providers: Self.notConfiguredProviders.map { provider in
                        ProviderQuota(
                            id: provider.id,
                            name: provider.name,
                            totalQuota: 0,
                            usedQuota: 0,
                            unit: provider.unit,
                            status: .syncFailed,
                            errorMessage: error.localizedDescription
                        )
                    }
                ),
                loadMessage: "读取快照失败"
            )
        }
    }

    static let placeholderProviders: [ProviderQuota] = [
        ProviderQuota(id: "codex", name: "Codex", totalQuota: 100, usedQuota: 36, unit: "USD", status: .synced, resetAt: Date().addingTimeInterval(86_400)),
        ProviderQuota(id: "minimax", name: "MiniMax", totalQuota: 500_000, usedQuota: 120_000, unit: "tokens", status: .syncing, resetAt: Date().addingTimeInterval(172_800)),
        ProviderQuota(id: "deepseek", name: "DeepSeek", totalQuota: 20, usedQuota: 7.5, unit: "USD", status: .sessionExpired)
    ]

    static let notConfiguredProviders: [ProviderQuota] = [
        ProviderQuota(id: "codex", name: "Codex", totalQuota: 0, usedQuota: 0, unit: "USD", status: .notConfigured),
        ProviderQuota(id: "minimax", name: "MiniMax", totalQuota: 0, usedQuota: 0, unit: "tokens", status: .notConfigured),
        ProviderQuota(id: "deepseek", name: "DeepSeek", totalQuota: 0, usedQuota: 0, unit: "USD", status: .notConfigured)
    ]
}
