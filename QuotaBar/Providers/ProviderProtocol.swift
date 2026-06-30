//
//  ProviderProtocol.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

/// 平台 Provider 统一接口
/// 各平台 Provider（Codex / MiniMax / DeepSeek）需实现此协议
public protocol ProviderProtocol {
    /// Provider 唯一标识
    var id: String { get }
    
    /// Provider 显示名称
    var name: String { get }
    
    /// 从平台 API 获取最新额度信息
    func fetchQuota() async throws -> ProviderQuota
}
