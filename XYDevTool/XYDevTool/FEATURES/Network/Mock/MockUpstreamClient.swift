//
//  MockUpstreamClient.swift
//  XYDevTool
//

import Foundation

enum MockUpstreamClient {
    struct Result {
        let statusCode: Int
        let contentType: String
        let body: Data
        let responseHeaders: [String: String]
        let storageResponseText: String
    }
    
    private static let hopByHop: Set<String> = [
        "host", "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
        "te", "trailers", "transfer-encoding", "upgrade", "content-length"
    ]
    
    static func forward(
        request: MockHTTPServer.RequestInfo,
        upstreamBaseURL: String,
        timeout: TimeInterval,
        headerTemplates: [String: String],
        variables: [String: String],
        completion: @escaping (Swift.Result<Result, Error>) -> Void
    ) {
        do {
            let url = try buildURL(base: upstreamBaseURL, path: request.path, query: request.query)
            var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
            urlRequest.httpMethod = request.method
            urlRequest.httpBody = request.body.isEmpty ? nil : request.body
            
            var headers = request.headers
            for (name, template) in headerTemplates {
                headers[name] = renderTemplate(template, variables: variables)
            }
            for (name, value) in headers {
                if hopByHop.contains(name.lowercased()) { continue }
                urlRequest.setValue(value, forHTTPHeaderField: name)
            }
            if let host = url.host {
                let hostValue: String
                if let port = url.port {
                    hostValue = "\(host):\(port)"
                } else {
                    hostValue = host
                }
                urlRequest.setValue(hostValue, forHTTPHeaderField: "Host")
            }
            
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.failure(VariableResolveError(message: "上游返回无效响应")))
                    return
                }
                let body = data ?? Data()
                let contentType = http.value(forHTTPHeaderField: "Content-Type")
                    ?? "application/json"
                var responseHeaders: [String: String] = [:]
                for (key, value) in http.allHeaderFields {
                    responseHeaders[String(describing: key)] = String(describing: value)
                }
                let storage = makeStorageResponseText(
                    statusCode: http.statusCode,
                    mimeType: http.mimeType,
                    headers: responseHeaders,
                    body: body
                )
                completion(.success(Result(
                    statusCode: http.statusCode,
                    contentType: contentType,
                    body: body,
                    responseHeaders: responseHeaders,
                    storageResponseText: storage
                )))
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    static func buildURL(base: String, path: String, query: String?) throws -> URL {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw VariableResolveError(message: "未配置透传上游地址")
        }
        var baseURLString = trimmed
        if baseURLString.hasSuffix("/") {
            baseURLString = String(baseURLString.dropLast())
        }
        guard var components = URLComponents(string: baseURLString) else {
            throw VariableResolveError(message: "上游地址无效")
        }
        if components.scheme == nil {
            components.scheme = "https"
        }
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        let basePath = components.path
        if basePath.isEmpty || basePath == "/" {
            components.path = normalizedPath
        } else {
            let prefix = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
            components.path = prefix + normalizedPath
        }
        if let query, query.isEmpty == false {
            components.percentEncodedQuery = query
        } else {
            components.percentEncodedQuery = nil
        }
        guard let url = components.url else {
            throw VariableResolveError(message: "无法拼接上游 URL")
        }
        return url
    }
    
    static func renderTemplate(_ template: String, variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
    
    /// 简单 JSON 路径：`data.token` / `data.items.0.id`（点分，含数字下标）
    static func value(atPath path: String, in json: Any) -> Any? {
        let parts = path.split(separator: ".").map(String.init).filter { $0.isEmpty == false }
        var current: Any? = json
        for part in parts {
            guard let cur = current else { return nil }
            if let dict = cur as? [String: Any] {
                current = dict[part]
            } else if let array = cur as? [Any], let index = Int(part), array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        return current
    }
    
    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        case is NSNull, .none:
            return nil
        default:
            return String(describing: value!)
        }
    }
    
    private static func makeStorageResponseText(
        statusCode: Int,
        mimeType: String?,
        headers: [String: String],
        body: Data
    ) -> String {
        var result: [String: Any] = [
            "_statusCode": statusCode,
            "_mimeType": mimeType ?? "",
            "_headers": headers
        ]
        if let object = try? JSONSerialization.jsonObject(with: body) {
            if let dict = object as? [String: Any] {
                for (key, value) in dict {
                    result[key] = value
                }
            } else if let array = object as? [Any] {
                result["_jsonArray"] = array
            } else {
                result["_text"] = String(data: body, encoding: .utf8) ?? ""
            }
        } else if let text = String(data: body, encoding: .utf8) {
            result["_text"] = text
        } else {
            result["_base64"] = body.base64EncodedString()
        }
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return String(data: body, encoding: .utf8) ?? ""
        }
        return text
    }
}
