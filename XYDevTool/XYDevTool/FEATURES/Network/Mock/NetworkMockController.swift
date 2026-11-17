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
    
    /// 网络主窗关闭时回调（用于一并关掉文档/Mock 附属窗）
    var onHostWindowWillClose: (() -> Void)?
    
    var conflictCount: Int {
        routes.filter(\.isConflict).count
    }
    
    var enabledRouteCount: Int {
        routes.filter(\.isEnabled).count
    }
    
    var baseURL: String {
        let host = preferences.localhostOnly ? "127.0.0.1" : selectedIP
        return "http://\(host):\(normalizedPortString())"
    }
    
    var matchQuery: Bool { preferences.matchQuery }
    var localhostOnly: Bool { preferences.localhostOnly }
    var delayMS: Int { preferences.delayMS }
    var corsEnabled: Bool { preferences.corsEnabled }
    var assets: [MockAsset] { preferences.assets }
    
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
        pushRuntimeSettings()
    }
    
    func refreshLocalIPs() {
        let ips = Self.localIPv4Addresses()
        localIPs = ips.isEmpty ? ["127.0.0.1"] : ips
        if preferences.localhostOnly {
            selectedIP = "127.0.0.1"
            return
        }
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
            try server.start(
                port: port,
                localhostOnly: preferences.localhostOnly,
                settings: currentRuntimeSettings()
            ) { [weak self] request in
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
                    "routes": String(enabledRouteCount),
                    "localhostOnly": preferences.localhostOnly ? "1" : "0"
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
    
    // MARK: - P2 settings
    
    func setMatchQuery(_ enabled: Bool) {
        preferences.matchQuery = enabled
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func setLocalhostOnly(_ enabled: Bool) {
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }
        preferences.localhostOnly = enabled
        persistPreferences()
        refreshLocalIPs()
        if wasRunning {
            start(with: latestRoots)
        }
    }
    
    func setDelayMS(_ value: Int) {
        preferences.delayMS = max(0, min(value, 30_000))
        persistPreferences()
        pushRuntimeSettings()
    }
    
    func setCorsEnabled(_ enabled: Bool) {
        preferences.corsEnabled = enabled
        persistPreferences()
        pushRuntimeSettings()
    }
    
    // MARK: - Route actions
    
    func setRouteEnabled(_ route: MockRoute, enabled: Bool) {
        if route.isAssetOnly, var asset = asset(forRouteKey: route.routeKey) {
            asset.enabled = enabled
            upsertAsset(asset)
            return
        }
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
        // 同步写入/更新资产，便于批量管理与导出
        if let parsed = MockRouteTable.parseRouteKey(routeKey) {
            upsertAsset(
                MockAsset(
                    id: asset(forRouteKey: routeKey)?.id ?? UUID(),
                    name: asset(forRouteKey: routeKey)?.name
                        ?? routes.first(where: { $0.routeKey == routeKey })?.sourceName
                        ?? "\(parsed.method) \(parsed.path)",
                    method: parsed.method,
                    path: parsed.path,
                    query: parsed.query,
                    enabled: true,
                    statusCode: override.statusCode,
                    contentType: override.contentType,
                    bodyText: override.bodyText
                )
            )
            return
        }
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
    
    // MARK: - Assets (P3)
    
    func asset(forRouteKey key: String) -> MockAsset? {
        preferences.assets.first { $0.routeKey(matchQuery: preferences.matchQuery) == key }
    }
    
    func upsertAsset(_ asset: MockAsset) {
        let key = asset.routeKey(matchQuery: preferences.matchQuery)
        if let index = preferences.assets.firstIndex(where: {
            $0.id == asset.id || $0.routeKey(matchQuery: preferences.matchQuery) == key
        }) {
            preferences.assets[index] = asset
        } else {
            preferences.assets.append(asset)
        }
        // 与旧 override 对齐，避免两套数据打架
        preferences.overrides[key] = MockRouteOverride(
            statusCode: asset.statusCode,
            bodyText: asset.bodyText,
            contentType: asset.contentType
        )
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func deleteAsset(id: UUID) {
        guard let asset = preferences.assets.first(where: { $0.id == id }) else { return }
        let key = asset.routeKey(matchQuery: preferences.matchQuery)
        preferences.assets.removeAll { $0.id == id }
        preferences.overrides.removeValue(forKey: key)
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func replaceAssets(_ assets: [MockAsset]) {
        preferences.assets = assets
        // 重建 overrides 映射
        var nextOverrides: [String: MockRouteOverride] = [:]
        for asset in assets {
            let key = asset.routeKey(matchQuery: preferences.matchQuery)
            nextOverrides[key] = MockRouteOverride(
                statusCode: asset.statusCode,
                bodyText: asset.bodyText,
                contentType: asset.contentType
            )
        }
        preferences.overrides = nextOverrides
        persistPreferences()
        reloadRoutes(from: latestRoots)
    }
    
    func addAsset(from route: MockRoute) {
        let response = resolvedResponse(for: route)
        let bodyText = String(data: response.body, encoding: .utf8) ?? "{}"
        upsertAsset(
            MockAsset(
                name: route.sourceName,
                method: route.method,
                path: route.path,
                query: route.query,
                enabled: true,
                statusCode: response.statusCode,
                contentType: response.contentType,
                bodyText: bodyText
            )
        )
    }
    
    func makeAssetBundle() -> MockAssetBundle {
        let formatter = ISO8601DateFormatter()
        return MockAssetBundle(
            version: MockAssetBundle.currentVersion,
            exportedAt: formatter.string(from: Date()),
            settings: MockAssetBundleSettings(
                matchQuery: preferences.matchQuery,
                localhostOnly: preferences.localhostOnly,
                delayMS: preferences.delayMS,
                corsEnabled: preferences.corsEnabled
            ),
            assets: preferences.assets
        )
    }
    
    func exportAssets(to fileURL: URL) throws {
        let bundle = makeAssetBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: fileURL, options: .atomic)
        logger.event(
            "mock.assets_export",
            result: "success",
            fields: ["count": String(bundle.assets.count)]
        )
    }
    
    enum AssetImportMode {
        case replace
        case merge
    }
    
    func importAssets(from fileURL: URL, mode: AssetImportMode, applySettings: Bool) throws {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let bundle = try decoder.decode(MockAssetBundle.self, from: data)
        guard bundle.version <= MockAssetBundle.currentVersion else {
            throw VariableResolveError(message: "不支持的 Mock 资产版本：\(bundle.version)")
        }
        
        switch mode {
        case .replace:
            preferences.assets = bundle.assets
        case .merge:
            for asset in bundle.assets {
                if let index = preferences.assets.firstIndex(where: {
                    $0.id == asset.id
                        || $0.routeKey(matchQuery: preferences.matchQuery)
                        == asset.routeKey(matchQuery: preferences.matchQuery)
                }) {
                    preferences.assets[index] = asset
                } else {
                    preferences.assets.append(asset)
                }
            }
        }
        
        if applySettings, let settings = bundle.settings {
            if let matchQuery = settings.matchQuery {
                preferences.matchQuery = matchQuery
            }
            if let localhostOnly = settings.localhostOnly {
                preferences.localhostOnly = localhostOnly
            }
            if let delayMS = settings.delayMS {
                preferences.delayMS = max(0, min(delayMS, 30_000))
            }
            if let corsEnabled = settings.corsEnabled {
                preferences.corsEnabled = corsEnabled
            }
        }
        
        // sync overrides
        var nextOverrides = preferences.overrides
        for asset in preferences.assets {
            let key = asset.routeKey(matchQuery: preferences.matchQuery)
            nextOverrides[key] = MockRouteOverride(
                statusCode: asset.statusCode,
                bodyText: asset.bodyText,
                contentType: asset.contentType
            )
        }
        preferences.overrides = nextOverrides
        persistPreferences()
        refreshLocalIPs()
        reloadRoutes(from: latestRoots)
        pushRuntimeSettings()
        logger.event(
            "mock.assets_import",
            result: "success",
            fields: [
                "count": String(bundle.assets.count),
                "mode": mode == .replace ? "replace" : "merge"
            ]
        )
    }
    
    func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    
    func copyBaseURL() {
        copyToPasteboard(baseURL)
    }
    
    func copyPath(for route: MockRoute) {
        copyToPasteboard(route.displayPath)
    }
    
    func copyFullURL(for route: MockRoute) {
        copyToPasteboard("\(baseURL)\(route.displayPath)")
    }
    
    func copyCurl(for route: MockRoute) {
        let url = "\(baseURL)\(route.displayPath)"
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
        onHostWindowWillClose?()
        stop()
    }
    
    // MARK: - Private
    
    private func handle(request: MockHTTPServer.RequestInfo) -> (Int, String, Data, String?) {
        let key = MockRouteTable.routeKey(
            method: request.method,
            path: request.path,
            query: preferences.matchQuery ? request.query : nil
        )
        let logPath = request.pathAndQuery
        
        return DispatchQueue.main.sync {
            if let route = self.routeMap[key], route.isEnabled {
                let response = self.resolvedResponse(for: route)
                let hitLabel: String
                if route.hasAsset || self.asset(forRouteKey: route.routeKey) != nil {
                    let assetName = self.asset(forRouteKey: route.routeKey)?.name ?? route.sourceName
                    hitLabel = "\(assetName) (资产)"
                } else if route.hasCustomOverride {
                    hitLabel = "\(route.sourceName) (自定义)"
                } else {
                    hitLabel = route.sourceName
                }
                self.appendLog(
                    method: request.method,
                    path: logPath,
                    statusCode: response.statusCode,
                    hitName: hitLabel,
                    hint: nil
                )
                self.logger.event(
                    "mock.hit",
                    fields: [
                        "method": request.method,
                        "path": logPath,
                        "name": route.sourceName,
                        "status": String(response.statusCode)
                    ]
                )
                return (response.statusCode, response.contentType, response.body, route.sourceName)
            }
            
            let hint = self.missHint(method: request.method, path: request.path, query: request.query)
            var bodyObject: [String: Any] = [
                "error": "mock_not_found",
                "method": request.method,
                "path": request.path
            ]
            if let query = request.query {
                bodyObject["query"] = query
            }
            if let hint {
                bodyObject["hint"] = hint
            }
            let body = (try? JSONSerialization.data(withJSONObject: bodyObject)) ?? Data(#"{"error":"mock_not_found"}"#.utf8)
            self.appendLog(
                method: request.method,
                path: logPath,
                statusCode: 404,
                hitName: nil,
                hint: hint
            )
            self.logger.event(
                "mock.miss",
                fields: [
                    "method": request.method,
                    "path": logPath
                ]
            )
            return (404, "application/json", body, nil)
        }
    }
    
    private func resolvedResponse(for route: MockRoute) -> (statusCode: Int, contentType: String, body: Data) {
        if let asset = asset(forRouteKey: route.routeKey), asset.enabled {
            let data = asset.bodyText.data(using: .utf8) ?? Data()
            return (asset.statusCode, asset.contentType, data)
        }
        if let override = preferences.overrides[route.routeKey] {
            let data = override.bodyText.data(using: .utf8) ?? Data()
            return (override.statusCode, override.contentType, data)
        }
        if let active = route.activeCandidate {
            return (active.statusCode, active.contentType, active.body)
        }
        return (200, "application/json", Data("{}".utf8))
    }
    
    private func missHint(method: String, path: String, query: String?) -> String? {
        var hints: [String] = []
        
        let methodOthers = routes
            .filter { $0.path == path && $0.method != method && $0.isEnabled }
            .map(\.method)
        if methodOthers.isEmpty == false {
            hints.append("同 path 存在 \(methodOthers.sorted().joined(separator: "/")) 路由，当前是 \(method)")
        }
        
        if preferences.matchQuery {
            let sameMethodPath = routes.filter {
                $0.path == path && $0.method == method && $0.isEnabled
            }
            if sameMethodPath.isEmpty == false {
                let queries = sameMethodPath.compactMap(\.query)
                if queries.isEmpty == false {
                    hints.append("已启用 query 匹配；可试已登记的 query，或关闭「匹配 Query」")
                } else if query != nil {
                    hints.append("路由未带 query，但请求带了 query；可去掉 query 或关闭「匹配 Query」")
                }
            }
        }
        
        guard hints.isEmpty == false else { return nil }
        return hints.joined(separator: "；")
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
        var parts = ["Mock 运行中 · \(enabledRouteCount)/\(routes.count) 条路由"]
        if preferences.localhostOnly {
            parts.append("仅本机")
        }
        if preferences.delayMS > 0 {
            parts.append("延迟 \(preferences.delayMS)ms")
        }
        statusText = parts.joined(separator: " · ")
    }
    
    private func currentRuntimeSettings() -> MockHTTPServer.RuntimeSettings {
        MockHTTPServer.RuntimeSettings(
            delayMS: preferences.delayMS,
            corsEnabled: preferences.corsEnabled,
            matchQuery: preferences.matchQuery
        )
    }
    
    private func pushRuntimeSettings() {
        guard isRunning else { return }
        server.updateRuntimeSettings(currentRuntimeSettings())
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
