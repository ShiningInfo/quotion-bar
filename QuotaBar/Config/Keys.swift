//
//  Keys.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

/// 配置键管理
/// ⚠️ 所有真实凭证必须通过 KeychainStore 存取，禁止硬编码在代码中
public enum ConfigKeys {
    /// App Group 标识符，用于 App 与 Widget 共享数据
    public static let appGroupIdentifier = "group.com.quotiabar.shared"
    
    /// Keychain Service 前缀
    public static let keychainServicePrefix = "com.quotiabar."
    
    /// 快照文件在 App Group 容器中的文件名
    public static let snapshotFilename = "quota_snapshot.json"
}

/// 各平台 API Key 的 Keychain account 名称
/// 实际值通过 KeychainStore 按 service + account 存取
public enum ProviderKeychainAccounts {
    public static let codex = "codex_api_key"
    public static let miniMax = "minimax_api_key"
    public static let deepSeek = "deepseek_api_key"
}
