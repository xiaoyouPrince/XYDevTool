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
    var routeKey: String { "\(method) \(path)" }
    
    let method: String
    let path: String
    let candidates: [MockRouteCandidate]
    var selectedSourceId: String
    var isEnabled: Bool
    var hasCustomOverride: Bool
    
    var isConflict: Bool { candidates.count > 1 }
    
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
    
    static let empty = MockPreferences(disabledKeys: [], preferredSourceIds: [:], overrides: [:])
    
    var disabledKeySet: Set<String> {
        Set(disabledKeys)
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
            let assembled = MockResponseAssembler.assemble(from: responseText)
            let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "(unnamed)"
            let key = "\(method) \(path)"
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
            let parts = key.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let method = String(parts[0])
            let path = String(parts[1])
            
            let preferred = preferences.preferredSourceIds[key]
            let selectedId: String
            if let preferred,
               candidates.contains(where: { $0.sourceId == preferred }) {
                selectedId = preferred
            } else {
                selectedId = candidates.last!.sourceId
            }
            
            return MockRoute(
                method: method,
                path: path,
                candidates: candidates,
                selectedSourceId: selectedId,
                isEnabled: disabled.contains(key) == false,
                hasCustomOverride: preferences.overrides[key] != nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.path == rhs.path {
                return lhs.method < rhs.method
            }
            return lhs.path < rhs.path
        }
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
