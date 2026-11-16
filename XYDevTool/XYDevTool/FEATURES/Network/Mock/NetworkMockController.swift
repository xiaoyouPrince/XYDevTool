//
//  NetworkMockController.swift
//  XYDevTool
//

import AppKit
import Foundation

final class NetworkMockController: NSObject, ObservableObject, NSWindowDelegate {
    @Published var isRunning = false
    @Published var portText = "18080"
    @Published var routes: [MockRoute] = []
    @Published var accessLogs: [MockAccessLog] = []
    @Published var localIPs: [String] = []
    @Published var selectedIP: String = "127.0.0.1"
    @Published var lastError: String?
    @Published var statusText = "Mock 未启动"
    
    private let server = MockHTTPServer()
    private let logger = Logger(category: "network_mock")
    private var routeMap: [String: MockRoute] = [:]
    private let maxLogs = 50
    
    var conflictCount: Int {
        routes.filter(\.isConflict).count
    }
    
    var baseURL: String {
        "http://\(selectedIP):\(normalizedPortString())"
    }
    
    func reloadRoutes(from roots: [HistoryNode]) {
        let built = MockRouteTable.build(from: roots)
        routes = built
        routeMap = Dictionary(uniqueKeysWithValues: built.map { ("\($0.method) \($0.path)", $0) })
        if isRunning {
            statusText = "Mock 运行中 · \(routes.count) 条路由"
        }
    }
    
    func refreshLocalIPs() {
        let ips = Self.localIPv4Addresses()
        localIPs = ips.isEmpty ? ["127.0.0.1"] : ips
        if localIPs.contains(selectedIP) == false {
            selectedIP = localIPs.first(where: { $0 != "127.0.0.1" }) ?? localIPs[0]
        }
    }
    
    func start(with roots: [HistoryNode]) {
        lastError = nil
        refreshLocalIPs()
        reloadRoutes(from: roots)
        
        guard let port = UInt16(normalizedPortString()), port > 0 else {
            lastError = "端口无效"
            statusText = lastError ?? ""
            return
        }
        
        do {
            try server.start(port: port) { [weak self] request in
                self?.handle(request: request) ?? (
                    503,
                    "application/json",
                    Data(#"{"error":"server_unavailable"}"#.utf8),
                    nil
                )
            }
            isRunning = true
            statusText = "Mock 运行中 · \(routes.count) 条路由"
            logger.event(
                "mock.started",
                result: "success",
                fields: [
                    "port": String(port),
                    "routes": String(routes.count)
                ]
            )
        } catch {
            isRunning = false
            lastError = error.localizedDescription
            statusText = "启动失败：\(error.localizedDescription)"
            logger.event(
                "mock.started",
                result: "failure",
                fields: ["error": error.localizedDescription]
            )
        }
    }
    
    func stop() {
        guard isRunning || server.isRunning else { return }
        server.stop()
        isRunning = false
        statusText = "Mock 已停止"
        logger.event("mock.stopped", result: "success")
    }
    
    func copyBaseURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(baseURL, forType: .string)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        stop()
    }
    
    // MARK: - Private
    
    private func handle(request: MockHTTPServer.RequestInfo) -> (Int, String, Data, String?) {
        let key = "\(request.method) \(request.path)"
        
        return DispatchQueue.main.sync {
            if let route = self.routeMap[key] {
                self.appendLog(
                    method: request.method,
                    path: request.path,
                    statusCode: route.statusCode,
                    hitName: route.sourceName
                )
                self.logger.event(
                    "mock.hit",
                    fields: [
                        "method": request.method,
                        "path": request.path,
                        "name": route.sourceName,
                        "status": String(route.statusCode)
                    ]
                )
                return (route.statusCode, route.contentType, route.body, route.sourceName)
            }
            
            let bodyObject: [String: Any] = [
                "error": "mock_not_found",
                "method": request.method,
                "path": request.path
            ]
            let body = (try? JSONSerialization.data(withJSONObject: bodyObject)) ?? Data(#"{"error":"mock_not_found"}"#.utf8)
            self.appendLog(
                method: request.method,
                path: request.path,
                statusCode: 404,
                hitName: nil
            )
            self.logger.event(
                "mock.miss",
                fields: [
                    "method": request.method,
                    "path": request.path
                ]
            )
            return (404, "application/json", body, nil)
        }
    }
    
    private func appendLog(method: String, path: String, statusCode: Int, hitName: String?) {
        let entry = MockAccessLog(
            method: method,
            path: path,
            statusCode: statusCode,
            hitName: hitName
        )
        accessLogs.insert(entry, at: 0)
        if accessLogs.count > maxLogs {
            accessLogs = Array(accessLogs.prefix(maxLogs))
        }
    }
    
    private func normalizedPortString() -> String {
        let trimmed = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "18080" : trimmed
    }
    
    private static func localIPv4Addresses() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return ["127.0.0.1"]
        }
        defer { freeifaddrs(ifaddr) }
        
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = pointer {
            defer { pointer = iface.pointee.ifa_next }
            
            guard let addr = iface.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            let ip = String(cString: hostname)
            if ip.hasPrefix("169.254.") { continue }
            if addresses.contains(ip) == false {
                addresses.append(ip)
            }
        }
        
        if addresses.contains("127.0.0.1") == false {
            addresses.insert("127.0.0.1", at: 0)
        } else if let loopback = addresses.firstIndex(of: "127.0.0.1"), loopback != 0 {
            addresses.remove(at: loopback)
            addresses.insert("127.0.0.1", at: 0)
        }
        return addresses
    }
}
