//
//  LogPrivacyPlugin.swift
//  XYDevTool
//

import Foundation

/// 本地日志后端插件。返回 nil 可以阻止该条记录落盘。
protocol LogBackendPlugin {
    func process(_ record: LogRecord) -> LogRecord?
}

struct LogSecurityOptions {
    var redactsSensitiveValues: Bool
    var includesRequestBodies: Bool
    var includesResponseBodies: Bool
    var maximumFieldLength: Int
    var redactionText: String
    var omittedText: String
    var sensitiveKeys: Set<String>

    static let `default` = LogSecurityOptions(
        redactsSensitiveValues: true,
        includesRequestBodies: true,
        includesResponseBodies: true,
        maximumFieldLength: 32 * 1_024,
        redactionText: "<redacted>",
        omittedText: "<omitted>",
        sensitiveKeys: [
            "authorization", "cookie", "setcookie", "proxyauthorization", "xapikey",
            "apikey", "accesstoken", "refreshtoken", "token", "password", "passwd",
            "secret", "clientsecret", "sessionid"
        ]
    )
}

/// 默认隐私插件：所有日志在落盘前统一执行脱敏与长度限制。
struct LogPrivacyPlugin: LogBackendPlugin {
    let options: LogSecurityOptions

    init(options: LogSecurityOptions = .default) {
        self.options = options
    }

    func process(_ record: LogRecord) -> LogRecord? {
        var fields = record.fields.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = sanitizeField(key: pair.key, value: pair.value)
        }
        if exceedsMaximumLength(record.fields["requestBody"]) {
            fields["requestBodyTruncated"] = "true"
        }
        if exceedsMaximumLength(record.fields["responseBody"]) {
            fields["responseBodyTruncated"] = "true"
        }

        return LogRecord(
            level: record.level,
            category: record.category,
            name: record.name,
            message: sanitizeText(record.message, fieldKey: "message"),
            traceID: record.traceID,
            result: record.result,
            durationMS: record.durationMS,
            fields: fields
        )
    }

    private func sanitizeField(key: String, value: String) -> String {
        let normalizedKey = normalize(key)

        if normalizedKey.contains("requestbody"), options.includesRequestBodies == false {
            return options.omittedText
        }
        if normalizedKey.contains("responsebody"), options.includesResponseBodies == false {
            return options.omittedText
        }
        if options.redactsSensitiveValues, isSensitiveKey(normalizedKey) {
            return options.redactionText
        }

        return sanitizeText(value, fieldKey: key)
    }

    private func sanitizeText(_ value: String, fieldKey: String) -> String {
        guard value.isEmpty == false else { return value }

        var sanitized = value
        if options.redactsSensitiveValues {
            if normalize(fieldKey).contains("url") {
                sanitized = sanitizeURL(sanitized)
            }
            sanitized = sanitizeJSON(sanitized) ?? sanitizePlainText(sanitized)
        }
        return truncate(sanitized)
    }

    private func sanitizeJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }

        let sanitizedObject = sanitizeJSONObject(object)
        guard JSONSerialization.isValidJSONObject(sanitizedObject),
              let output = try? JSONSerialization.data(withJSONObject: sanitizedObject, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: output, encoding: .utf8)
    }

    private func sanitizeJSONObject(_ object: Any) -> Any {
        if let dictionary = object as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = isSensitiveKey(normalize(pair.key))
                    ? options.redactionText
                    : sanitizeJSONObject(pair.value)
            }
        }
        if let array = object as? [Any] {
            return array.map(sanitizeJSONObject)
        }
        if let string = object as? String {
            return sanitizeURL(string)
        }
        return object
    }

    private func sanitizeURL(_ text: String) -> String {
        guard var components = URLComponents(string: text),
              let queryItems = components.queryItems,
              queryItems.isEmpty == false else {
            return text
        }

        components.queryItems = queryItems.map { item in
            guard isSensitiveKey(normalize(item.name)) else { return item }
            return URLQueryItem(name: item.name, value: options.redactionText)
        }
        return components.string ?? text
    }

    private func sanitizePlainText(_ text: String) -> String {
        var result = text
        let keyPattern = options.sensitiveKeys
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        guard keyPattern.isEmpty == false,
              let expression = try? NSRegularExpression(
                pattern: "(?i)(\\b(?:\(keyPattern))\\b\\s*[:=]\\s*)(?:Bearer\\s+)?[^\\s,;&]+"
              ) else {
            return result
        }

        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = expression.stringByReplacingMatches(
            in: result,
            range: range,
            withTemplate: "$1\(options.redactionText)"
        )
        return result
    }

    private func truncate(_ text: String) -> String {
        guard options.maximumFieldLength > 0, text.count > options.maximumFieldLength else {
            return text
        }
        return String(text.prefix(options.maximumFieldLength)) + "…<truncated>"
    }

    private func exceedsMaximumLength(_ text: String?) -> Bool {
        guard options.maximumFieldLength > 0, let text else { return false }
        return text.count > options.maximumFieldLength
    }

    private func isSensitiveKey(_ normalizedKey: String) -> Bool {
        options.sensitiveKeys.contains(normalizedKey)
    }

    private func normalize(_ key: String) -> String {
        key.lowercased().filter(\.isLetter)
    }
}
