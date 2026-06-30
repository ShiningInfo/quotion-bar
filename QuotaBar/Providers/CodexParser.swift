//
//  CodexParser.swift
//  QuotaBar
//
//  Created by QuotaBar on 2026/06/30.
//

import Foundation

public struct CodexUsageSummary: Equatable {
    public let used: Double
    public let remaining: Double
    public let total: Double?
    public let unit: String
    public let planType: String
    public let resetAt: Date?
    public let period: String
    public let sourceURL: URL
}

public enum CodexParserError: Error, LocalizedError, Equatable {
    case missingRequiredFields(url: String, selectors: [String], snippet: String)
    case invalidResponse(url: String, snippet: String)

    public var errorDescription: String? {
        switch self {
        case let .missingRequiredFields(url, selectors, snippet):
            return "Codex usage parsing failed at \(url). Missing: \(selectors.joined(separator: ", ")). Snippet: \(snippet)"
        case let .invalidResponse(url, snippet):
            return "Codex usage response is not recognized at \(url). Snippet: \(snippet)"
        }
    }
}

public struct CodexParser {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func parse(data: Data, responseURL: URL) throws -> CodexUsageSummary {
        if let summary = try parseJSON(data: data, responseURL: responseURL) {
            return summary
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw CodexParserError.invalidResponse(
                url: responseURL.absoluteString,
                snippet: snippet(from: data)
            )
        }

        return try parseHTML(html, responseURL: responseURL)
    }

    public func parseHTML(_ html: String, responseURL: URL) throws -> CodexUsageSummary {
        let text = normalizeText(stripHTML(html))
        let used = firstNumber(in: text, after: [
            "credits used",
            "used credits",
            "messages used",
            "used messages",
            "used",
            "已使用",
            "已用"
        ])
        let remaining = firstNumber(in: text, after: [
            "credits remaining",
            "remaining credits",
            "messages remaining",
            "remaining messages",
            "remaining",
            "available",
            "剩余",
            "可用"
        ])
        var total = firstNumber(in: text, after: [
            "total credits",
            "credit limit",
            "message limit",
            "total messages",
            "quota",
            "limit",
            "total",
            "额度"
        ])

        if total == nil, let used, let remaining {
            total = used + remaining
        }

        guard let used, let remaining else {
            throw CodexParserError.missingRequiredFields(
                url: responseURL.absoluteString,
                selectors: ["used", "remaining"],
                snippet: String(text.prefix(240))
            )
        }

        return CodexUsageSummary(
            used: used,
            remaining: remaining,
            total: total,
            unit: firstUnit(in: text) ?? "credits",
            planType: firstPlanType(in: text) ?? "ChatGPT Codex",
            resetAt: firstResetDate(in: text),
            period: firstPeriod(in: text),
            sourceURL: responseURL
        )
    }

    public func extractAPIHints(from html: String, baseURL: URL) -> [URL] {
        let patterns = [
            #""([^"]*(?:/api/|/backend-api/)[^"]*(?:codex|billing|usage|credit)[^"]*)""#,
            #"'([^']*(?:/api/|/backend-api/)[^']*(?:codex|billing|usage|credit)[^']*)'"#,
            #"fetch\(\s*["']([^"']+)["']"#,
            #"href=["']([^"']*(?:codex|billing|usage|credit)[^"']*)["']"#
        ]

        var seen = Set<String>()
        var urls: [URL] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in regex.matches(in: html, range: range) {
                guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: html) else { continue }
                let raw = String(html[swiftRange])
                guard shouldConsiderAPIHint(raw), let url = URL(string: raw, relativeTo: baseURL)?.absoluteURL else { continue }
                if seen.insert(url.absoluteString).inserted {
                    urls.append(url)
                }
            }
        }

        return urls
    }

    private func parseJSON(data: Data, responseURL: URL) throws -> CodexUsageSummary? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let flattened = flattenJSON(object)
        else {
            return nil
        }

        let used = firstValue(in: flattened, keysContaining: [
            "used",
            "usage",
            "consumed",
            "spent"
        ])
        let remaining = firstValue(in: flattened, keysContaining: [
            "remaining",
            "remain",
            "available",
            "balance",
            "left"
        ])
        var total = firstValue(in: flattened, keysContaining: [
            "total",
            "quota",
            "limit",
            "cap"
        ])

        if total == nil, let used, let remaining {
            total = used + remaining
        }

        guard let used, let remaining else {
            throw CodexParserError.missingRequiredFields(
                url: responseURL.absoluteString,
                selectors: ["used", "remaining"],
                snippet: snippet(from: data)
            )
        }

        let unit = firstString(in: flattened, keysContaining: ["unit", "metric"]) ?? "credits"
        let planType = firstString(in: flattened, keysContaining: ["plan", "subscription", "tier", "product"]) ?? "ChatGPT Codex"

        return CodexUsageSummary(
            used: used,
            remaining: remaining,
            total: total,
            unit: normalizedUnit(unit),
            planType: planType.isEmpty ? "ChatGPT Codex" : planType,
            resetAt: firstDate(in: flattened),
            period: firstString(in: flattened, keysContaining: ["period", "cycle", "window"]) ?? "unknown",
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
            if let match = values.first(where: { $0.key.contains(keyword) }) {
                if let string = match.value as? String {
                    return string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let number = match.value as? NSNumber {
                    return number.stringValue
                }
            }
        }
        return nil
    }

    private func firstDate(in values: [String: Any]) -> Date? {
        for key in ["reset", "refresh", "renew", "expire", "end"] {
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
            .replacingOccurrences(of: "&#x2F;", with: "/")
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

    private func firstUnit(in text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("message") {
            return "messages"
        }
        if lowercased.contains("credit") {
            return "credits"
        }
        return nil
    }

    private func firstPlanType(in text: String) -> String? {
        let patterns = [
            #"(?i)\b(ChatGPT\s+(?:Plus|Pro|Team|Enterprise))\b"#,
            #"(?i)\b(Plus|Pro|Team|Enterprise)\b"#,
            #"(?i)plan\s*[:：]?\s*([A-Za-z0-9 _-]+)"#,
            #"套餐\s*[:：]?\s*([A-Za-z0-9 _-]+)"#
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

    private func firstResetDate(in text: String) -> Date? {
        let labels = ["next refresh", "refreshes", "resets", "reset", "renews", "expires", "下次刷新", "重置"]
        for label in labels {
            let pattern = "\(NSRegularExpression.escapedPattern(for: label))\\s*[:：]?\\s*([A-Za-z0-9, :+\\-/TZ]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                match.numberOfRanges > 1,
                let dateRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            let candidate = String(text[dateRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let date = parseDate(candidate) {
                return date
            }
        }

        return nil
    }

    private func firstPeriod(in text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("5h") || lowercased.contains("5 h") || lowercased.contains("5-hour") || lowercased.contains("5 hour") {
            return "5h"
        }
        if lowercased.contains("weekly") || lowercased.contains("week") || lowercased.contains("每周") {
            return "weekly"
        }
        return "unknown"
    }

    private func parseDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = TimeInterval(value), seconds > 1_000_000_000 {
            return Date(timeIntervalSince1970: seconds)
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let formats = [
            "yyyy-MM-dd HH:mm:ss ZZZZZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MMM d, yyyy h:mm a",
            "MMM d yyyy h:mm a",
            "MMMM d, yyyy h:mm a"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func number(from value: Any) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            return Double(string.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private func normalizedUnit(_ unit: String) -> String {
        let lowercased = unit.lowercased()
        if lowercased.contains("message") {
            return "messages"
        }
        if lowercased.contains("credit") {
            return "credits"
        }
        return unit.isEmpty ? "credits" : unit
    }

    private func snippet(from data: Data) -> String {
        String(decoding: data.prefix(240), as: UTF8.self)
    }

    private func shouldConsiderAPIHint(_ raw: String) -> Bool {
        let lowercased = raw.lowercased()
        return lowercased.contains("codex")
            || lowercased.contains("usage")
            || lowercased.contains("billing")
            || lowercased.contains("credit")
    }
}
