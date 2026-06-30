# QuotaBar

Quota Bar 是一个 macOS 原生应用（SwiftUI + WidgetKit），用于聚合 Codex / MiniMax / DeepSeek 三个平台的额度信息，并在桌面 Widget 中实时展示。

## 工程结构

```
QuotaBar/
├── App/                          # 主 App 入口
│   ├── QuotaBarApp.swift         # App 生命周期入口
│   └── ContentView.swift         # 主窗口空白视图（占位）
├── Core/
│   ├── Models/
│   │   └── QuotaSnapshot.swift   # 统一额度数据模型（App ↔ Widget 共享）
│   ├── Storage/
│   │   ├── KeychainStore.swift   # Keychain 读写封装（API Key 安全存储）
│   │   └── SharedSnapshotStore.swift  # App Group 文件共享封装
│   └── Scheduler/
│       └── RefreshScheduler.swift # 后台刷新调度器接口（占位）
├── Providers/
│   └── ProviderProtocol.swift    # 平台 Provider 统一协议（占位）
├── Widget/                       # Widget Extension
│   ├── QuotaBarWidget.swift      # Widget 实现（显示"初始化中"）
│   └── QuotaBarWidgetBundle.swift # Widget Bundle 入口
├── Config/
│   ├── Keys.swift                # 配置键常量（App Group ID、Keychain 前缀等）
│   ├── QuotaBar.entitlements     # 主 App 沙盒与权限配置
│   └── QuotaBarWidget.entitlements # Widget 沙盒与权限配置
├── Tests/
│   ├── QuotaBarTests/            # 主 App 单元测试
│   └── WidgetTests/              # Widget 单元测试
├── .env.example                  # 环境变量示例（真实凭证禁止提交）
└── .gitignore                    # Git 忽略规则
```

## 依赖与构建要求

- **macOS**: 14.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **框架**: SwiftUI, WidgetKit, Security (Keychain)

## 构建步骤

1. 在 Xcode 中打开工程目录（后续需创建 `QuotaBar.xcodeproj`）
2. 选择 `QuotaBar` scheme，按 `⌘R` 运行主 App
3. 选择 `QuotaBarWidgetExtension` scheme，按 `⌘R` 运行 Widget

## App Group 配置

App Group ID: `group.com.quotiabar.shared`

- 主 App Target 和 Widget Extension Target 均需启用同一 App Group
- 共享数据通过 `SharedSnapshotStore` 读写 App Group 容器内的 `quota_snapshot.json`
- 配置位于 `Config/QuotaBar.entitlements` 和 `Config/QuotaBarWidget.entitlements`

## Keychain 配置

- 主 App entitlements 已启用 `com.apple.security.keychain`
- API Key 通过 `KeychainStore` 按 `service + account` 维度存取
- 各平台 Keychain account 名称定义于 `Config/Keys.swift`:
  - `codex_api_key`
  - `minimax_api_key`
  - `deepseek_api_key`

## 安全规范

- **禁止**在代码中硬编码任何真实 API Key 或 Bearer Token
- **禁止**将 `.env` 文件（含真实凭证）提交到 Git
- 运行 `git grep -E 'sk-[a-zA-Z0-9]{20,}|Bearer [a-zA-Z0-9]{20,}'` 应无任何命中
- 所有敏感凭证通过 `KeychainStore` 存取

## 测试

运行单元测试：

```bash
xcodebuild test -scheme QuotaBar -destination 'platform=macOS'
```

测试覆盖：
- `KeychainStore`: save / load / delete / update 基础增删改查
- `SharedSnapshotStore`: 快照编码解码、App Group 原始字符串读写
- `QuotaSnapshot` 模型: 额度计算、JSON 编解码

## 后续任务依赖

| 子任务 | 依赖本任务产出 |
|--------|--------------|
| 子任务 2 (UI/登录) | `App/` 目录、主窗口 |
| 子任务 3 (设置) | `KeychainStore`、`SharedSnapshotStore` |
| 子任务 4/5/6 (Provider) | `ProviderProtocol`、`Core/Models` |
| 子任务 7 (Widget UI) | `Widget/` 目录、`QuotaSnapshot` 模型 |
| 子任务 8 (后台刷新) | `RefreshScheduler` 接口占位 |
