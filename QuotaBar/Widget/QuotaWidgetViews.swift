//
//  QuotaWidgetViews.swift
//  QuotaBarWidgetExtension
//
//  Created by QuotaBar on 2026/06/30.
//

import SwiftUI
import WidgetKit

struct QuotaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuotaWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                QuotaSmallWidgetView(entry: entry)
            case .systemLarge:
                QuotaLargeWidgetView(entry: entry)
            default:
                QuotaMediumWidgetView(entry: entry)
            }
        }
    }
}

struct QuotaSmallWidgetView: View {
    let entry: QuotaWidgetEntry

    private var provider: ProviderQuota {
        entry.providers.sortedForWidget.first ?? QuotaTimelineProvider.notConfiguredProviders[0]
    }

    var body: some View {
        Link(destination: WidgetDeepLink.provider(provider.id)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    ProviderIcon(providerID: provider.id)
                    Spacer(minLength: 8)
                    StatusBadge(status: provider.status)
                }

                Spacer(minLength: 4)

                Text(provider.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(provider.remainingText)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(provider.resetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding()
        }
        .widgetURL(WidgetDeepLink.provider(provider.id))
    }
}

struct QuotaMediumWidgetView: View {
    let entry: QuotaWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            ForEach(entry.providers.normalizedForWidget) { provider in
                ProviderQuotaCard(provider: provider, showsErrorText: false)
            }
        }
        .padding()
    }
}

struct QuotaLargeWidgetView: View {
    let entry: QuotaWidgetEntry

    private var errorMessage: String? {
        entry.providers.compactMap(\.shortErrorText).first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quota Bar")
                    .font(.headline)
                Spacer()
                Text("同步 \(entry.snapshot.timestamp.shortTimeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(entry.providers.normalizedForWidget) { provider in
                    ProviderQuotaCard(provider: provider, showsErrorText: true)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else if entry.hasExpiredSession {
                Label("有平台需要重新授权", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }
}

struct ProviderQuotaCard: View {
    let provider: ProviderQuota
    let showsErrorText: Bool

    var body: some View {
        Link(destination: WidgetDeepLink.provider(provider.id)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    ProviderIcon(providerID: provider.id)
                    Text(provider.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    StatusBadge(status: provider.status)
                }

                ProgressView(value: provider.progressValue)
                    .progressViewStyle(.linear)
                    .tint(provider.status.tintColor)

                HStack(alignment: .lastTextBaseline) {
                    Text(provider.remainingText)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 6)
                    Text(provider.stateText)
                        .font(.caption)
                        .foregroundStyle(provider.status.tintColor)
                        .lineLimit(1)
                }

                if provider.status == .sessionExpired {
                    Link(destination: WidgetDeepLink.reauthorize(provider.id)) {
                        Label("重新授权", systemImage: "arrow.clockwise.circle")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.orange)
                } else if showsErrorText, let error = provider.shortErrorText {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ProviderIcon: View {
    let providerID: String

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 24, height: 24)
            .foregroundStyle(.white)
            .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var symbolName: String {
        switch providerID {
        case "codex":
            return "terminal"
        case "minimax":
            return "sparkles"
        case "deepseek":
            return "creditcard"
        default:
            return "chart.bar"
        }
    }

    private var tint: Color {
        switch providerID {
        case "codex":
            return .blue
        case "minimax":
            return .purple
        case "deepseek":
            return .green
        default:
            return .gray
        }
    }
}

struct StatusBadge: View {
    let status: ProviderStatus

    var body: some View {
        Text(status.badgeText)
            .font(.system(size: 9, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(status.tintColor)
            .background(status.tintColor.opacity(0.16), in: Capsule())
    }
}

enum WidgetDeepLink {
    static func provider(_ providerID: String) -> URL {
        URL(string: "quotabar://provider/\(providerID)")!
    }

    static func reauthorize(_ providerID: String) -> URL {
        URL(string: "quotabar://provider/\(providerID)?action=reauthorize")!
    }
}

private extension Array where Element == ProviderQuota {
    var normalizedForWidget: [ProviderQuota] {
        let byID = Dictionary(uniqueKeysWithValues: map { ($0.id, $0) })
        return QuotaTimelineProvider.notConfiguredProviders.map { fallback in
            byID[fallback.id] ?? fallback
        }
    }

    var sortedForWidget: [ProviderQuota] {
        sorted { lhs, rhs in
            if lhs.status.widgetPriority != rhs.status.widgetPriority {
                return lhs.status.widgetPriority > rhs.status.widgetPriority
            }
            return lhs.remainingQuota > rhs.remainingQuota
        }
    }
}

private extension ProviderQuota {
    var progressValue: Double {
        guard totalQuota > 0 else { return 0 }
        return min(max(remainingQuota / totalQuota, 0), 1)
    }

    var remainingText: String {
        switch status {
        case .syncing:
            return "同步中"
        case .notConfigured:
            return "未配置"
        case .sessionExpired:
            return "需要重新授权"
        default:
            return "\(remainingQuota.compactQuotaText) \(unit)"
        }
    }

    var resetText: String {
        guard let resetAt else { return "重置时间待同步" }
        return "重置 \(resetAt.shortDateText)"
    }

    var stateText: String {
        switch status {
        case .syncing:
            return "同步中"
        case .notConfigured:
            return "未配置"
        case .sessionExpired:
            return "重新授权"
        case .syncFailed, .error:
            return "同步失败"
        default:
            return resetAt?.shortDateText ?? "已同步"
        }
    }

    var shortErrorText: String? {
        guard status == .syncFailed || status == .error else { return nil }
        guard let errorMessage, !errorMessage.isEmpty else { return "同步失败" }
        return errorMessage
    }
}

private extension ProviderStatus {
    var badgeText: String {
        switch self {
        case .synced, .active:
            return "SYNCED"
        case .syncing:
            return "SYNCING"
        case .syncFailed, .error:
            return "FAILED"
        case .sessionExpired:
            return "AUTH"
        case .notConfigured:
            return "SETUP"
        case .inactive:
            return "PAUSED"
        case .unknown:
            return "UNKNOWN"
        }
    }

    var tintColor: Color {
        switch self {
        case .synced, .active:
            return .green
        case .syncing:
            return .blue
        case .syncFailed, .error, .sessionExpired:
            return .orange
        case .notConfigured, .inactive, .unknown:
            return .secondary
        }
    }

    var widgetPriority: Int {
        switch self {
        case .sessionExpired:
            return 5
        case .syncFailed, .error:
            return 4
        case .syncing:
            return 3
        case .synced, .active:
            return 2
        case .notConfigured, .inactive, .unknown:
            return 1
        }
    }
}

private extension Date {
    var shortDateText: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var shortTimeText: String {
        formatted(date: .omitted, time: .shortened)
    }
}

private extension Double {
    var compactQuotaText: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", self / 1_000_000)
        }
        if self >= 1_000 {
            return String(format: "%.1fK", self / 1_000)
        }
        if rounded() == self {
            return String(format: "%.0f", self)
        }
        return String(format: "%.2f", self)
    }
}
