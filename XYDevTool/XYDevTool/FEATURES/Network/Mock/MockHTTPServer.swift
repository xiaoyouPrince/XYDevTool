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
        let headers: [String: String]
        let body: Data
        
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
    
    /// 异步 handler：上游透传等耗时操作在回调里完成后再 `respond`。
    typealias Handler = (
        _ request: RequestInfo,
        _ respond: @escaping (_ status: Int, _ contentType: String, _ body: Data, _ hitName: String?) -> Void
    ) -> Void
    
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
            
            if nextBuffer.count > 8 * 1024 * 1024 {
                self.send(
                    status: 413,
                    contentType: "application/json",
                    body: Data(#"{"error":"request_too_large"}"#.utf8),
                    on: connection
                )
                return
            }
            
            guard let headerEnd = nextBuffer.range(of: Data("\r\n\r\n".utf8)) else {
                if isComplete {
                    if nextBuffer.isEmpty == false {
                        self.finishRequest(raw: nextBuffer, connection: connection)
                    } else {
                        connection.cancel()
                    }
                } else {
                    self.receive(on: connection, buffer: nextBuffer)
                }
                return
            }
            
            let headerData = nextBuffer.subdata(in: nextBuffer.startIndex..<headerEnd.lowerBound)
            let afterHeaders = nextBuffer.subdata(in: headerEnd.upperBound..<nextBuffer.endIndex)
            let contentLength = Self.contentLength(fromHeaderData: headerData) ?? 0
            
            if afterHeaders.count >= contentLength {
                let body = afterHeaders.prefix(contentLength)
                self.finishRequest(headerData: headerData, body: Data(body), connection: connection)
                return
            }
            
            if isComplete {
                self.finishRequest(headerData: headerData, body: afterHeaders, connection: connection)
                return
            }
            
            self.receiveBody(
                on: connection,
                headerData: headerData,
                bodySoFar: afterHeaders,
                expectedLength: contentLength
            )
        }
    }
    
    private func receiveBody(
        on connection: NWConnection,
        headerData: Data,
        bodySoFar: Data,
        expectedLength: Int
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                connection.cancel()
                _ = error
                return
            }
            
            var body = bodySoFar
            if let data, data.isEmpty == false {
                body.append(data)
            }
            
            if body.count > 8 * 1024 * 1024 {
                self.send(
                    status: 413,
                    contentType: "application/json",
                    body: Data(#"{"error":"request_too_large"}"#.utf8),
                    on: connection
                )
                return
            }
            
            if body.count >= expectedLength {
                self.finishRequest(
                    headerData: headerData,
                    body: Data(body.prefix(expectedLength)),
                    connection: connection
                )
                return
            }
            
            if isComplete {
                self.finishRequest(headerData: headerData, body: body, connection: connection)
                return
            }
            
            self.receiveBody(
                on: connection,
                headerData: headerData,
                bodySoFar: body,
                expectedLength: expectedLength
            )
        }
    }
    
    private func finishRequest(raw: Data, connection: NWConnection) {
        if let headerEnd = raw.range(of: Data("\r\n\r\n".utf8)) {
            let headerData = raw.subdata(in: raw.startIndex..<headerEnd.lowerBound)
            let body = raw.subdata(in: headerEnd.upperBound..<raw.endIndex)
            finishRequest(headerData: headerData, body: body, connection: connection)
        } else {
            finishRequest(headerData: raw, body: Data(), connection: connection)
        }
    }
    
    private func finishRequest(headerData: Data, body: Data, connection: NWConnection) {
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            send(
                status: 400,
                contentType: "application/json",
                body: Data(#"{"error":"bad_request"}"#.utf8),
                on: connection
            )
            return
        }
        
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
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
        let query = Self.queryOnly(from: target)
        let headers = Self.parseHeaders(Array(lines.dropFirst()))
        
        if method == "OPTIONS" {
            var extra: [String] = []
            if runtime.corsEnabled {
                extra = [
                    "Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS",
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
        
        let info = RequestInfo(
            method: method,
            path: path,
            query: runtime.matchQuery ? query : nil,
            headers: headers,
            body: body
        )
        
        let respond: (Int, String, Data, String?) -> Void = { [weak self] status, contentType, responseBody, _ in
            guard let self else { return }
            let delayMS = max(0, self.runtime.delayMS)
            let work = {
                self.send(
                    status: status,
                    contentType: contentType,
                    body: responseBody,
                    on: connection
                )
            }
            if delayMS > 0 {
                self.queue.asyncAfter(deadline: .now() + .milliseconds(delayMS), execute: work)
            } else {
                self.queue.async(execute: work)
            }
        }
        
        if let handler {
            handler(info, respond)
        } else {
            respond(503, "application/json", Data(#"{"error":"server_unavailable"}"#.utf8), nil)
        }
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
    
    private static func parseHeaders(_ lines: [String]) -> [String: String] {
        var headers: [String: String] = [:]
        for line in lines {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            guard name.isEmpty == false else { continue }
            headers[name] = value
        }
        return headers
    }
    
    private static func contentLength(fromHeaderData data: Data) -> Int? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, parts[0].lowercased() == "content-length" else { continue }
            return Int(parts[1])
        }
        return nil
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
