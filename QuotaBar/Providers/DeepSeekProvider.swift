//
//  DeepSeekProvider.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public final class DeepSeekProvider: ProviderProtocol {
    public static let providerID = "deepseek"
    public static let displayName = "DeepSeek"
    public static let keychainService = "quota-bar.deepseek"
    public static let keychainAccount = ProviderKeychainAccounts.deepSeek

    public let id = DeepSeekProvider.providerID
    public let name = DeepSeekProvider.displayName

    private let apiKeyProvider: () -> String?
    private let baseURL: URL
    private let session: URLSession
    private let planType: String?

    public init(
        apiKeyProvider: @escaping () -> String? = {
            KeychainStore.shared.load(
                service: DeepSeekProvider.keychainService,
                account: DeepSeekProvider.keychainAccount
            )
        },
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        session: URLSession = .shared,
        planType: String? = "API Pay-as-you-go"
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.baseURL = baseURL
        self.session = session
        self.planType = planType
    }

    public func fetchQuota() async throws -> ProviderQuota {
        guard let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            return failureQuota(
                status: .sessionExpired,
                message: "DeepSeek API Key 未配置，请重新登录或重新授权"
            )
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/user/balance"))
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return failureQuota(status: .syncFailed, message: "DeepSeek 响应无效")
            }

            switch httpResponse.statusCode {
            case 200:
                return decodeQuota(from: data)
            case 401, 403:
                return failureQuota(
                    status: .sessionExpired,
                    message: "DeepSeek 授权失败，请重新登录或重新授权 (HTTP \(httpResponse.statusCode))"
                )
            default:
                return failureQuota(
                    status: .syncFailed,
                    message: "DeepSeek 同步失败，HTTP \(httpResponse.statusCode)"
                )
            }
        } catch {
            return failureQuota(
                status: .syncFailed,
                message: "DeepSeek 同步失败：\(error.localizedDescription)"
            )
        }
    }

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        QuotaSnapshot(providers: [try await fetchQuota()])
    }

    private func decodeQuota(from data: Data) -> ProviderQuota {
        do {
            let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
            guard let balanceInfo = preferredBalanceInfo(from: response.balanceInfos) else {
                return failureQuota(status: .syncFailed, message: "DeepSeek 余额响应缺少 balance_infos")
            }

            let remaining = balanceInfo.totalBalance.doubleValue
            let granted = balanceInfo.grantedBalance.doubleValue
            let toppedUp = balanceInfo.toppedUpBalance.doubleValue
            let purchasedTotal = granted + toppedUp
            let total = max(purchasedTotal, remaining)
            let used = max(0, total - remaining)

            return ProviderQuota(
                id: id,
                name: name,
                totalQuota: total,
                usedQuota: used,
                unit: balanceInfo.currency,
                status: response.isAvailable ? .active : .inactive,
                planType: planType,
                period: "pay-as-you-go",
                sourceType: "api"
            )
        } catch {
            return failureQuota(
                status: .syncFailed,
                message: "DeepSeek 余额响应解析失败：\(error.localizedDescription)"
            )
        }
    }

    private func preferredBalanceInfo(from balanceInfos: [DeepSeekBalanceInfo]) -> DeepSeekBalanceInfo? {
        balanceInfos.first { $0.currency == "USD" } ?? balanceInfos.first
    }

    private func failureQuota(status: ProviderStatus, message: String) -> ProviderQuota {
        ProviderQuota(
            id: id,
            name: name,
            totalQuota: 0,
            usedQuota: 0,
            unit: "USD",
            status: status,
            planType: planType,
            period: "pay-as-you-go",
            sourceType: "api",
            errorMessage: message
        )
    }
}

private struct DeepSeekBalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [DeepSeekBalanceInfo]

    private enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

private struct DeepSeekBalanceInfo: Decodable {
    let currency: String
    let totalBalance: Decimal
    let grantedBalance: Decimal
    let toppedUpBalance: Decimal

    private enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

private extension KeyedDecodingContainer {
    func decode(_ type: Decimal.Type, forKey key: Key) throws -> Decimal {
        if let stringValue = try? decode(String.self, forKey: key),
           let decimal = Decimal(string: stringValue, locale: Locale(identifier: "en_US_POSIX")) {
            return decimal
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected decimal string or number"
        )
    }
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
