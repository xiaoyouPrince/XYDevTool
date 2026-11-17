//
//  APIDocMarkdownGenerator.swift
//  XYDevTool
//
//  版式对齐常见后台手写说明：标题 / uri / HTTP-Method / 请求参数 / 响应 / 枚举 / 错误码。
//

import Foundation

enum APIDocScope: Equatable {
    case all
    case group(id: String, name: String)
}

enum APIDocMarkdownGenerator {
    static func generate(from roots: [HistoryNode], scope: APIDocScope) -> String {
        let requests: [(groupPath: String, node: HistoryNode)]
        switch scope {
        case .all:
            requests = collectRequests(in: roots, groupPath: [])
        case .group(let id, _):
            if let group = HistoryTree.findNode(id: id, in: roots)?.node, group.isGroup {
                requests = collectRequests(in: group.children ?? [], groupPath: [group.name ?? "未命名分组"])
            } else {
                requests = []
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var lines: [String] = []
        lines.append("# 接口文档")
        lines.append("")
        lines.append("- 生成时间：\(formatter.string(from: Date()))")
        lines.append("- 来源：XYDevTool 网络请求历史")
        switch scope {
        case .all:
            lines.append("- 范围：全部历史")
        case .group(_, let name):
            lines.append("- 范围：分组「\(name)」")
        }
        lines.append("- 说明：版式为「标题 + uri + Method + 带类型注释的 JSON」；中文业务注释、枚举表、错误码需人工补充。")
        lines.append("")
        
        if requests.isEmpty {
            lines.append("> 当前范围内没有可文档化的请求。请先 Submit 并保存带 JSON 的历史记录。")
            lines.append("")
            return lines.joined(separator: "\n")
        }
        
        lines.append("## 目录")
        lines.append("")
        for (index, item) in requests.enumerated() {
            let method = (item.node.request?.method ?? "GET").uppercased()
            let path = pathOnly(from: item.node.request?.url)
            let title = item.node.name ?? "未命名"
            lines.append("\(index + 1). \(title)（\(method) \(path)）")
        }
        lines.append("")
        
        for item in requests {
            lines.append(contentsOf: renderRequest(groupPath: item.groupPath, node: item.node))
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func collectRequests(
        in nodes: [HistoryNode],
        groupPath: [String]
    ) -> [(groupPath: String, node: HistoryNode)] {
        var result: [(groupPath: String, node: HistoryNode)] = []
        for node in nodes {
            if node.isRequest {
                result.append((groupPath.joined(separator: " / "), node))
            } else if node.isGroup {
                let name = node.name ?? "未命名分组"
                result.append(contentsOf: collectRequests(in: node.children ?? [], groupPath: groupPath + [name]))
            }
        }
        return result
    }
    
    private static func renderRequest(groupPath: String, node: HistoryNode) -> [String] {
        let method = (node.request?.method ?? "GET").uppercased()
        let url = node.request?.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let path = pathOnly(from: url)
        let title = displayTitle(node: node, groupPath: groupPath)
        
        var body: [String] = []
        body.append("uri: `\(path)`")
        body.append("")
        body.append("HTTP-Method: `\(method)`")
        body.append("")
        if groupPath.isEmpty == false {
            body.append("分组：\(groupPath)")
            body.append("")
        }
        if url.isEmpty == false, url != path {
            body.append("完整 URL（样本）：`\(url)`")
            body.append("")
        }
        
        let queryItems = queryItems(from: url)
        let bodyText = node.request?.body ?? ""
        let bodyTrimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var requestContent: [String] = []
        if queryItems.isEmpty == false {
            requestContent.append("Query：")
            requestContent.append("")
            requestContent.append("```")
            requestContent.append(contentsOf: annotatedObject(from: queryItems))
            requestContent.append("```")
            requestContent.append("")
        }
        if bodyTrimmed.isEmpty == false {
            if queryItems.isEmpty == false {
                requestContent.append("Body：")
                requestContent.append("")
            }
            requestContent.append(contentsOf: fencedAnnotatedJSON(bodyTrimmed))
        } else if queryItems.isEmpty {
            requestContent.append("> 无请求参数样本。")
            requestContent.append("")
        }
        body.append(contentsOf: foldableSection(
            summary: "请求参数",
            content: requestContent
        ))
        
        let headersText = node.request?.header ?? ""
        if headersText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
           AnnotatedJSONRenderer.render(fromJSONString: headersText) != nil {
            body.append(contentsOf: foldableSection(
                summary: "请求头",
                content: fencedAnnotatedJSON(headersText)
            ))
        }
        
        let responseText = node.response ?? ""
        var responseContent: [String] = []
        if responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let assembled = MockResponseAssembler.assemble(from: responseText)
            let businessText = String(data: assembled.body, encoding: .utf8) ?? ""
            responseContent.append("- HTTP 状态码（样本）：`\(assembled.statusCode)`")
            responseContent.append("- Content-Type（样本）：`\(assembled.contentType)`")
            responseContent.append("")
            if businessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                responseContent.append(contentsOf: fencedAnnotatedJSON(businessText))
            } else {
                responseContent.append("> 响应体为空。")
                responseContent.append("")
            }
        } else {
            responseContent.append("> 尚无响应样本。")
            responseContent.append("")
        }
        body.append(contentsOf: foldableSection(
            summary: "响应",
            content: responseContent
        ))
        
        body.append(contentsOf: foldableSection(
            summary: "枚举说明（待补充）",
            forceCollapsed: true,
            content: [
                "> 历史样本无法自动生成枚举表。请按业务补充，例如：",
                ">",
                "> | 枚举 | 含义 | 单位 |",
                "> | --- | --- | --- |",
                "> | EXAMPLE | 示例 |  |"
            ]
        ))
        
        body.append(contentsOf: foldableSection(
            summary: "错误码（待补充）",
            forceCollapsed: true,
            content: [
                "> 请人工补充，例如：`5207` — 设备尚未注册"
            ]
        ))
        
        var lines: [String] = []
        lines.append("---")
        lines.append("")
        lines.append(contentsOf: foldableSection(
            summary: "\(title) · \(method) \(path)",
            forceCollapsed: true,
            content: body
        ))
        return lines
    }
    
    /// 内容行数超过阈值时默认折叠（与 GitHub `<details>` 一致，导出 md 也可折叠）。
    private static let foldLineThreshold = 12
    
    private static func foldableSection(
        summary: String,
        forceCollapsed: Bool = false,
        content: [String]
    ) -> [String] {
        let substantive = content.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        let open = forceCollapsed == false && substantive.count <= foldLineThreshold
        var lines: [String] = [
            open ? "<details open>" : "<details>",
            "<summary>\(summary)</summary>",
            ""
        ]
        lines.append(contentsOf: content)
        if lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append("</details>")
        lines.append("")
        return lines
    }
    
    private static func displayTitle(node: HistoryNode, groupPath: String) -> String {
        let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty == false {
            return name
        }
        let path = pathOnly(from: node.request?.url)
        if groupPath.isEmpty == false {
            return "\(groupPath) — \(path)"
        }
        return path
    }
    
    private static func fencedAnnotatedJSON(_ text: String) -> [String] {
        var lines: [String] = ["```"]
        if let annotated = AnnotatedJSONRenderer.render(fromJSONString: text) {
            lines.append(annotated)
        } else {
            lines.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        lines.append("```")
        lines.append("")
        return lines
    }
    
    private static func annotatedObject(from queryItems: [(name: String, value: String)]) -> [String] {
        var object: [String: Any] = [:]
        for item in queryItems {
            object[item.name] = item.value
        }
        return AnnotatedJSONRenderer.render(object)
            .components(separatedBy: "\n")
    }
    
    private static func pathOnly(from urlString: String?) -> String {
        guard let urlString, urlString.isEmpty == false else { return "/" }
        return MockRouteTable.normalizedPath(from: urlString) ?? "/"
    }
    
    private static func queryItems(from urlString: String) -> [(name: String, value: String)] {
        guard let normalized = MockRouteTable.normalizedQuery(from: urlString) else { return [] }
        return normalized.split(separator: "&").compactMap { part in
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let name = pair.first.map(String.init), name.isEmpty == false else { return nil }
            let value = pair.count > 1 ? String(pair[1]) : ""
            return (name, value)
        }
    }
}
