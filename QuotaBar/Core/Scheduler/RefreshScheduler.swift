//
//  RefreshScheduler.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

/// 后台刷新调度器接口占位
/// 实际调度逻辑由子任务 8 实现
public protocol RefreshSchedulerProtocol {
    func scheduleNextRefresh()
    func cancelAllRefreshTasks()
}

public final class RefreshScheduler: RefreshSchedulerProtocol {
    
    public static let shared = RefreshScheduler()
    
    private init() {}
    
    public func scheduleNextRefresh() {
        // TODO: 子任务 8 实现具体调度逻辑
    }
    
    public func cancelAllRefreshTasks() {
        // TODO: 子任务 8 实现具体取消逻辑
    }
}
