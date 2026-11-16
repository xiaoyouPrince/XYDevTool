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

struct MockPreferences: Codable, Equatable {
    var disabledKeys: [String]
    var preferredSourceIds: [String: String]
    var overrides: [String: MockRouteOverride]
    /// 匹配时是否包含 query（默认关闭，仅 Method+Path）
    var matchQuery: Bool
    /// 仅监听 127.0.0.1，不暴露局域网
    var localhostOnly: Bool
    /// 响应延迟（毫秒）
    var delayMS: Int
    /// 是否返回 CORS 头
    var corsEnabled: Bool
    
    static let empty = MockPreferences(
        disabledKeys: [],
        preferredSourceIds: [:],
        overrides: [:],
        matchQuery: false,
        localhostOnly: false,
        delayMS: 0,
        corsEnabled: true
    )
    
    var disabledKeySet: Set<String> {
        Set(disabledKeys)
    }
    
    enum CodingKeys: String, CodingKey {
        case disabledKeys
        case preferredSourceIds
        case overrides
        case matchQuery
        case localhostOnly
        case delayMS
        case corsEnabled
    }
    
    init(
        disabledKeys: [String],
        preferredSourceIds: [String: String],
        overrides: [String: MockRouteOverride],
        matchQuery: Bool,
        localhostOnly: Bool,
        delayMS: Int,
        corsEnabled: Bool
    ) {
        self.disabledKeys = disabledKeys
        self.preferredSourceIds = preferredSourceIds
        self.overrides = overrides
        self.matchQuery = matchQuery
        self.localhostOnly = localhostOnly
        self.delayMS = delayMS
        self.corsEnabled = corsEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        disabledKeys = try container.decodeIfPresent([String].self, forKey: .disabledKeys) ?? []
        preferredSourceIds = try container.decodeIfPresent([String: String].self, forKey: .preferredSourceIds) ?? [:]
        overrides = try container.decodeIfPresent([String: MockRouteOverride].self, forKey: .overrides) ?? [:]
        matchQuery = try container.decodeIfPresent(Bool.self, forKey: .matchQuery) ?? false
        localhostOnly = try container.decodeIfPresent(Bool.self, forKey: .localhostOnly) ?? false
        delayMS = try container.decodeIfPresent(Int.self, forKey: .delayMS) ?? 0
        corsEnabled = try container.decodeIfPresent(Bool.self, forKey: .corsEnabled) ?? true
    }
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
        return order.compactMap { key -> MockRoute? in
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
            
            return MockRoute(
                method: parsed.method,
                path: parsed.path,
                query: parsed.query,
                routeKey: key,
                candidates: candidates,
                selectedSourceId: selectedId,
                isEnabled: disabled.contains(key) == false,
                hasCustomOverride: preferences.overrides[key] != nil
            )
        }
        .sorted { lhs, rhs in
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
