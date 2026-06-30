//
//  KeychainStore.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import Security

/// Keychain 读写封装工具类
/// 按 service + account 维度存取敏感数据（如 API Key）
public final class KeychainStore {
    
    public static let shared = KeychainStore()
    
    private init() {}
    
    // MARK: - Save
    
    @discardableResult
    public func save(
        token: String,
        service: String,
        account: String
    ) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        
        // 先删除已有项，避免重复
        delete(service: service, account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Load
    
    public func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    // MARK: - Delete
    
    @discardableResult
    public func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Update
    
    @discardableResult
    public func update(
        token: String,
        service: String,
        account: String
    ) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        // 如果 item 不存在，则执行新增
        if status == errSecItemNotFound {
            return save(token: token, service: service, account: account)
        }
        
        return status == errSecSuccess
    }
}
