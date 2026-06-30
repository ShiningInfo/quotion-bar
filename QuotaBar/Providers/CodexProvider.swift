//
//  CodexProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation
import WebKit

public final class CodexProvider: PlaceholderProvider {
    public init() {
        super.init(
            providerId: ProviderIdentifier.codex,
            displayName: "Codex",
            planType: "ChatGPT Plus/Codex",
            sourceType: ProviderSourceType.webviewSession
        )
    }
}
