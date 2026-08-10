//
//  NetModels.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/11.
//

/*
 {
     "item": [
         {
             "name": "New Request",
             "request": {
                 "method": "POST",
                 "header": [],
                 "body": "{\n    \"staffId\": 1098943659,\n    \"rootOrgId\": 130300385,\n    \"sideBusinessType\": \"OPERATION\",\n    \"sideBusinessSubtype\": \"TEST\"\n}",
                 "url":  "http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent"
             },
             "response": []
         }
     ]
 }
 */

import Cocoa

class XYRequest: Model {
    
    /** POST */
    var method: String?
    
    var header: String?
    
    /** {
    "staffId": 1098943659,
    "rootOrgId": 130300385,
    "sideBusinessType": "OPERATION",
    "sideBusinessSubtype": "TEST"
} */    //  需要注意这个字段是个完整的 JSON String
    var body: String?
    
    /** http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent */
    var url: String?
}

class XYItem: Model, Hashable {
    static func == (lhs: XYItem, rhs: XYItem) -> Bool {
        lhs.name != nil && lhs.name == rhs.name
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    /// 请求在历史列表中的唯一标识（业务主键）。
    /// - 展示名称，用户可改；
    /// - `NetworkDataModel.updateHistory(with:)` 按同名覆盖更新，不会并存两条同名记录；
    /// - 列表排序、选中、删除、拖拽排序均以 `name` 定位条目。
    /** New Request */
    var name: String?
    /// 是否锁定，锁定不能移除，防止误删
    var isLock: Bool?
    var request: XYRequest?
    var response: String?
    /// 是否启用请求完成后脚本
    var enablePostScript: Bool?
    /// 请求完成后脚本命令模板
    var postResponseScript: String?
    /// 当前请求选择执行的全局脚本 ID 列表
    var selectedPostScriptIDs: [String]?
    /// 当前请求绑定的全局前置脚本 ID（单选）
    var selectedPreScriptID: String?
    
    func update(with item: XYItem) {
        name = item.name
        isLock = item.isLock
        request = item.request
        response = item.response
        enablePostScript = item.enablePostScript
        postResponseScript = item.postResponseScript
        selectedPostScriptIDs = item.selectedPostScriptIDs
        selectedPreScriptID = item.selectedPreScriptID
    }
}

class MyObj: Model {
    var item: [XYItem]?
}

// MARK: - History tree (v2)

enum HistoryNodeType: String, Codable {
    case group
    case request
}

/// 请求历史树节点（分组 / 请求）
class HistoryNode: Model {
    var id: String?
    var type: String?
    var name: String?
    var collapsed: Bool?
    var children: [HistoryNode]?
    
    var isLock: Bool?
    var request: XYRequest?
    var response: String?
    var enablePostScript: Bool?
    var postResponseScript: String?
    var selectedPostScriptIDs: [String]?
    var selectedPreScriptID: String?
    
    var nodeType: HistoryNodeType {
        get { HistoryNodeType(rawValue: type ?? HistoryNodeType.request.rawValue) ?? .request }
        set { type = newValue.rawValue }
    }
    
    var isGroup: Bool { nodeType == .group }
    var isRequest: Bool { nodeType == .request }
    
    static func newGroup(name: String) -> HistoryNode {
        let node = HistoryNode()
        node.id = UUID().uuidString
        node.type = HistoryNodeType.group.rawValue
        node.name = name
        node.collapsed = false
        node.children = []
        return node
    }
    
    static func fromXYItem(_ item: XYItem) -> HistoryNode {
        let node = HistoryNode()
        node.id = UUID().uuidString
        node.type = HistoryNodeType.request.rawValue
        node.name = item.name
        node.isLock = item.isLock
        node.request = item.request
        node.response = item.response
        node.enablePostScript = item.enablePostScript
        node.postResponseScript = item.postResponseScript
        node.selectedPostScriptIDs = item.selectedPostScriptIDs
        node.selectedPreScriptID = item.selectedPreScriptID
        return node
    }
    
    func toXYItem() -> XYItem {
        let item = XYItem()
        item.name = name
        item.isLock = isLock
        item.request = request
        item.response = response
        item.enablePostScript = enablePostScript
        item.postResponseScript = postResponseScript
        item.selectedPostScriptIDs = selectedPostScriptIDs
        item.selectedPreScriptID = selectedPreScriptID
        return item
    }
    
    func update(with item: XYItem) {
        name = item.name
        isLock = item.isLock
        request = item.request
        response = item.response
        enablePostScript = item.enablePostScript
        postResponseScript = item.postResponseScript
        selectedPostScriptIDs = item.selectedPostScriptIDs
        selectedPreScriptID = item.selectedPreScriptID
    }
}

class HistoryDocument: Model {
    var version: Int?
    var item: [HistoryNode]?
}

// MARK: - Tree helpers

enum HistoryTree {
    
    struct NodeLocation {
        let node: HistoryNode
        let parentId: String?
        let index: Int
    }
    
    static func normalize(_ nodes: inout [HistoryNode]) {
        for i in nodes.indices {
            if nodes[i].id == nil || nodes[i].id?.isEmpty == true {
                nodes[i].id = UUID().uuidString
            }
            if nodes[i].type == nil {
                nodes[i].type = HistoryNodeType.request.rawValue
            }
            if nodes[i].isGroup {
                if nodes[i].children == nil { nodes[i].children = [] }
                normalize(&nodes[i].children!)
            }
        }
    }
    
    static func subtreeContainsRequest(_ node: HistoryNode) -> Bool {
        if node.isRequest { return true }
        guard let children = node.children else { return false }
        return children.contains { subtreeContainsRequest($0) }
    }
    
    static func findNode(id: String, in nodes: [HistoryNode], parentId: String? = nil) -> NodeLocation? {
        for (index, node) in nodes.enumerated() {
            if node.id == id {
                return NodeLocation(node: node, parentId: parentId, index: index)
            }
            if node.isGroup, let children = node.children,
               let found = findNode(id: id, in: children, parentId: node.id) {
                return found
            }
        }
        return nil
    }
    
    static func isDescendant(nodeId: String, of ancestorId: String, in roots: [HistoryNode]) -> Bool {
        guard let ancestor = findNode(id: ancestorId, in: roots)?.node,
              ancestor.isGroup,
              let children = ancestor.children else {
            return false
        }
        func search(_ nodes: [HistoryNode]) -> Bool {
            for node in nodes {
                if node.id == nodeId { return true }
                if node.isGroup, let c = node.children, search(c) { return true }
            }
            return false
        }
        return search(children)
    }
    
    @discardableResult
    static func removeNode(id: String, from nodes: inout [HistoryNode]) -> HistoryNode? {
        for i in nodes.indices {
            if nodes[i].id == id {
                return nodes.remove(at: i)
            }
            if nodes[i].isGroup, var children = nodes[i].children,
               let removed = removeNode(id: id, from: &children) {
                nodes[i].children = children
                return removed
            }
        }
        return nil
    }
    
    static func insertNode(_ node: HistoryNode, parentId: String?, at index: Int, in roots: inout [HistoryNode]) -> Bool {
        if parentId == nil {
            let safeIndex = min(max(0, index), roots.count)
            roots.insert(node, at: safeIndex)
            return true
        }
        guard let location = findNode(id: parentId!, in: roots),
              location.node.isGroup else {
            return false
        }
        var children = location.node.children ?? []
        let safeIndex = min(max(0, index), children.count)
        children.insert(node, at: safeIndex)
        location.node.children = children
        return true
    }
    
    static func allRequestNodes(in nodes: [HistoryNode]) -> [HistoryNode] {
        var result: [HistoryNode] = []
        for node in nodes {
            if node.isRequest {
                result.append(node)
            } else if let children = node.children {
                result.append(contentsOf: allRequestNodes(in: children))
            }
        }
        return result
    }
    
    static func allGroupNames(in nodes: [HistoryNode]) -> [String] {
        var names: [String] = []
        for node in nodes {
            if node.isGroup {
                if let name = node.name { names.append(name) }
                if let children = node.children {
                    names.append(contentsOf: allGroupNames(in: children))
                }
            }
        }
        return names
    }
    
    static func allRequestNames(in nodes: [HistoryNode]) -> [String] {
        allRequestNodes(in: nodes).compactMap(\.name)
    }
    
    static func countLockedRequests(in node: HistoryNode) -> Int {
        if node.isRequest { return (node.isLock == true) ? 1 : 0 }
        return (node.children ?? []).reduce(0) { $0 + countLockedRequests(in: $1) }
    }
    
    static func siblingIds(in nodes: [HistoryNode]) -> [String] {
        nodes.compactMap(\.id)
    }
    
    static func children(of parentId: String?, in roots: [HistoryNode]) -> [HistoryNode] {
        if parentId == nil { return roots }
        return findNode(id: parentId!, in: roots)?.node.children ?? []
    }
    
    static func setChildren(_ children: [HistoryNode], of parentId: String?, in roots: inout [HistoryNode]) {
        if parentId == nil {
            roots = children
            return
        }
        guard let location = findNode(id: parentId!, in: roots) else { return }
        location.node.children = children
    }
}
