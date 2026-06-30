//
//  DeepSeekProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public final class DeepSeekProvider: PlaceholderProvider {
    public init() {
        super.init(
            providerId: ProviderIdentifier.deepseek,
            displayName: "DeepSeek",
            planType: "API Pay-as-you-go",
            sourceType: ProviderSourceType.api
        )
    }
}
