//
//  XYNetToolLogAdapter.swift
//  XYDevTool
//

import Foundation

/// App 层适配器：消费网络生命周期，并按当前 App 的策略记录本地日志。
final class XYNetToolLogAdapter: XYNetToolDelegate {
    static let shared = XYNetToolLogAdapter()

    private let logger = Logger(category: "network")
    private let maximumBodyLength = 32 * 1_024
    private let sensitiveHeaderNames = [
        "authorization", "cookie", "set-cookie", "proxy-authorization", "x-api-key"
    ]

    private init() {}

    func netToolWillSend(_ request: URLRequest, requestID: String) {
        logger.event(
            "request.started",
            traceID: requestID,
            fields: requestFields(request)
        )
    }

    func netToolDidComplete(
        _ request: URLRequest,
        data: Data?,
        response: URLResponse?,
        error: Error?,
        requestID: String,
        duration: TimeInterval
    ) {
        var fields = requestFields(request)
        fields["durationMs"] = String(format: "%.2f", duration * 1_000)
        fields["mimeType"] = response?.mimeType ?? ""
        fields["responseBytes"] = String(data?.count ?? 0)

        if let httpResponse = response as? HTTPURLResponse {
            fields["statusCode"] = String(httpResponse.statusCode)
            fields["responseHeaders"] = jsonString(redactedHeaders(httpResponse.allHeaderFields))
        }

        if let data {
            let body = bodyText(data)
            fields["responseBody"] = body.value
            fields["responseBodyEncoding"] = body.encoding
            fields["responseBodyTruncated"] = String(body.truncated)
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let failedStatus = statusCode.map { (200 ... 299).contains($0) == false } ?? false
        let isFailure = error != nil || response == nil || failedStatus

        if isFailure {
            fields["error"] = error?.localizedDescription
                ?? (response == nil ? "Invalid response" : "HTTP status code indicates failure")
            logger.event(
                "request.failed",
                level: .error,
                traceID: requestID,
                result: "failure",
                durationMS: duration * 1_000,
                fields: fields
            )
        } else {
            logger.event(
                "request.completed",
                traceID: requestID,
                result: "success",
                durationMS: duration * 1_000,
                fields: fields
            )
        }
    }

    private func requestFields(_ request: URLRequest) -> [String: String] {
        let body = bodyText(request.httpBody)
        return [
            "url": request.url?.absoluteString ?? "",
            "method": request.httpMethod ?? "",
            "headers": jsonString(redactedHeaders(request.allHTTPHeaderFields ?? [:])),
            "requestBody": body.value,
            "requestBodyEncoding": body.encoding,
            "requestBodyTruncated": String(body.truncated),
            "requestBytes": String(request.httpBody?.count ?? 0),
            "timeout": String(request.timeoutInterval)
        ]
    }

    private func redactedHeaders(_ headers: [AnyHashable: Any]) -> [String: String] {
        headers.reduce(into: [:]) { result, pair in
            let key = String(describing: pair.key)
            result[key] = sensitiveHeaderNames.contains(key.lowercased())
                ? "<redacted>"
                : String(describing: pair.value)
        }
    }

    private func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        redactedHeaders(Dictionary(uniqueKeysWithValues: headers.map { (AnyHashable($0.key), $0.value as Any) }))
    }

    private func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func bodyText(_ data: Data?) -> (value: String, encoding: String, truncated: Bool) {
        guard let data, data.isEmpty == false else { return ("", "empty", false) }
        let truncated = data.count > maximumBodyLength
        let visibleData = data.prefix(maximumBodyLength)
        if let text = String(data: visibleData, encoding: .utf8) {
            return (text, "utf8", truncated)
        }
        return (Data(visibleData).base64EncodedString(), "base64", truncated)
    }
}
