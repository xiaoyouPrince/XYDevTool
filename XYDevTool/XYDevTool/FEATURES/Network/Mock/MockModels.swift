//
//  MockModels.swift
//  XYDevTool
//

import Foundation

struct MockRoute: Identifiable, Equatable {
    var id: String { "\(method) \(path)" }
    let method: String
    let path: String
    let sourceName: String
    let sourceId: String
    let statusCode: Int
    let body: Data
    let contentType: String
    let isConflict: Bool
    let overwrittenNames: [String]
}

struct MockAccessLog: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let hitName: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: String,
        path: String,
        statusCode: Int,
        hitName: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.hitName = hitName
    }
}

struct MockAssembledResponse: Equatable {
    let statusCode: Int
    let contentType: String
    let body: Data
}

enum MockRouteTable {
    static func build(from roots: [HistoryNode]) -> [MockRoute] {
        var provisional: [String: (route: MockRoute, names: [String])] = [:]
        
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
            
            var names = provisional[key]?.names ?? []
            if let existing = provisional[key]?.route.sourceName {
                names.append(existing)
            }
            
            let route = MockRoute(
                method: method,
                path: path,
                sourceName: name,
                sourceId: node.id ?? UUID().uuidString,
                statusCode: assembled.statusCode,
                body: assembled.body,
                contentType: assembled.contentType,
                isConflict: false,
                overwrittenNames: []
            )
            provisional[key] = (route, names)
        }
        
        return provisional.values.map { entry in
            var route = entry.route
            let overwritten = entry.names.filter { $0 != route.sourceName }
            if overwritten.isEmpty == false {
                route = MockRoute(
                    method: route.method,
                    path: route.path,
                    sourceName: route.sourceName,
                    sourceId: route.sourceId,
                    statusCode: route.statusCode,
                    body: route.body,
                    contentType: route.contentType,
                    isConflict: true,
                    overwrittenNames: overwritten
                )
            }
            return route
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
