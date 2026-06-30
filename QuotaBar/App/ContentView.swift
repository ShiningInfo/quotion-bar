//
//  ContentView.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProviderConfigurationStore()

    var body: some View {
        NavigationSplitView {
            ProviderListView(
                providers: store.providers,
                selectedProviderId: $store.selectedProviderId
            )
        } detail: {
            if let provider = store.selectedProvider {
                ProviderDetailView(
                    provider: provider,
                    onLogin: { store.openLogin(for: provider.id) },
                    onSync: { store.sync(providerId: provider.id) },
                    onDeleteCredentials: { store.requestCredentialDeletion(for: provider.id) }
                )
            } else {
                ContentUnavailableView("未选择平台", systemImage: "sidebar.left")
            }
        }
        .navigationTitle("Quota Bar")
        .frame(minWidth: 920, minHeight: 620)
        .sheet(item: $store.activeLoginProvider) { provider in
            WebLoginSheet(
                provider: provider,
                onComplete: { store.completeLogin(for: provider.id) },
                onCancel: { store.cancelLogin() }
            )
        }
        .confirmationDialog(
            "删除凭证",
            isPresented: Binding(
                get: { store.pendingCredentialDeletion != nil },
                set: { if !$0 { store.pendingCredentialDeletion = nil } }
            ),
            presenting: store.pendingCredentialDeletion
        ) { provider in
            Button("删除 \(provider.displayName) 凭证", role: .destructive) {
                store.deleteCredentials(for: provider.id)
            }
            Button("取消", role: .cancel) {
                store.pendingCredentialDeletion = nil
            }
        } message: { provider in
            Text("将清空 \(provider.displayName) 在 Keychain 中保存的登录状态。")
        }
        .onOpenURL { url in
            store.openProvider(from: url)
        }
    }
}

private struct ProviderListView: View {
    let providers: [ProviderViewState]
    @Binding var selectedProviderId: String

    var body: some View {
        List(providers, selection: $selectedProviderId) { provider in
            HStack(spacing: 10) {
                Image(systemName: iconName(for: provider.id))
                    .frame(width: 18)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.displayName)
                        .font(.body.weight(.medium))
                    Text(provider.status.displayText)
                        .font(.caption)
                        .foregroundStyle(provider.status.tint)
                }
            }
            .padding(.vertical, 6)
            .tag(provider.id)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
    }

    private func iconName(for providerId: String) -> String {
        switch providerId {
        case ProviderIdentifier.codex:
            return "sparkles"
        case ProviderIdentifier.minimax:
            return "chart.line.uptrend.xyaxis"
        case ProviderIdentifier.deepseek:
            return "magnifyingglass.circle"
        default:
            return "app"
        }
    }
}

private struct ProviderDetailView: View {
    let provider: ProviderViewState
    let onLogin: () -> Void
    let onSync: () -> Void
    let onDeleteCredentials: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(provider.displayName)
                        .font(.largeTitle.weight(.semibold))
                    Text(provider.definition.serviceName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(status: provider.status)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
                GridRow {
                    Text("当前状态")
                        .foregroundStyle(.secondary)
                    Text(provider.status.displayText)
                }
                GridRow {
                    Text("上次同步")
                        .foregroundStyle(.secondary)
                    Text(lastSyncedText)
                }
                GridRow {
                    Text("登录入口")
                        .foregroundStyle(.secondary)
                    Text(provider.loginURL.absoluteString)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("错误信息")
                        .foregroundStyle(.secondary)
                    Text(provider.errorMessage ?? "无")
                        .foregroundColor(provider.errorMessage == nil ? .secondary : .red)
                        .textSelection(.enabled)
                }
            }
            .font(.body)

            HStack(spacing: 12) {
                Button(action: onLogin) {
                    Label(loginButtonTitle, systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onSync) {
                    Label("立即同步", systemImage: "arrow.clockwise")
                }
                .disabled(provider.status == .syncing || provider.status == .notConfigured || provider.status == .needsLogin)

                Button(role: .destructive, action: onDeleteCredentials) {
                    Label("删除凭证", systemImage: "trash")
                }
                .disabled(provider.status == .notConfigured)
            }

            Spacer()
        }
        .padding(32)
    }

    private var loginButtonTitle: String {
        switch provider.status {
        case .notConfigured, .needsLogin:
            return "登录"
        default:
            return "重新授权"
        }
    }

    private var lastSyncedText: String {
        guard let date = provider.lastSyncedAt else { return "未同步" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct StatusBadge: View {
    let status: ProviderStatus

    var body: some View {
        Label(status.displayText, systemImage: status.systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.tint.opacity(0.12), in: Capsule())
    }
}

private extension ProviderStatus {
    var displayText: String {
        switch self {
        case .notConfigured:
            return "not_configured"
        case .needsLogin:
            return "needs_login"
        case .authenticated:
            return "authenticated"
        case .sessionExpired:
            return "session_expired"
        case .syncing:
            return "syncing"
        case .synced:
            return "synced"
        case .syncFailed:
            return "sync_failed"
        }
    }

    var systemImage: String {
        switch self {
        case .notConfigured:
            return "circle"
        case .needsLogin:
            return "person.crop.circle.badge.exclamationmark"
        case .authenticated:
            return "checkmark.seal"
        case .sessionExpired:
            return "clock.badge.exclamationmark"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.circle"
        case .syncFailed:
            return "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .notConfigured:
            return .secondary
        case .needsLogin, .sessionExpired:
            return .orange
        case .authenticated, .synced:
            return .green
        case .syncing:
            return .blue
        case .syncFailed:
            return .red
        }
    }
}

#Preview {
    ContentView()
}
