//
//  MiniMaxProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public final class MiniMaxProvider: PlaceholderProvider {
    public init() {
        super.init(
            providerId: ProviderIdentifier.minimax,
            displayName: "MiniMax",
            planType: "Token Plan",
            sourceType: ProviderSourceType.api
        )
    }
}
