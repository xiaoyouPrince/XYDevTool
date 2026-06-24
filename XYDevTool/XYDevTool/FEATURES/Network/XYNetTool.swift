//
//  XYNetTool.swift
//  XYUIKit
//
//  Created by 渠晓友 on 2022/4/26.
//

import Foundation

/*
 一个简单的网络工具，统一请求构建、发送和响应解析。
 */

/// 暴露真实网络请求生命周期。Delegate 可用于日志、调试或性能统计，
/// XYNetTool 不关心外部如何使用这些数据。
public protocol XYNetToolDelegate: AnyObject {
    func netToolWillSend(_ request: URLRequest, requestID: String)

    func netToolDidComplete(
        _ request: URLRequest,
        data: Data?,
        response: URLResponse?,
        error: Error?,
        requestID: String,
        duration: TimeInterval
    )
}

public typealias NetTool = XYNetTool
public struct XYNetTool {
    public static weak var delegate: XYNetToolDelegate?

    private init () {}
    
    public typealias AnyJsonCallback = ([String: Any]) -> Void
    public typealias DataCallback = (Data) -> Void
    public typealias ErrorCallback = (_ errMsg: String) -> Void
    public typealias DownloadDataCallback = (_ filePath: URL?, _ error: Error?) -> Void
    public typealias AnyResponseCallback = (NetResponse) -> Void
    
    public enum RequestType: String {
        case GET, POST
    }
    
    public enum ParsedBody {
        case jsonObject([String: Any])
        case jsonArray([Any])
        case text(String)
        case binary(Data)
        case empty
    }
    
    public struct NetResponse {
        public let data: Data
        public let urlResponse: URLResponse
        public let httpResponse: HTTPURLResponse?
        public let statusCode: Int?
        public let mimeType: String?
        public let headers: [AnyHashable: Any]
        public let parsedBody: ParsedBody
        
        public func asDictionary() -> [String: Any] {
            let stringHeaders = headers.reduce(into: [String: String]()) { result, pair in
                result[String(describing: pair.key)] = String(describing: pair.value)
            }
            var result: [String: Any] = [
                "_statusCode": statusCode ?? -1,
                "_mimeType": mimeType ?? "",
                "_headers": stringHeaders
            ]
            
            switch parsedBody {
            case .jsonObject(let dict):
                for (key, value) in dict {
                    result[key] = value
                }
            case .jsonArray(let array):
                result["_jsonArray"] = array
            case .text(let text):
                result["_text"] = text
            case .binary(let data):
                result["_base64"] = data.base64EncodedString()
            case .empty:
                result["_text"] = ""
            }
            return result
        }
    }
    
    public struct RequestOptions {
        public var timeout: TimeInterval
        public var validateStatusCode: Bool
        public var responseParsers: [ResponseParser]
        
        public init(timeout: TimeInterval = 20,
                    validateStatusCode: Bool = false,
                    responseParsers: [ResponseParser] = ResponseParser.defaultParsers) {
            self.timeout = timeout
            self.validateStatusCode = validateStatusCode
            self.responseParsers = responseParsers
        }
        
        public static let `default` = RequestOptions()
    }
    
    public struct ResponseParser {
        let parse: (_ data: Data, _ response: URLResponse) -> ParsedBody?
        
        public init(parse: @escaping (_ data: Data, _ response: URLResponse) -> ParsedBody?) {
            self.parse = parse
        }
        
        public static let defaultParsers: [ResponseParser] = [
            ResponseParser(parse: parseJSONBody),
            ResponseParser(parse: parseTextBody),
            ResponseParser(parse: parseBinaryBody)
        ]
    }
    
    public enum NetError: LocalizedError {
        case invalidURL
        case invalidResponse
        case requestFailed(String)
        case statusCode(Int, String)
        case decodeFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL 无效"
            case .invalidResponse:
                return "响应无效"
            case .requestFailed(let message):
                return message
            case .statusCode(let code, let message):
                return "HTTP \(code): \(message)"
            case .decodeFailed:
                return "响应解析失败"
            }
        }
    }
    
    /// GET 请求，兼容旧接口，返回字典。
    public static func get(url: URL,
                           paramters: [String: Any],
                           headers: [String: String]?,
                           success: @escaping AnyJsonCallback,
                           failure: @escaping ErrorCallback) {
        send(url: url, method: .GET, paramters: paramters, headers: headers, rawBody: nil, options: .default) { result in
            switch result {
            case .success(let response):
                success(response.asDictionary())
            case .failure(let error):
                failure(error.localizedDescription)
            }
        }
    }
    
    /// POST 请求，使用原始 Body 字节（保序，不经 Dictionary 重序列化）。
    public static func post(url: URL,
                            headers: [String: String]?,
                            body: Data,
                            success: @escaping AnyJsonCallback,
                            failure: @escaping ErrorCallback) {
        send(url: url, method: .POST, paramters: [:], headers: headers, rawBody: body, options: .default) { result in
            switch result {
            case .success(let response):
                success(response.asDictionary())
            case .failure(let error):
                failure(error.localizedDescription)
            }
        }
    }
    
    /// POST 请求，兼容旧接口，返回字典。
    public static func post(url: URL,
                            paramters: [String: Any],
                            headers: [String: String]?,
                            success: @escaping AnyJsonCallback,
                            failure: @escaping ErrorCallback) {
        send(url: url, method: .POST, paramters: paramters, headers: headers, rawBody: nil, options: .default) { result in
            switch result {
            case .success(let response):
                success(response.asDictionary())
            case .failure(let error):
                failure(error.localizedDescription)
            }
        }
    }
    
    /// 下载数据，直接返回 Data。
    public static func download(url: URL,
                                paramters: [String: Any],
                                headers: [String: String]?,
                                success: @escaping DataCallback,
                                failure: @escaping ErrorCallback) {
        send(url: url, method: .POST, paramters: paramters, headers: headers, rawBody: nil, options: .default) { result in
            switch result {
            case .success(let response):
                success(response.data)
            case .failure(let error):
                failure(error.localizedDescription)
            }
        }
    }
    
    /// 新增：可拿到结构化响应（状态码、mimeType、headers、解析后的 body）。
    public static func request(url: URL,
                               method: RequestType,
                               paramters: [String: Any],
                               headers: [String: String]?,
                               options: RequestOptions = .default,
                               success: @escaping AnyResponseCallback,
                               failure: @escaping ErrorCallback) {
        send(url: url, method: method, paramters: paramters, headers: headers, rawBody: nil, options: options) { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure(let error):
                failure(error.localizedDescription)
            }
        }
    }
    
    /// 下载文件到指定 URL 地址(GET)。
    public static func download(url: URL,
                                paramters: [String: Any],
                                headers: [String: String]?,
                                saveToUrl: URL,
                                completion: @escaping DownloadDataCallback) {
        let request = buildRequest(url: url, method: .GET, paramters: paramters, headers: headers, timeout: 10)
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let requestID = UUID().uuidString
        let startedAt = ProcessInfo.processInfo.systemUptime
        delegate?.netToolWillSend(request, requestID: requestID)

        session.downloadTask(with: request) { tmpFileUrl, response, error in
            var downloadedURL: URL?
            var completionError = error

            if let tmpFileUrl, completionError == nil {
                do {
                    if FileManager.default.fileExists(atPath: saveToUrl.path) {
                        try FileManager.default.removeItem(at: saveToUrl)
                    }
                    try FileManager.default.moveItem(at: tmpFileUrl, to: saveToUrl)
                    downloadedURL = saveToUrl
                } catch {
                    completionError = error
                }
            } else if completionError == nil {
                completionError = NetError.invalidResponse
            }

            delegate?.netToolDidComplete(
                request,
                data: nil,
                response: response,
                error: completionError,
                requestID: requestID,
                duration: ProcessInfo.processInfo.systemUptime - startedAt
            )

            DispatchQueue.main.async {
                completion(downloadedURL, completionError)
            }
        }.resume()
    }
}

private extension XYNetTool {
    static func send(url: URL,
                     method: RequestType,
                     paramters: [String: Any],
                     headers: [String: String]?,
                     rawBody: Data?,
                     options: RequestOptions,
                     completion: @escaping (Swift.Result<NetResponse, NetError>) -> Void) {
        let request = buildRequest(url: url, method: method, paramters: paramters, headers: headers, timeout: options.timeout, rawBody: rawBody)
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let requestID = UUID().uuidString
        let startedAt = ProcessInfo.processInfo.systemUptime
        delegate?.netToolWillSend(request, requestID: requestID)
        
        session.dataTask(with: request) { data, response, error in
            delegate?.netToolDidComplete(
                request,
                data: data,
                response: response,
                error: error,
                requestID: requestID,
                duration: ProcessInfo.processInfo.systemUptime - startedAt
            )

            let result: Swift.Result<NetResponse, NetError>
            defer {
                DispatchQueue.main.async {
                    completion(result)
                }
            }
            
            if let error = error {
                result = .failure(.requestFailed(error.localizedDescription))
                return
            }
            
            guard let response = response else {
                result = .failure(.invalidResponse)
                return
            }
            
            let body = data ?? Data()
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode

            if options.validateStatusCode,
               let statusCode = statusCode,
               (200 ... 299).contains(statusCode) == false {
                let message = responseText(from: body) ?? "请求失败"
                result = .failure(.statusCode(statusCode, message))
                return
            }
            
            guard let parsedBody = parseBody(data: body, response: response, parsers: options.responseParsers) else {
                result = .failure(.decodeFailed)
                return
            }
            
            result = .success(NetResponse(data: body,
                                          urlResponse: response,
                                          httpResponse: httpResponse,
                                          statusCode: statusCode,
                                          mimeType: response.mimeType,
                                          headers: httpResponse?.allHeaderFields ?? [:],
                                          parsedBody: parsedBody))
        }.resume()
    }
    
    static func buildRequest(url: URL,
                             method: RequestType,
                             paramters: [String: Any],
                             headers: [String: String]?,
                             timeout: TimeInterval,
                             rawBody: Data? = nil) -> URLRequest {
        var requestURL = url
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = method.rawValue
        
        switch method {
        case .GET:
            if paramters.isEmpty == false {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let queryItems = paramters.map { key, value in
                    URLQueryItem(name: key, value: String(describing: value))
                }
                if components?.queryItems?.isEmpty == false {
                    components?.queryItems?.append(contentsOf: queryItems)
                } else {
                    components?.queryItems = queryItems
                }
                if let finalURL = components?.url {
                    requestURL = finalURL
                }
            }
            request.url = requestURL
        case .POST:
            if let rawBody {
                request.httpBody = rawBody
            } else if let data = try? JSONSerialization.data(withJSONObject: paramters, options: .fragmentsAllowed) {
                request.httpBody = data
            } else if let params = paramters as? Encodable, let data = try? JSONEncoder().encode(params) {
                request.httpBody = data
            }
            
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return request
    }
    
    static func parseBody(data: Data,
                          response: URLResponse,
                          parsers: [ResponseParser]) -> ParsedBody? {
        if data.isEmpty {
            return .empty
        }
        
        for parser in parsers {
            if let parsed = parser.parse(data, response) {
                return parsed
            }
        }
        
        return nil
    }
    
    static func responseText(from data: Data) -> String? {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
    }

    static func parseJSONBody(data: Data, response: URLResponse) -> ParsedBody? {
        let mimeType = response.mimeType?.lowercased() ?? ""
        if mimeType.contains("json") == false && mimeType != "text/javascript" {
            return nil
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else {
            return nil
        }
        if let dict = json as? [String: Any] {
            return .jsonObject(dict)
        }
        if let array = json as? [Any] {
            return .jsonArray(array)
        }
        return .text(String(describing: json))
    }
    
    static func parseTextBody(data: Data, response: URLResponse) -> ParsedBody? {
        let mimeType = response.mimeType?.lowercased() ?? ""
        let textLike = mimeType.hasPrefix("text/") || mimeType.contains("xml") || mimeType.contains("html")
        guard textLike else { return nil }
        guard let text = responseText(from: data) else { return nil }
        return .text(text)
    }
    
    static func parseBinaryBody(data: Data, response: URLResponse) -> ParsedBody? {
        _ = response
        return .binary(data)
    }
}
