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
    @Published private(set) var preferences = MockPreferences.empty
    
    private let server = MockHTTPServer()
    private let logger = Logger(category: "network_mock")
    private var routeMap: [String: MockRoute] = [:]
    private var latestRoots: [HistoryNode] = []
    private let maxLogs = 50
    private let preferencesKey = "xydev.network.mockPreferences"
    
    var conflictCount: Int {
        routes.filter(\.isConflict).count
    }
    
    var enabledRouteCount: Int {
        routes.filter(\.isEnabled).count
    }
    
    var baseURL: String {
        "http://\(selectedIP):\(normalizedPortString())"
    }
    
    override init() {
        super.init()
        preferences = loadPreferences()
    }
    
    func reloadRoutes(from roots: [HistoryNode]) {
        latestRoots = roots
        let built = MockRouteTable.build(from: roots, preferences: preferences)
        routes = built
        routeMap = Dictionary(uniqueKeysWithValues: built.map { ($0.routeKey, $0) })
        refreshStatusText()
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
            refreshStatusText()
            logger.event(
                "mock.started",
                result: "success",
                fields: [
                    "port": String(port),
                    "routes": String(enabledRouteCount)
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
    
    // MARK: - Route actions
    
    func setRouteEnabled(_ route: MockRoute, enabled: Bool) {
        var disabled = preferences.disabledKeySet
        if enabled {
            disabled.remove(route.routeKey)
        } else {
            disabled.insert(route.routeKey)
        }
        preferences.disabledKeys = Array(disabled).sorted()
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func selectConflictWinner(routeKey: String, sourceId: String) {
        preferences.preferredSourceIds[routeKey] = sourceId
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func saveOverride(routeKey: String, override: MockRouteOverride) {
        preferences.overrides[routeKey] = override
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func clearOverride(routeKey: String) {
        preferences.overrides.removeValue(forKey: routeKey)
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func override(for routeKey: String) -> MockRouteOverride? {
        preferences.overrides[routeKey]
    }
    
    func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    
    func copyBaseURL() {
        copyToPasteboard(baseURL)
    }
    
    func copyPath(for route: MockRoute) {
        copyToPasteboard(route.path)
    }
    
    func copyFullURL(for route: MockRoute) {
        copyToPasteboard("\(baseURL)\(route.path)")
    }
    
    func copyCurl(for route: MockRoute) {
        let url = "\(baseURL)\(route.path)"
        let curl: String
        if route.method == "GET" {
            curl = "curl -X GET '\(url)'"
        } else {
            curl = "curl -X \(route.method) '\(url)' -H 'Content-Type: application/json' -d '{}'"
        }
        copyToPasteboard(curl)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        stop()
    }
    
    // MARK: - Private
    
    private func handle(request: MockHTTPServer.RequestInfo) -> (Int, String, Data, String?) {
        let key = "\(request.method) \(request.path)"
        
        return DispatchQueue.main.sync {
            if let route = self.routeMap[key], route.isEnabled {
                let response = self.resolvedResponse(for: route)
                self.appendLog(
                    method: request.method,
                    path: request.path,
                    statusCode: response.statusCode,
                    hitName: route.hasCustomOverride ? "\(route.sourceName) (自定义)" : route.sourceName,
                    hint: nil
                )
                self.logger.event(
                    "mock.hit",
                    fields: [
                        "method": request.method,
                        "path": request.path,
                        "name": route.sourceName,
                        "status": String(response.statusCode)
                    ]
                )
                return (response.statusCode, response.contentType, response.body, route.sourceName)
            }
            
            let hint = self.methodMismatchHint(method: request.method, path: request.path)
            var bodyObject: [String: Any] = [
                "error": "mock_not_found",
                "method": request.method,
                "path": request.path
            ]
            if let hint {
                bodyObject["hint"] = hint
            }
            let body = (try? JSONSerialization.data(withJSONObject: bodyObject)) ?? Data(#"{"error":"mock_not_found"}"#.utf8)
            self.appendLog(
                method: request.method,
                path: request.path,
                statusCode: 404,
                hitName: nil,
                hint: hint
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
    
    private func resolvedResponse(for route: MockRoute) -> (statusCode: Int, contentType: String, body: Data) {
        if let override = preferences.overrides[route.routeKey] {
            let data = override.bodyText.data(using: .utf8) ?? Data()
            return (override.statusCode, override.contentType, data)
        }
        if let active = route.activeCandidate {
            return (active.statusCode, active.contentType, active.body)
        }
        return (200, "application/json", Data("{}".utf8))
    }
    
    private func methodMismatchHint(method: String, path: String) -> String? {
        let others = routes
            .filter { $0.path == path && $0.method != method && $0.isEnabled }
            .map(\.method)
        guard others.isEmpty == false else { return nil }
        let joined = others.sorted().joined(separator: "/")
        return "同 path 存在 \(joined) 路由，当前请求是 \(method)"
    }
    
    private func appendLog(
        method: String,
        path: String,
        statusCode: Int,
        hitName: String?,
        hint: String?
    ) {
        let entry = MockAccessLog(
            method: method,
            path: path,
            statusCode: statusCode,
            hitName: hitName,
            hint: hint
        )
        accessLogs.insert(entry, at: 0)
        if accessLogs.count > maxLogs {
            accessLogs = Array(accessLogs.prefix(maxLogs))
        }
    }
    
    private func refreshStatusText() {
        guard isRunning else {
            if statusText.hasPrefix("启动失败") == false {
                statusText = "Mock 未启动"
            }
            return
        }
        statusText = "Mock 运行中 · \(enabledRouteCount)/\(routes.count) 条路由"
    }
    
    private func normalizedPortString() -> String {
        let trimmed = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "18080" : trimmed
    }
    
    private func loadPreferences() -> MockPreferences {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let decoded = try? JSONDecoder().decode(MockPreferences.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func persistPreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: preferencesKey)
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
