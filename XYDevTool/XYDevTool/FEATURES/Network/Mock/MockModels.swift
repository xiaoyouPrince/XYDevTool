//
//  MockModels.swift
//  XYDevTool
//

import Foundation

struct MockRouteCandidate: Identifiable, Equatable {
    var id: String { sourceId }
    let sourceId: String
    let sourceName: String
    let statusCode: Int
    let body: Data
    let contentType: String
}

struct MockRoute: Identifiable, Equatable {
    var id: String { routeKey }
    
    let method: String
    let path: String
    /// 规范化后的 query（不含 `?`）；未启用 query 匹配时为 nil
    let query: String?
    let routeKey: String
    let candidates: [MockRouteCandidate]
    var selectedSourceId: String
    var isEnabled: Bool
    var hasCustomOverride: Bool
    /// 是否有独立 Mock 资产覆盖此路由
    var hasAsset: Bool
    /// 仅由资产产生、历史中无对应请求
    var isAssetOnly: Bool
    
    var isConflict: Bool { candidates.count > 1 }
    
    var displayPath: String {
        if let query, query.isEmpty == false {
            return "\(path)?\(query)"
        }
        return path
    }
    
    var activeCandidate: MockRouteCandidate? {
        candidates.first(where: { $0.sourceId == selectedSourceId }) ?? candidates.last
    }
    
    var sourceName: String {
        activeCandidate?.sourceName ?? "(unnamed)"
    }
    
    var overwrittenNames: [String] {
        candidates
            .map(\.sourceName)
            .filter { $0 != sourceName }
    }
}

/// 独立于网络历史的 Mock 资产条目（可导入导出、批量编辑）。
struct MockAsset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var method: String
    var path: String
    var query: String?
    var enabled: Bool
    var statusCode: Int
    var contentType: String
    var bodyText: String
    
    init(
        id: UUID = UUID(),
        name: String,
        method: String,
        path: String,
        query: String? = nil,
        enabled: Bool = true,
        statusCode: Int = 200,
        contentType: String = "application/json",
        bodyText: String = "{\n\n}"
    ) {
        self.id = id
        self.name = name
        self.method = method.uppercased()
        self.path = path.hasPrefix("/") ? path : "/" + path
        self.query = query?.nilIfEmpty
        self.enabled = enabled
        self.statusCode = statusCode
        self.contentType = contentType
        self.bodyText = bodyText
    }
    
    func routeKey(matchQuery: Bool) -> String {
        MockRouteTable.routeKey(
            method: method,
            path: path,
            query: matchQuery ? query : nil
        )
    }
}

struct MockAssetBundle: Codable, Equatable {
    var version: Int
    var exportedAt: String
    var settings: MockAssetBundleSettings?
    var assets: [MockAsset]
    
    static let currentVersion = 1
}

struct MockAssetBundleSettings: Codable, Equatable {
    var matchQuery: Bool?
    var localhostOnly: Bool?
    var delayMS: Int?
    var corsEnabled: Bool?
}

struct MockAccessLog: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let hitName: String?
    /// 未命中时的补充说明，例如同 path 存在其它 Method
    let hint: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: String,
        path: String,
        statusCode: Int,
        hitName: String?,
        hint: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.hitName = hitName
        self.hint = hint
    }
}

struct MockAssembledResponse: Equatable {
    let statusCode: Int
    let contentType: String
    let body: Data
}

struct MockRouteOverride: Codable, Equatable {
    var statusCode: Int
    var bodyText: String
    var contentType: String
}

enum MockRouteMode: String, Codable, CaseIterable, Identifiable {
    case cache
    case passthrough
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .cache: return "缓存"
        case .passthrough: return "透传"
        }
    }
}

/// 从透传/缓存响应 JSON 提取变量（P2）
struct MockExtractRule: Identifiable, Codable, Equatable {
    var id: UUID
    var enabled: Bool
    /// 为空表示对所有响应生效；否则仅匹配该 routeKey
    var routeKey: String
    /// 点分路径，如 `data.token`
    var jsonPath: String
    var variableKey: String
    
    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        routeKey: String = "",
        jsonPath: String,
        variableKey: String
    ) {
        self.id = id
        self.enabled = enabled
        self.routeKey = routeKey
        self.jsonPath = jsonPath
        self.variableKey = variableKey
    }
}

struct MockPreferences: Codable, Equatable {
    var disabledKeys: [String]
    var preferredSourceIds: [String: String]
    var overrides: [String: MockRouteOverride]
    var assets: [MockAsset]
    /// 匹配时是否包含 query（默认关闭，仅 Method+Path）
    var matchQuery: Bool
    /// 仅监听 127.0.0.1，不暴露局域网
    var localhostOnly: Bool
    /// 响应延迟（毫秒）
    var delayMS: Int
    /// 是否返回 CORS 头
    var corsEnabled: Bool
    /// 未命中时是否允许透传
    var passthroughEnabled: Bool
    /// 上游 Base URL，如 https://api.example.com
    var upstreamBaseURL: String
    /// 透传超时（毫秒）
    var passthroughTimeoutMS: Int
    /// 透传成功后是否写回历史
    var passthroughWriteBack: Bool
    /// 非 2xx 是否仍写回历史
    var passthroughSaveNon2xx: Bool
    /// 已命中路由的全局默认模式（无逐条覆盖时生效）
    var globalHitMode: String
    /// routeKey → cache|passthrough（逐条覆盖全局）
    var routeModes: [String: String]
    /// 响应抽变量规则
    var extractRules: [MockExtractRule]
    /// 出站 Header 模板：Header 名 → 含 `{{var}}` 的模板
    var outboundHeaderTemplates: [String: String]
    
    static let empty = MockPreferences(
        disabledKeys: [],
        preferredSourceIds: [:],
        overrides: [:],
        assets: [],
        matchQuery: false,
        localhostOnly: false,
        delayMS: 0,
        corsEnabled: true,
        passthroughEnabled: false,
        upstreamBaseURL: "",
        passthroughTimeoutMS: 20_000,
        passthroughWriteBack: true,
        passthroughSaveNon2xx: true,
        globalHitMode: MockRouteMode.cache.rawValue,
        routeModes: [:],
        extractRules: [],
        outboundHeaderTemplates: [:]
    )
    
    var disabledKeySet: Set<String> {
        Set(disabledKeys)
    }
    
    var resolvedGlobalHitMode: MockRouteMode {
        MockRouteMode(rawValue: globalHitMode) ?? .cache
    }
    
    var routeModeOverrideCount: Int {
        routeModes.count
    }
    
    func mode(for routeKey: String) -> MockRouteMode {
        if let raw = routeModes[routeKey], let mode = MockRouteMode(rawValue: raw) {
            return mode
        }
        return resolvedGlobalHitMode
    }
    
    enum CodingKeys: String, CodingKey {
        case disabledKeys
        case preferredSourceIds
        case overrides
        case assets
        case matchQuery
        case localhostOnly
        case delayMS
        case corsEnabled
        case passthroughEnabled
        case upstreamBaseURL
        case passthroughTimeoutMS
        case passthroughWriteBack
        case passthroughSaveNon2xx
        case globalHitMode
        case routeModes
        case extractRules
        case outboundHeaderTemplates
    }
    
    init(
        disabledKeys: [String],
        preferredSourceIds: [String: String],
        overrides: [String: MockRouteOverride],
        assets: [MockAsset],
        matchQuery: Bool,
        localhostOnly: Bool,
        delayMS: Int,
        corsEnabled: Bool,
        passthroughEnabled: Bool,
        upstreamBaseURL: String,
        passthroughTimeoutMS: Int,
        passthroughWriteBack: Bool,
        passthroughSaveNon2xx: Bool,
        globalHitMode: String,
        routeModes: [String: String],
        extractRules: [MockExtractRule],
        outboundHeaderTemplates: [String: String]
    ) {
        self.disabledKeys = disabledKeys
        self.preferredSourceIds = preferredSourceIds
        self.overrides = overrides
        self.assets = assets
        self.matchQuery = matchQuery
        self.localhostOnly = localhostOnly
        self.delayMS = delayMS
        self.corsEnabled = corsEnabled
        self.passthroughEnabled = passthroughEnabled
        self.upstreamBaseURL = upstreamBaseURL
        self.passthroughTimeoutMS = passthroughTimeoutMS
        self.passthroughWriteBack = passthroughWriteBack
        self.passthroughSaveNon2xx = passthroughSaveNon2xx
        self.globalHitMode = globalHitMode
        self.routeModes = routeModes
        self.extractRules = extractRules
        self.outboundHeaderTemplates = outboundHeaderTemplates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        disabledKeys = try container.decodeIfPresent([String].self, forKey: .disabledKeys) ?? []
        preferredSourceIds = try container.decodeIfPresent([String: String].self, forKey: .preferredSourceIds) ?? [:]
        overrides = try container.decodeIfPresent([String: MockRouteOverride].self, forKey: .overrides) ?? [:]
        assets = try container.decodeIfPresent([MockAsset].self, forKey: .assets) ?? []
        matchQuery = try container.decodeIfPresent(Bool.self, forKey: .matchQuery) ?? false
        localhostOnly = try container.decodeIfPresent(Bool.self, forKey: .localhostOnly) ?? false
        delayMS = try container.decodeIfPresent(Int.self, forKey: .delayMS) ?? 0
        corsEnabled = try container.decodeIfPresent(Bool.self, forKey: .corsEnabled) ?? true
        passthroughEnabled = try container.decodeIfPresent(Bool.self, forKey: .passthroughEnabled) ?? false
        upstreamBaseURL = try container.decodeIfPresent(String.self, forKey: .upstreamBaseURL) ?? ""
        passthroughTimeoutMS = try container.decodeIfPresent(Int.self, forKey: .passthroughTimeoutMS) ?? 20_000
        passthroughWriteBack = try container.decodeIfPresent(Bool.self, forKey: .passthroughWriteBack) ?? true
        passthroughSaveNon2xx = try container.decodeIfPresent(Bool.self, forKey: .passthroughSaveNon2xx) ?? true
        globalHitMode = try container.decodeIfPresent(String.self, forKey: .globalHitMode)
            ?? MockRouteMode.cache.rawValue
        routeModes = try container.decodeIfPresent([String: String].self, forKey: .routeModes) ?? [:]
        extractRules = try container.decodeIfPresent([MockExtractRule].self, forKey: .extractRules) ?? []
        outboundHeaderTemplates = try container.decodeIfPresent([String: String].self, forKey: .outboundHeaderTemplates) ?? [:]
    }
}

struct MockPassthroughCapture: Equatable {
    let method: String
    let path: String
    let query: String?
    let requestHeaders: [String: String]
    let requestBody: Data
    let responseText: String
    let statusCode: Int
}

enum MockRouteTable {
    static func build(
        from roots: [HistoryNode],
        preferences: MockPreferences
    ) -> [MockRoute] {
        var provisional: [String: [MockRouteCandidate]] = [:]
        var order: [String] = []
        
        for node in HistoryTree.allRequestNodes(in: roots) {
            guard let responseText = node.response?.trimmingCharacters(in: .whitespacesAndNewlines),
                  responseText.isEmpty == false else {
                continue
            }
            guard let urlString = node.request?.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  urlString.isEmpty == false,
                  let path = normalizedPath(from: urlString) else {
                continue
            }
            
            let method = (node.request?.method ?? "GET").uppercased()
            let query = preferences.matchQuery ? normalizedQuery(from: urlString) : nil
            let key = routeKey(method: method, path: path, query: query)
            let assembled = MockResponseAssembler.assemble(from: responseText)
            let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "(unnamed)"
            let candidate = MockRouteCandidate(
                sourceId: node.id ?? UUID().uuidString,
                sourceName: name,
                statusCode: assembled.statusCode,
                body: assembled.body,
                contentType: assembled.contentType
            )
            
            if provisional[key] == nil {
                order.append(key)
                provisional[key] = [candidate]
            } else {
                provisional[key]?.append(candidate)
            }
        }
        
        let disabled = preferences.disabledKeySet
        var routes = order.compactMap { key -> MockRoute? in
            guard let candidates = provisional[key], candidates.isEmpty == false else { return nil }
            guard let parsed = parseRouteKey(key) else { return nil }
            
            let preferred = preferences.preferredSourceIds[key]
            let selectedId: String
            if let preferred,
               candidates.contains(where: { $0.sourceId == preferred }) {
                selectedId = preferred
            } else {
                selectedId = candidates.last!.sourceId
            }
            
            let asset = preferences.assets.first {
                $0.routeKey(matchQuery: preferences.matchQuery) == key
            }
            
            return MockRoute(
                method: parsed.method,
                path: parsed.path,
                query: parsed.query,
                routeKey: key,
                candidates: candidates,
                selectedSourceId: selectedId,
                isEnabled: disabled.contains(key) == false,
                hasCustomOverride: preferences.overrides[key] != nil,
                hasAsset: asset != nil,
                isAssetOnly: false
            )
        }
        
        let existingKeys = Set(routes.map(\.routeKey))
        for asset in preferences.assets {
            let key = asset.routeKey(matchQuery: preferences.matchQuery)
            if existingKeys.contains(key) { continue }
            let candidate = MockRouteCandidate(
                sourceId: asset.id.uuidString,
                sourceName: asset.name,
                statusCode: asset.statusCode,
                body: Data(asset.bodyText.utf8),
                contentType: asset.contentType
            )
            routes.append(
                MockRoute(
                    method: asset.method,
                    path: asset.path,
                    query: preferences.matchQuery ? asset.query : nil,
                    routeKey: key,
                    candidates: [candidate],
                    selectedSourceId: candidate.sourceId,
                    isEnabled: asset.enabled && disabled.contains(key) == false,
                    hasCustomOverride: preferences.overrides[key] != nil,
                    hasAsset: true,
                    isAssetOnly: true
                )
            )
        }
        
        return routes.sorted { lhs, rhs in
            if lhs.path == rhs.path {
                if lhs.method == rhs.method {
                    return (lhs.query ?? "") < (rhs.query ?? "")
                }
                return lhs.method < rhs.method
            }
            return lhs.path < rhs.path
        }
    }
    
    static func routeKey(method: String, path: String, query: String?) -> String {
        if let query, query.isEmpty == false {
            return "\(method) \(path)?\(query)"
        }
        return "\(method) \(path)"
    }
    
    static func parseRouteKey(_ key: String) -> (method: String, path: String, query: String?)? {
        let parts = key.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let method = String(parts[0])
        let rest = String(parts[1])
        if let index = rest.firstIndex(of: "?") {
            let path = String(rest[..<index])
            let query = String(rest[rest.index(after: index)...])
            return (method, path, query.isEmpty ? nil : query)
        }
        return (method, rest, nil)
    }
    
    static func normalizedPath(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/"), trimmed.contains("://") == false {
            let pathOnly = trimmed.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
            return normalizePathComponents(pathOnly)
        }
        
        guard let url = URL(string: trimmed), url.path.isEmpty == false || trimmed.contains("://") else {
            if trimmed.hasPrefix("/") {
                return normalizePathComponents(trimmed.split(separator: "?").first.map(String.init) ?? trimmed)
            }
            return nil
        }
        
        var path = url.path
        if path.isEmpty {
            path = "/"
        }
        return normalizePathComponents(path)
    }
    
    static func normalizedQuery(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawQuery: String?
        if let url = URL(string: trimmed), trimmed.contains("://") {
            rawQuery = url.query
        } else if let index = trimmed.firstIndex(of: "?") {
            rawQuery = String(trimmed[trimmed.index(after: index)...])
        } else {
            rawQuery = nil
        }
        guard let rawQuery, rawQuery.isEmpty == false else { return nil }
        
        let items = rawQuery
            .split(separator: "&", omittingEmptySubsequences: true)
            .map { part -> (String, String) in
                let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let name = pair.first.map(String.init) ?? ""
                let value = pair.count > 1 ? String(pair[1]) : ""
                return (name, value)
            }
            .sorted { lhs, rhs in
                if lhs.0 == rhs.0 {
                    return lhs.1 < rhs.1
                }
                return lhs.0 < rhs.0
            }
        
        guard items.isEmpty == false else { return nil }
        return items.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }
    
    private static func normalizePathComponents(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/" }
        let withSlash = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        let parts = withSlash.split(separator: "/", omittingEmptySubsequences: true)
        if parts.isEmpty { return "/" }
        return "/" + parts.joined(separator: "/")
    }
}

fileprivate extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
