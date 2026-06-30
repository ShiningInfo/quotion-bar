//
//  MiniMaxParser.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public struct MiniMaxUsageSummary: Equatable {
    public let used: Double
    public let total: Double
    public let remaining: Double?
    public let planType: String
    public let resetAt: Date?
    public let period: String
    public let sourceURL: URL
}

public enum MiniMaxParserError: Error, LocalizedError, Equatable {
    case missingRequiredFields(url: String, selectors: [String], snippet: String)
    case invalidResponse(url: String, snippet: String)

    public var errorDescription: String? {
        switch self {
        case let .missingRequiredFields(url, selectors, snippet):
            return "MiniMax usage parsing failed at \(url). Missing: \(selectors.joined(separator: ", ")). Snippet: \(snippet)"
        case let .invalidResponse(url, snippet):
            return "MiniMax usage response is not recognized at \(url). Snippet: \(snippet)"
        }
    }
}

public struct MiniMaxParser {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func parse(data: Data, responseURL: URL) throws -> MiniMaxUsageSummary {
        if let summary = try parseJSON(data: data, responseURL: responseURL) {
            return summary
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw MiniMaxParserError.invalidResponse(
                url: responseURL.absoluteString,
                snippet: snippet(from: data)
            )
        }

        return try parseHTML(html, responseURL: responseURL)
    }

    public func parseHTML(_ html: String, responseURL: URL) throws -> MiniMaxUsageSummary {
        let text = normalizeText(stripHTML(html))
        let used = firstNumber(in: text, after: ["used tokens", "tokens used", "used", "已使用", "使用量", "已用"])
        let remaining = firstNumber(in: text, after: ["remaining tokens", "tokens remaining", "remaining", "剩余", "可用"])
        var total = firstNumber(in: text, after: ["total tokens", "token quota", "quota", "total", "总量", "总额度", "额度"])

        if total == nil, let used, let remaining {
            total = used + remaining
        }

        guard let used, let total else {
            throw MiniMaxParserError.missingRequiredFields(
                url: responseURL.absoluteString,
                selectors: ["used tokens", "total tokens"],
                snippet: String(text.prefix(240))
            )
        }

        return MiniMaxUsageSummary(
            used: used,
            total: total,
            remaining: remaining,
            planType: firstPlanType(in: text) ?? "Token Plan",
            resetAt: firstResetDate(in: text),
            period: firstPeriod(in: text),
            sourceURL: responseURL
        )
    }

    public func extractAPIHints(from html: String, baseURL: URL) -> [URL] {
        let patterns = [
            #""([^"]*/console/api/[^"]*usage[^"]*)""#,
            #"'([^']*/console/api/[^']*usage[^']*)'"#,
            #""([^"]*/api/[^"]*usage[^"]*)""#,
            #"'([^']*/api/[^']*usage[^']*)'"#
        ]

        var seen = Set<String>()
        var urls: [URL] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in regex.matches(in: html, range: range) {
                guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: html) else { continue }
                let raw = String(html[swiftRange])
                guard let url = URL(string: raw, relativeTo: baseURL)?.absoluteURL else { continue }
                if seen.insert(url.absoluteString).inserted {
                    urls.append(url)
                }
            }
        }

        return urls
    }

    private func parseJSON(data: Data, responseURL: URL) throws -> MiniMaxUsageSummary? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let flattened = flattenJSON(object)
        else {
            return nil
        }

        let used = firstValue(in: flattened, keysContaining: ["used", "usage", "consumed"])
        let remaining = firstValue(in: flattened, keysContaining: ["remaining", "remain", "balance", "left"])
        var total = firstValue(in: flattened, keysContaining: ["total", "quota", "limit"])

        if total == nil, let used, let remaining {
            total = used + remaining
        }

        guard let used, let total else {
            throw MiniMaxParserError.missingRequiredFields(
                url: responseURL.absoluteString,
                selectors: ["used", "total"],
                snippet: snippet(from: data)
            )
        }

        let planType = firstString(in: flattened, keysContaining: ["plan", "package", "subscription"]) ?? "Token Plan"
        let period = firstString(in: flattened, keysContaining: ["period", "cycle"]) ?? "monthly"

        return MiniMaxUsageSummary(
            used: used,
            total: total,
            remaining: remaining,
            planType: planType.isEmpty ? "Token Plan" : planType,
            resetAt: firstDate(in: flattened),
            period: period.isEmpty ? "monthly" : period,
            sourceURL: responseURL
        )
    }

    private func flattenJSON(_ object: Any, prefix: String = "") -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, pair in
                let key = prefix.isEmpty ? pair.key : "\(prefix).\(pair.key)"
                if let nested = flattenJSON(pair.value, prefix: key) {
                    result.merge(nested) { current, _ in current }
                } else {
                    result[key.lowercased()] = pair.value
                }
            }
        }

        if let array = object as? [Any] {
            return array.enumerated().reduce(into: [String: Any]()) { result, pair in
                let key = "\(prefix).\(pair.offset)"
                if let nested = flattenJSON(pair.element, prefix: key) {
                    result.merge(nested) { current, _ in current }
                } else {
                    result[key.lowercased()] = pair.element
                }
            }
        }

        return prefix.isEmpty ? nil : [prefix.lowercased(): object]
    }

    private func firstValue(in values: [String: Any], keysContaining keywords: [String]) -> Double? {
        for keyword in keywords {
            if let match = values.first(where: { $0.key.contains(keyword) }), let number = number(from: match.value) {
                return number
            }
        }
        return nil
    }

    private func firstString(in values: [String: Any], keysContaining keywords: [String]) -> String? {
        for keyword in keywords {
            if let match = values.first(where: { $0.key.contains(keyword) }), let string = match.value as? String {
                return string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func firstDate(in values: [String: Any]) -> Date? {
        for key in ["reset", "renew", "expire", "end"] {
            if let string = firstString(in: values, keysContaining: [key]), let date = parseDate(string) {
                return date
            }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstNumber(in text: String, after labels: [String]) -> Double? {
        for label in labels {
            let pattern = "\(NSRegularExpression.escapedPattern(for: label))\\s*[:：]?\\s*([0-9][0-9,]*(?:\\.[0-9]+)?)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                match.numberOfRanges > 1,
                let numberRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }
            return Double(text[numberRange].replacingOccurrences(of: ",", with: ""))
        }

        return nil
    }

    private func firstPlanType(in text: String) -> String? {
        let patterns = [
            #"(?i)(Token Plan)"#,
            #"套餐\s*[:：]?\s*([A-Za-z0-9 _-]+)"#,
            #"plan\s*[:：]?\s*([A-Za-z0-9 _-]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                match.numberOfRanges > 1,
                let swiftRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }
            return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func firstPeriod(in text: String) -> String {
        if text.range(of: "year", options: .caseInsensitive) != nil || text.contains("年度") {
            return "yearly"
        }
        if text.range(of: "day", options: .caseInsensitive) != nil || text.contains("每日") {
            return "daily"
        }
        return "monthly"
    }

    private func firstResetDate(in text: String) -> Date? {
        let pattern = #"(?i)(?:reset|renew|重置时间|下次重置|到期时间)\s*[:：]?\s*([0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}(?:\s+[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let swiftRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return parseDate(String(text[swiftRange]))
    }

    private func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm", "yyyy/MM/dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    private func number(from value: Any) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let string = value as? String {
            return Double(string.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private func snippet(from data: Data) -> String {
        if let string = String(data: data, encoding: .utf8) {
            return String(string.prefix(240))
        }
        return "<\(data.count) bytes>"
    }
}
