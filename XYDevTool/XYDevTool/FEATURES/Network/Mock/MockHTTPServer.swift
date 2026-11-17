//
//  MockHTTPServer.swift
//  XYDevTool
//

import Foundation
import Network

final class MockHTTPServer {
    enum ServerError: LocalizedError {
        case invalidPort
        case alreadyRunning
        case listenerFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidPort:
                return "端口无效，请使用 1–65535"
            case .alreadyRunning:
                return "Mock 服务已在运行"
            case .listenerFailed(let message):
                return message
            }
        }
    }
    
    struct RequestInfo {
        let method: String
        let path: String
        let query: String?
        
        var pathAndQuery: String {
            if let query, query.isEmpty == false {
                return "\(path)?\(query)"
            }
            return path
        }
    }
    
    struct RuntimeSettings {
        var delayMS: Int
        var corsEnabled: Bool
        var matchQuery: Bool
    }
    
    typealias Handler = (_ request: RequestInfo) -> (status: Int, contentType: String, body: Data, hitName: String?)
    
    private let queue = DispatchQueue(label: "com.xydevtool.network.mock.server")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var handler: Handler?
    private var runtime = RuntimeSettings(delayMS: 0, corsEnabled: true, matchQuery: false)
    
    var isRunning: Bool {
        listener != nil
    }
    
    func start(
        port: UInt16,
        localhostOnly: Bool,
        settings: RuntimeSettings,
        handler: @escaping Handler
    ) throws {
        try queue.sync {
            guard listener == nil else { throw ServerError.alreadyRunning }
            guard port > 0 else { throw ServerError.invalidPort }
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                throw ServerError.invalidPort
            }
            
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            if localhostOnly {
                parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                    host: NWEndpoint.Host("127.0.0.1"),
                    port: nwPort
                )
            }
            
            do {
                let listener = try NWListener(using: parameters, on: nwPort)
                self.handler = handler
                self.runtime = settings
                self.listener = listener
                
                listener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .failed(let error):
                        self.queue.async {
                            self.tearDownLocked(reason: error.localizedDescription)
                        }
                    case .cancelled:
                        self.queue.async {
                            self.tearDownLocked(reason: nil)
                        }
                    default:
                        break
                    }
                }
                
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                
                listener.start(queue: queue)
            } catch {
                self.handler = nil
                self.listener = nil
                throw ServerError.listenerFailed(error.localizedDescription)
            }
        }
    }
    
    func updateRuntimeSettings(_ settings: RuntimeSettings) {
        queue.async {
            self.runtime = settings
        }
    }
    
    func stop() {
        queue.sync {
            tearDownLocked(reason: nil)
        }
    }
    
    private func tearDownLocked(reason: String?) {
        listener?.cancel()
        listener = nil
        handler = nil
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        _ = reason
    }
    
    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        queue.async {
            self.connections[id] = connection
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.queue.async {
                    self?.connections[id] = nil
                }
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }
    
    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            
            if let error {
                connection.cancel()
                self.queue.async {
                    self.connections[ObjectIdentifier(connection)] = nil
                }
                _ = error
                return
            }
            
            var nextBuffer = buffer
            if let data, data.isEmpty == false {
                nextBuffer.append(data)
            }
            
            if let headerEnd = nextBuffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = nextBuffer.subdata(in: nextBuffer.startIndex..<headerEnd.lowerBound)
                self.handleRequest(headerData: headerData, connection: connection)
                return
            }
            
            if isComplete {
                if nextBuffer.isEmpty == false {
                    self.handleRequest(headerData: nextBuffer, connection: connection)
                } else {
                    connection.cancel()
                }
                return
            }
            
            if nextBuffer.count > 1024 * 1024 {
                self.send(
                    status: 413,
                    contentType: "application/json",
                    body: Data(#"{"error":"request_too_large"}"#.utf8),
                    on: connection
                )
                return
            }
            
            self.receive(on: connection, buffer: nextBuffer)
        }
    }
    
    private func handleRequest(headerData: Data, connection: NWConnection) {
        guard let headerText = String(data: headerData, encoding: .utf8),
              let requestLine = headerText.split(separator: "\r\n", maxSplits: 1).first else {
            send(
                status: 400,
                contentType: "application/json",
                body: Data(#"{"error":"bad_request"}"#.utf8),
                on: connection
            )
            return
        }
        
        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else {
            send(
                status: 400,
                contentType: "application/json",
                body: Data(#"{"error":"bad_request"}"#.utf8),
                on: connection
            )
            return
        }
        
        let method = parts[0].uppercased()
        let target = parts[1]
        let path = Self.pathOnly(from: target)
        let query = runtime.matchQuery ? Self.queryOnly(from: target) : nil
        
        if method == "OPTIONS" {
            var extra: [String] = []
            if runtime.corsEnabled {
                extra = [
                    "Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS",
                    "Access-Control-Allow-Headers: *"
                ]
            }
            send(
                status: 204,
                contentType: "text/plain",
                body: Data(),
                on: connection,
                extraHeaders: extra
            )
            return
        }
        
        let response: (status: Int, contentType: String, body: Data, hitName: String?)
        if let handler {
            response = handler(RequestInfo(method: method, path: path, query: query))
        } else {
            response = (
                503,
                "application/json",
                Data(#"{"error":"server_unavailable"}"#.utf8),
                nil
            )
        }
        
        let delayMS = max(0, runtime.delayMS)
        if delayMS > 0 {
            Thread.sleep(forTimeInterval: Double(delayMS) / 1000.0)
        }
        
        send(
            status: response.status,
            contentType: response.contentType,
            body: response.body,
            on: connection
        )
    }
    
    private func send(
        status: Int,
        contentType: String,
        body: Data,
        on connection: NWConnection,
        extraHeaders: [String] = []
    ) {
        let reason = Self.reasonPhrase(for: status)
        let resolvedType = Self.contentTypeWithCharset(contentType)
        var lines = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: \(resolvedType)",
            "Content-Length: \(body.count)",
            "Connection: close"
        ]
        if runtime.corsEnabled {
            lines.insert("Access-Control-Allow-Origin: *", at: 3)
        }
        lines.append(contentsOf: extraHeaders)
        lines.append(contentsOf: ["", ""])
        
        var payload = Data(lines.joined(separator: "\r\n").utf8)
        payload.append(body)
        
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    static func pathOnly(from target: String) -> String {
        let withoutQuery = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? target
        if withoutQuery.isEmpty { return "/" }
        if withoutQuery.hasPrefix("http://") || withoutQuery.hasPrefix("https://"),
           let url = URL(string: withoutQuery) {
            let path = url.path.isEmpty ? "/" : url.path
            return MockRouteTable.normalizedPath(from: path) ?? path
        }
        return MockRouteTable.normalizedPath(from: withoutQuery) ?? (withoutQuery.hasPrefix("/") ? withoutQuery : "/" + withoutQuery)
    }
    
    static func queryOnly(from target: String) -> String? {
        if target.hasPrefix("http://") || target.hasPrefix("https://"),
           let url = URL(string: target) {
            return MockRouteTable.normalizedQuery(from: url.absoluteString)
        }
        return MockRouteTable.normalizedQuery(from: target)
    }
    
    private static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 413: return "Payload Too Large"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
    
    /// 手机浏览器对无 charset 的 JSON/文本常按系统默认编码解读，导致中文乱码。
    private static func contentTypeWithCharset(_ contentType: String) -> String {
        let trimmed = contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return "application/json; charset=utf-8"
        }
        let lower = trimmed.lowercased()
        if lower.contains("charset=") {
            return trimmed
        }
        if lower.hasPrefix("application/json")
            || lower.hasPrefix("text/")
            || lower.hasPrefix("application/javascript")
            || lower.hasPrefix("application/xml") {
            return "\(trimmed); charset=utf-8"
        }
        return trimmed
    }
}
