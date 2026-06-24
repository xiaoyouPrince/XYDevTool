//
//  NetworkDataModel.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import Foundation
import SwiftUI
import Observation

struct NetworkVariable: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var key: String = ""
    var value: String = ""
}

struct NetworkVariablePreview: Identifiable, Equatable {
    let id: String
    let key: String
    let resolvedValue: String
}

struct VariableResolveError: Error, LocalizedError, Equatable {
    let message: String
    
    var errorDescription: String? {
        message
    }
}

struct GlobalPostScript: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var command: String = ""
}

struct GlobalPreScript: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var command: String = ""
}

private struct PreScriptRunResult {
    var url: String?
    var method: HttpMethod?
    var headers: [String: String]?
    /// POST 原始 Body 文本（保序，直接写入 httpBody）
    var bodyText: String?
    var parameters: [String: Any]?
    var response: String?
    var error: String?
    
    /// 脚本是否显式返回了 url（GET 签名场景应返回完整 URL，不再拼 query）
    var urlOverridden: Bool = false
    
    static func unchanged() -> PreScriptRunResult {
        PreScriptRunResult()
    }
}

/// 历史列表专用 UI 状态，与编辑区字段分离，避免选中时整表重绘。
@Observable
final class HistoryListUIStore {
    var selectedId: String?
    var requestCount: Int = 0
    /// 树结构变更时递增，供 AppKit Outline 触发 reloadData。
    var treeRevision: Int = 0
}

/// 请求编辑区状态，与历史列表分离，避免加载表单时触发列表重绘。
@Observable
final class NetworkEditorStore {
    var requesName: String = ""
    var isLock: Bool = true {
        didSet {
            guard isApplyingState == false else { return }
            onLockChanged?()
        }
    }
    var urlString: String = ""
    var httpMethod: HttpMethod = .get
    var httpHeaders: String = ""
    var httpParameters: String = ""
    var httpResponse: String = ""
    var selectedPostScriptIDsForCurrent: [String] = [] {
        didSet {
            guard isApplyingState == false else { return }
            onScriptsChanged?()
        }
    }
    var selectedPreScriptIDForCurrent: String? {
        didSet {
            guard isApplyingState == false else { return }
            onPreScriptChanged?()
        }
    }
    
    fileprivate var isApplyingState = false
    fileprivate var onLockChanged: (() -> Void)?
    fileprivate var onScriptsChanged: (() -> Void)?
    fileprivate var onPreScriptChanged: (() -> Void)?
    
    /// 先加载轻量字段，让顶栏立刻刷新。
    fileprivate func loadMetadata(from node: HistoryNode) {
        isApplyingState = true
        requesName = node.name ?? ""
        isLock = node.isLock ?? true
        urlString = node.request?.url ?? ""
        httpMethod = HttpMethod(rawValue: node.request?.method?.lowercased() ?? "") ?? .get
        selectedPostScriptIDsForCurrent = node.selectedPostScriptIDs ?? []
        selectedPreScriptIDForCurrent = node.selectedPreScriptID
        isApplyingState = false
    }
    
    /// 大段 JSON 延后加载，避免阻塞选中高亮。
    fileprivate func loadTextContent(from node: HistoryNode) {
        isApplyingState = true
        httpHeaders = node.request?.header ?? ""
        httpParameters = node.request?.body ?? ""
        httpResponse = node.response ?? ""
        isApplyingState = false
    }
    
    fileprivate func load(from node: HistoryNode) {
        loadMetadata(from: node)
        loadTextContent(from: node)
    }
}

class NetworkDataModel: ObservableObject, BaseDataProtocol {
    
    /// 历史列表行内上下 padding、行尾删除按钮边长
    static let historyRowVerticalPadding: CGFloat = 3
    static let historyRowAccessorySize: CGFloat = 22
    
    /// 行内容撑开的最小高度，低于此值背景会重叠
    static var historyRowMinHeight: CGFloat {
        historyRowAccessorySize + historyRowVerticalPadding * 2
    }
    
    let editor = NetworkEditorStore()
    var historyRoots: [HistoryNode] = []
    private(set) var selectedId: String?
    @Published var status: String = "Ready"
    
    /// 非 @Published：选中切换时不触发整窗 EnvironmentObject 刷新。
    private(set) var currentHistory: HistoryNode?
    
    /// 名称区每加深一层缩进（pt）
    let historyIndentPerLevel: CGFloat = 12
    
    @Published var globalPostScripts: [GlobalPostScript] = [] {
        didSet {
            saveGlobalPostScripts()
            sanitizeSelectedScriptReferences()
        }
    }
    @Published var globalPreScripts: [GlobalPreScript] = [] {
        didSet {
            saveGlobalPreScripts()
            sanitizeSelectedPreScriptReferences()
        }
    }
    @Published var variables: [NetworkVariable] = [] {
        didSet {
            saveVariables()
        }
    }
    
    private let variablesStoreKey = "xydev.network.variables"
    private let globalPostScriptsStoreKey = "xydev.network.globalPostScripts"
    private let globalPreScriptsStoreKey = "xydev.network.globalPreScripts"
    private let exportHistoryFileName = "network_history.json"
    private let exportVariablesFileName = "network_variables.json"
    private let exportGlobalScriptsFileName = "network_global_scripts.json"
    private let exportGlobalPreScriptsFileName = "network_global_pre_scripts.json"
    
    let historyListUI = HistoryListUIStore()
    lazy var historyActions = HistoryListActions(model: self)
    private var historyPersistToken = UUID()
    private var selectionGeneration = 0
    
    init() {
        editor.onLockChanged = { [weak self] in self?.syncLockToSelectedRequest() }
        editor.onScriptsChanged = { [weak self] in self?.syncCurrentScriptSelection() }
        editor.onPreScriptChanged = { [weak self] in self?.syncCurrentPreScriptSelection() }
        loadHistoryFromDisk()
        refreshHistoryListUI()
        loadVariables()
        loadGlobalPostScripts()
        loadGlobalPreScripts()
    }
    
    var selectedNode: HistoryNode? {
        guard let selectedId else { return nil }
        return HistoryTree.findNode(id: selectedId, in: historyRoots)?.node
    }
}

extension NetworkDataModel {
    func exportNetworkConfigs(to folderURL: URL) throws {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let historyItems = historyRoots.compactMap { $0.toDictionary() }
        let historyDict: [String: Any] = ["version": 2, "item": historyItems]
        let historyData = try JSONSerialization.data(withJSONObject: historyDict, options: [.prettyPrinted, .sortedKeys])
        try historyData.write(to: folderURL.appendingPathComponent(exportHistoryFileName), options: .atomic)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let variablesData = try encoder.encode(variables)
        try variablesData.write(to: folderURL.appendingPathComponent(exportVariablesFileName), options: .atomic)
        
        let scriptsData = try encoder.encode(globalPostScripts)
        try scriptsData.write(to: folderURL.appendingPathComponent(exportGlobalScriptsFileName), options: .atomic)
        
        let preScriptsData = try encoder.encode(globalPreScripts)
        try preScriptsData.write(to: folderURL.appendingPathComponent(exportGlobalPreScriptsFileName), options: .atomic)
    }
    
    func importNetworkConfigs(from folderURL: URL) throws {
        let historyURL = folderURL.appendingPathComponent(exportHistoryFileName)
        let variablesURL = folderURL.appendingPathComponent(exportVariablesFileName)
        let scriptsURL = folderURL.appendingPathComponent(exportGlobalScriptsFileName)
        
        guard FileManager.default.fileExists(atPath: historyURL.path),
              FileManager.default.fileExists(atPath: variablesURL.path),
              FileManager.default.fileExists(atPath: scriptsURL.path) else {
            throw VariableResolveError(message: "导入失败：所选目录缺少必要文件（network_history.json / network_variables.json / network_global_scripts.json）")
        }
        
        let historyData = try Data(contentsOf: historyURL)
        guard let roots = parseImportedHistoryRoots(from: historyData) else {
            throw VariableResolveError(message: "导入失败：network_history.json 格式无效")
        }
        
        let decoder = JSONDecoder()
        let importedVariables = try decoder.decode([NetworkVariable].self, from: Data(contentsOf: variablesURL))
        let importedScripts = try decoder.decode([GlobalPostScript].self, from: Data(contentsOf: scriptsURL))
        
        historyRoots = roots
        refreshHistoryListUI()
        persistHistory()
        variables = importedVariables
        globalPostScripts = importedScripts
        
        let preScriptsURL = folderURL.appendingPathComponent(exportGlobalPreScriptsFileName)
        if FileManager.default.fileExists(atPath: preScriptsURL.path) {
            globalPreScripts = try decoder.decode([GlobalPreScript].self, from: Data(contentsOf: preScriptsURL))
        } else {
            globalPreScripts = []
        }
        
        currentHistory = nil
        selectedId = nil
        historyListUI.selectedId = nil
        editor.selectedPostScriptIDsForCurrent = []
        editor.selectedPreScriptIDForCurrent = nil
    }
    
    // MARK: - History tree
    
    private func loadHistoryFromDisk() {
        guard let data = NSData(contentsOfFile: history_path) as Data? else { return }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["version"] as? Int == 2,
           let doc = HistoryDocument.mapping(jsonData: data) {
            var items = doc.item ?? []
            HistoryTree.normalize(&items)
            historyRoots = items
            return
        }
        
        if let doc = HistoryDocument.mapping(jsonData: data),
           let items = doc.item,
           items.isEmpty == false,
           items.contains(where: { $0.type != nil }) {
            var normalized = items
            HistoryTree.normalize(&normalized)
            historyRoots = normalized
            return
        }
        
        if let historys = MyObj.mapping(jsonData: data) {
            historyRoots = (historys.item ?? []).map { HistoryNode.fromXYItem($0) }
            persistHistory()
        }
    }
    
    private func parseImportedHistoryRoots(from data: Data) -> [HistoryNode]? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["version"] as? Int == 2,
           let doc = HistoryDocument.mapping(jsonData: data) {
            var items = doc.item ?? []
            HistoryTree.normalize(&items)
            return items
        }
        
        if let doc = HistoryDocument.mapping(jsonData: data),
           let items = doc.item,
           items.isEmpty == false,
           items.contains(where: { $0.type != nil }) {
            var normalized = items
            HistoryTree.normalize(&normalized)
            return normalized
        }
        
        if let historys = MyObj.mapping(jsonData: data) {
            return (historys.item ?? []).map { HistoryNode.fromXYItem($0) }
        }
        
        return nil
    }
    
    func refreshHistoryListUI() {
        historyListUI.requestCount = HistoryTree.allRequestNodes(in: historyRoots).count
        historyListUI.selectedId = selectedId
        historyListUI.treeRevision += 1
    }
    
    /// 当前选中节点是否为请求（供设置页等判断脚本绑定）。
    var isSelectedRequest: Bool {
        guard let selectedId,
              let node = HistoryTree.findNode(id: selectedId, in: historyRoots)?.node else {
            return false
        }
        return node.isRequest
    }
    
    private func updateHistoryListSelection(_ id: String?, notifyListUI: Bool = true) {
        selectedId = id
        guard notifyListUI else { return }
        guard historyListUI.selectedId != id else { return }
        historyListUI.selectedId = id
    }
    
    private func commitHistoryMutation(_ mutate: (inout [HistoryNode]) -> Void) {
        mutate(&historyRoots)
        refreshHistoryListUI()
        persistHistory()
    }
    
    func persistHistory() {
        let items = historyRoots.compactMap { $0.toDictionary() }
        let dict: [String: Any] = ["version": 2, "item": items]
        let path = history_path
        historyPersistToken = UUID()
        let token = historyPersistToken
        
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                let jsonStr = String(data: data, encoding: .utf8)
                try jsonStr?.write(toFile: path, atomically: true, encoding: .utf8)
            } catch {
                print(error)
            }
            _ = token
        }
    }
    
    func createGroup() {
        let parentId = selectedNode?.isGroup == true ? selectedId : nil
        let name = uniqueGroupName(base: "新分组")
        let group = HistoryNode.newGroup(name: name)
        commitHistoryMutation { roots in
            if let parentId {
                _ = HistoryTree.insertNode(group, parentId: parentId, at: Int.max, in: &roots)
            } else {
                roots.append(group)
            }
        }
        updateHistoryListSelection(group.id)
    }
    
    func uniqueGroupName(base: String) -> String {
        let existing = Set(HistoryTree.allGroupNames(in: historyRoots))
        if existing.contains(base) == false { return base }
        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
    
    func groupNameExists(_ name: String, excludingId: String? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return false }
        return containsGroupName(trimmed, in: historyRoots, excludingId: excludingId)
    }
    
    private func containsGroupName(_ name: String, in nodes: [HistoryNode], excludingId: String?) -> Bool {
        for node in nodes {
            if node.isGroup {
                if node.id != excludingId, node.name == name { return true }
                if let children = node.children, containsGroupName(name, in: children, excludingId: excludingId) {
                    return true
                }
            }
        }
        return false
    }
    
    func canMoveNode(_ nodeId: String, intoGroup groupId: String) -> Bool {
        guard nodeId != groupId else { return false }
        guard HistoryTree.findNode(id: groupId, in: historyRoots)?.node.isGroup == true else { return false }
        return HistoryTree.isDescendant(nodeId: groupId, of: nodeId, in: historyRoots) == false
    }
    
    func renameGroup(id: String, to newName: String) -> String? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "分组名称不能为空" }
        guard let location = HistoryTree.findNode(id: id, in: historyRoots), location.node.isGroup else {
            return "未找到分组"
        }
        if location.node.name == trimmed { return nil }
        if groupNameExists(trimmed, excludingId: id) {
            return "已存在同名分组"
        }
        location.node.name = trimmed
        refreshHistoryListUI()
        persistHistory()
        AppLogger.shared.track(category: .network, name: "history_group_renamed", result: .success)
        return nil
    }
    
    func toggleGroupCollapsed(id: String) {
        guard let node = HistoryTree.findNode(id: id, in: historyRoots)?.node, node.isGroup else { return }
        node.collapsed = !(node.collapsed ?? false)
        refreshHistoryListUI()
        persistHistory()
    }
    
    /// 由 NSOutlineView 展开/折叠回调调用，避免整表 flatten 刷新。
    func setGroupCollapsed(id: String, collapsed: Bool) {
        guard let node = HistoryTree.findNode(id: id, in: historyRoots)?.node, node.isGroup else { return }
        guard (node.collapsed ?? false) != collapsed else { return }
        node.collapsed = collapsed
        persistHistory()
    }
    
    func applySiblingOrder(parentId: String?, orderedIds: [String]) {
        let current = HistoryTree.children(of: parentId, in: historyRoots)
        let currentIds = HistoryTree.siblingIds(in: current)
        guard orderedIds != currentIds else { return }
        var nodeMap: [String: HistoryNode] = [:]
        for node in current {
            if let id = node.id { nodeMap[id] = node }
        }
        let reordered = orderedIds.compactMap { nodeMap[$0] }
        guard reordered.count == current.count else { return }
        commitHistoryMutation { roots in
            HistoryTree.setChildren(reordered, of: parentId, in: &roots)
        }
    }
    
    func moveNode(id: String, toParentId: String?, atIndex index: Int) {
        guard id != toParentId else { return }
        if let toParentId, HistoryTree.isDescendant(nodeId: toParentId, of: id, in: historyRoots) {
            return
        }
        commitHistoryMutation { roots in
            guard let node = HistoryTree.removeNode(id: id, from: &roots) else { return }
            _ = HistoryTree.insertNode(node, parentId: toParentId, at: index, in: &roots)
        }
        AppLogger.shared.track(
            category: .network,
            name: "history_moved",
            result: .success,
            metadata: ["destination": toParentId == nil ? "root" : "group"]
        )
    }
    
    func moveNodeIntoGroup(id: String, groupId: String) {
        guard id != groupId else { return }
        guard HistoryTree.findNode(id: groupId, in: historyRoots)?.node.isGroup == true else { return }
        if HistoryTree.isDescendant(nodeId: groupId, of: id, in: historyRoots) { return }
        commitHistoryMutation { roots in
            guard let node = HistoryTree.removeNode(id: id, from: &roots) else { return }
            _ = HistoryTree.insertNode(node, parentId: groupId, at: Int.max, in: &roots)
        }
    }
    
    func deleteGroup(id: String, unwrapOnly: Bool) {
        guard let location = HistoryTree.findNode(id: id, in: historyRoots), location.node.isGroup else { return }
        commitHistoryMutation { roots in
            guard let removed = HistoryTree.removeNode(id: id, from: &roots) else { return }
            if unwrapOnly, let children = removed.children, children.isEmpty == false {
                for (offset, child) in children.enumerated() {
                    _ = HistoryTree.insertNode(child, parentId: location.parentId, at: location.index + offset, in: &roots)
                }
            }
        }
        if selectedId == id {
            updateHistoryListSelection(nil)
        }
        if unwrapOnly == false {
            if isIdInsideSubtree(selectedId, of: location.node) {
                updateHistoryListSelection(nil)
            }
            if isIdInsideSubtree(currentHistory?.id, of: location.node) {
                currentHistory = nil
                editor.selectedPostScriptIDsForCurrent = []
            }
        }
        AppLogger.shared.track(
            category: .network,
            name: "history_group_deleted",
            result: .success,
            metadata: ["keptChildren": String(unwrapOnly)]
        )
    }
    
    private func isIdInsideSubtree(_ id: String?, of node: HistoryNode) -> Bool {
        guard let id else { return false }
        if node.id == id { return true }
        guard let children = node.children else { return false }
        return children.contains { isIdInsideSubtree(id, of: $0) }
    }
    
    func lockedRequestCount(inSubtreeOf groupId: String) -> Int {
        guard let node = HistoryTree.findNode(id: groupId, in: historyRoots)?.node else { return 0 }
        return HistoryTree.countLockedRequests(in: node)
    }
    
    func exportFileNamesDescription() -> String {
        "\(exportHistoryFileName), \(exportVariablesFileName), \(exportGlobalScriptsFileName), \(exportGlobalPreScriptsFileName)"
    }
    
    func variableResolutionPreview() -> (rows: [NetworkVariablePreview], error: String?) {
        let trimmedKeys = variables.map { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) }
        if trimmedKeys.contains(where: { $0.isEmpty }) {
            return ([], "存在空 key，补全后可查看完整解析结果。")
        }
        
        var keyCounter: [String: Int] = [:]
        for key in trimmedKeys {
            keyCounter[key, default: 0] += 1
        }
        let duplicatedKeys = keyCounter
            .filter { $0.value > 1 }
            .map { $0.key }
            .sorted()
        if duplicatedKeys.isEmpty == false {
            return ([], "存在重复 key：\(duplicatedKeys.joined(separator: ", "))")
        }
        
        switch resolvedVariableDictionary() {
        case .success(let resolvedVariables):
            var rows: [NetworkVariablePreview] = []
            var addedKeys = Set<String>()
            for item in variables {
                let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
                if key.isEmpty || addedKeys.contains(key) { continue }
                rows.append(NetworkVariablePreview(id: key, key: key, resolvedValue: resolvedVariables[key] ?? item.value))
                addedKeys.insert(key)
            }
            return (rows, nil)
        case .failure(let error):
            return ([], error.message)
        }
    }
    
    
    /// 删除指定 id 的请求历史。
    func removeHistory(id: String) {
        guard let location = HistoryTree.findNode(id: id, in: historyRoots), location.node.isRequest else { return }
        commitHistoryMutation { roots in
            _ = HistoryTree.removeNode(id: id, from: &roots)
        }
        if currentHistory?.id == id {
            currentHistory = nil
            updateHistoryListSelection(nil)
            editor.selectedPostScriptIDsForCurrent = []
            editor.selectedPreScriptIDForCurrent = nil
        }
        AppLogger.shared.track(category: .network, name: "history_request_deleted", result: .success)
    }
    
    /// 选中历史节点并加载请求到编辑区（仅 request 类型会填充表单）。
    func selectHistory(id: String) {
        selectionGeneration += 1
        let generation = selectionGeneration
        let nodeType = HistoryTree.findNode(id: id, in: historyRoots)?.node.isGroup == true ? "group" : "request"
        AppLogger.shared.track(
            category: .network,
            name: "history_selected",
            metadata: ["type": nodeType]
        )
        applySelection(id: id, generation: generation, loadText: false)
    }
    
    private func applySelection(id: String, generation: Int, loadText: Bool) {
        guard selectionGeneration == generation else { return }
        
        if loadText {
            guard let node = HistoryTree.findNode(id: id, in: historyRoots)?.node, node.isRequest else { return }
            editor.loadTextContent(from: node)
            return
        }
        
        guard let location = HistoryTree.findNode(id: id, in: historyRoots) else { return }
        updateHistoryListSelection(id)
        
        guard location.node.isRequest else {
            currentHistory = nil
            return
        }
        
        let node = location.node
        currentHistory = node
        editor.loadMetadata(from: node)
        
        DispatchQueue.main.async { [weak self] in
            self?.applySelection(id: id, generation: generation, loadText: true)
        }
    }
    
    func isRequestLocked(id: String) -> Bool {
        guard let node = HistoryTree.findNode(id: id, in: historyRoots)?.node, node.isRequest else {
            return false
        }
        return node.isLock ?? true
    }
    
    private func syncLockToSelectedRequest() {
        guard let selectedId,
              let location = HistoryTree.findNode(id: selectedId, in: historyRoots),
              location.node.isRequest else {
            return
        }
        location.node.isLock = editor.isLock
        if currentHistory?.id == selectedId {
            currentHistory = location.node
        }
        persistHistory()
    }
    
    private func findRequestNode(byName name: String) -> HistoryNode? {
        HistoryTree.allRequestNodes(in: historyRoots).first { $0.name == name }
    }
    
    /// 开始发起请求
    func makeRequest() {
        let selectedPreScriptName = editor.selectedPreScriptIDForCurrent.flatMap { selectedID in
            globalPreScripts.first { $0.id.uuidString == selectedID }?.name
        } ?? ""
        let selectedPostScriptNames = globalPostScripts
            .filter { editor.selectedPostScriptIDsForCurrent.contains($0.id.uuidString) }
            .map(\.name)
            .joined(separator: ",")

        AppLogger.shared.track(
            category: .network,
            name: "request_input_received",
            metadata: [
                "requestName": editor.requesName,
                "url": editor.urlString,
                "method": editor.httpMethod.rawValue.uppercased(),
                "headers": editor.httpHeaders,
                "parameters": editor.httpParameters,
                "variables": variableDictionary().toJsonString(),
                "preScript": selectedPreScriptName,
                "postScripts": selectedPostScriptNames
            ]
        )

        let requestOperation = AppLogger.shared.begin(
            category: .network,
            name: "request",
            metadata: [
                "method": editor.httpMethod.rawValue.uppercased(),
                "hasPreScript": String(editor.selectedPreScriptIDForCurrent != nil),
                "postScriptCount": String(editor.selectedPostScriptIDsForCurrent.count)
            ]
        )

        if let variableError = validateVariablesBeforeRequest() {
            status = "request fail: \(variableError)"
            AppLogger.shared.track(
                category: .network,
                name: "request_validation_failed",
                level: .error,
                result: .failure,
                metadata: ["stage": "variables", "error": variableError]
            )
            requestOperation.finish(result: .failure, metadata: ["stage": "variable_validation"])
            showAlert(msg: variableError)
            return
        }
        
        let urlStringApplied = applyVariables(to: editor.urlString)
        let headersTextApplied = applyVariables(to: editor.httpHeaders)
        let paramsTextApplied = applyVariables(to: editor.httpParameters)

        AppLogger.shared.track(
            category: .network,
            name: "request_variables_applied",
            result: .success,
            metadata: [
                "url": urlStringApplied,
                "headers": headersTextApplied,
                "parameters": paramsTextApplied
            ]
        )

        // url
        guard urlStringApplied.isEmpty == false, URL(string: urlStringApplied) != nil else {
            AppLogger.shared.track(
                category: .network,
                name: "request_validation_failed",
                level: .error,
                result: .failure,
                metadata: ["stage": "url", "url": urlStringApplied]
            )
            requestOperation.finish(result: .failure, metadata: ["stage": "url_validation"])
            showAlert(msg: "网址有误，输入正确的网址")
            return
        }
        status = "requesting..."
        
        var headerDict: [String: String] = [:]
        let headersText = headersTextApplied.trimmingCharacters(in: .whitespacesAndNewlines)
        if headersText.isEmpty == false {
            guard let headersData = headersText.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: headersData, options: .fragmentsAllowed) as? [String: Any] else {
                status = "request fail: Header 不是合法 JSON 对象"
                AppLogger.shared.track(
                    category: .network,
                    name: "request_validation_failed",
                    level: .error,
                    result: .failure,
                    metadata: ["stage": "headers", "headers": headersTextApplied]
                )
                requestOperation.finish(result: .failure, metadata: ["stage": "header_validation"])
                showAlert(msg: "请求头格式错误：请输入 JSON 对象，例如 {\"Authorization\":\"Bearer xxx\"}")
                return
            }
            headerDict = dict.reduce(into: [:]) { partialResult, new in
                partialResult[new.key] = "\(new.value)"
            }
        }
        
        var parameters: [String: Any] = [:]
        let paramsText = paramsTextApplied.trimmingCharacters(in: .whitespacesAndNewlines)
        if paramsText.isEmpty == false {
            guard let paramsData = paramsText.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: paramsData, options: .fragmentsAllowed) as? [String: Any] else {
                status = "request fail: Parameters 不是合法 JSON 对象"
                AppLogger.shared.track(
                    category: .network,
                    name: "request_validation_failed",
                    level: .error,
                    result: .failure,
                    metadata: ["stage": "parameters", "parameters": paramsTextApplied]
                )
                requestOperation.finish(result: .failure, metadata: ["stage": "parameter_validation"])
                showAlert(msg: "请求参数格式错误：请输入 JSON 对象，例如 {\"page\":1,\"size\":20}")
                return
            }
            parameters = dict
        }
        
        let item = XYItem()
        item.isLock = editor.isLock
        item.name = editor.requesName
        item.selectedPostScriptIDs = editor.selectedPostScriptIDsForCurrent
        item.selectedPreScriptID = editor.selectedPreScriptIDForCurrent
        let res = XYRequest()
        res.method = editor.httpMethod.rawValue.uppercased()
        res.url = editor.urlString
        res.header = editor.httpHeaders
        res.body = editor.httpParameters
        //res.url = urlStringApplied
        //res.header = headersTextApplied
        //res.body = paramsTextApplied
        item.request = res
        if item.name?.isEmpty == true {
            item.name = URL(string: editor.urlString)?.host
            //item.name = URL(string: urlStringApplied)?.host
        }
        
        // 前置脚本：签名 / 改包 / 或脚本代发
        AppLogger.shared.track(
            category: .network,
            name: editor.selectedPreScriptIDForCurrent == nil ? "pre_script_skipped" : "pre_script_started",
            metadata: [
                "script": selectedPreScriptName,
                "url": urlStringApplied,
                "method": editor.httpMethod.rawValue.uppercased(),
                "headers": headersTextApplied,
                "parameters": paramsTextApplied
            ]
        )
        let preResult = runPreScriptIfNeeded(
            url: urlStringApplied,
            method: editor.httpMethod,
            headersText: headersTextApplied,
            parametersText: paramsTextApplied,
            headers: headerDict,
            parameters: parameters
        )
        if let error = preResult.error {
            status = "pre-script fail: \(error)"
            AppLogger.shared.track(
                category: .network,
                name: "pre_script_finished",
                level: .error,
                result: .failure,
                metadata: ["script": selectedPreScriptName, "error": error]
            )
            requestOperation.finish(result: .failure, metadata: ["stage": "pre_script"])
            showAlert(msg: "前置脚本执行失败：\(error)")
            return
        }
        if let response = preResult.response {
            editor.httpResponse = response
            status = "complete (pre-script)"
            item.response = response
            updateHistory(with: item)
            AppLogger.shared.track(
                category: .network,
                name: "pre_script_finished",
                result: .success,
                metadata: [
                    "script": selectedPreScriptName,
                    "mode": "script_response",
                    "response": response
                ]
            )
            requestOperation.finish(
                result: .success,
                metadata: [
                    "mode": "pre_script_response",
                    "responseBytes": String(response.utf8.count)
                ]
            )
            return
        }
        
        // Mark: - 前置脚本未直接请求，App 继续
        
        let requestURLString = preResult.url ?? urlStringApplied
        let requestMethod = preResult.method ?? editor.httpMethod
        headerDict = preResult.headers ?? headerDict
        
        // POST：优先用原始 JSON 文本（UI 原文或脚本返回的 parametersText），避免 Dictionary 重序列化打乱 key 顺序
        var requestBodyText: String? = paramsText.isEmpty ? nil : paramsTextApplied
        if let bodyText = preResult.bodyText {
            requestBodyText = bodyText
        }

        AppLogger.shared.track(
            category: .network,
            name: "pre_script_finished",
            result: .success,
            metadata: [
                "script": selectedPreScriptName,
                "mode": editor.selectedPreScriptIDForCurrent == nil ? "skipped" : "continue_request",
                "url": requestURLString,
                "method": requestMethod.rawValue.uppercased(),
                "headers": headerDict.toJsonString(),
                "parameters": preResult.parameters?.toJsonString() ?? parameters.toJsonString(),
                "body": requestBodyText ?? ""
            ]
        )
        
        guard requestURLString.isEmpty == false, let requestURL = URL(string: requestURLString) else {
            AppLogger.shared.track(
                category: .network,
                name: "request_validation_failed",
                level: .error,
                result: .failure,
                metadata: ["stage": "pre_script_url", "url": requestURLString]
            )
            showAlert(msg: "前置脚本返回的 URL 无效")
            status = "pre-script fail: invalid url"
            requestOperation.finish(result: .failure, metadata: ["stage": "pre_script_url_validation"])
            return
        }
        
        let onSuccess: ([String: Any]) -> Void = { result in
            print("XYNetTool 请求成功 - \n\(result)")
            self.status = "complete"

            let responseText = result.toJsonString()
            item.response = responseText
            self.editor.httpResponse = responseText
            self.updateHistory(with: item)
            AppLogger.shared.track(
                category: .network,
                name: "response_received",
                result: .success,
                metadata: [
                    "url": requestURL.absoluteString,
                    "method": requestMethod.rawValue.uppercased(),
                    "response": responseText
                ]
            )
            self.runPostResponseScriptIfNeeded(for: item, responseText: self.editor.httpResponse)
            requestOperation.finish(
                result: .success,
                metadata: [
                    "mode": "app_request",
                    "method": requestMethod.rawValue.uppercased(),
                    "requestBytes": String(requestBodyText?.utf8.count ?? 0),
                    "responseBytes": String(responseText.utf8.count)
                ]
            )
        }
        
        let onFailure: (String) -> Void = { errMsg in
            print("XYNetTool 请求失败 - \n\(errMsg)")
            let message = errMsg.isEmpty ? "未知错误" : errMsg
            self.status = "request fail: \(message)"
            AppLogger.shared.track(
                category: .network,
                name: "request_failed",
                level: .error,
                result: .failure,
                metadata: [
                    "url": requestURL.absoluteString,
                    "method": requestMethod.rawValue.uppercased(),
                    "error": message
                ]
            )
            requestOperation.finish(
                result: .failure,
                metadata: [
                    "stage": "transport",
                    "method": requestMethod.rawValue.uppercased()
                ]
            )
        }

        AppLogger.shared.track(
            category: .network,
            name: "request_started",
            metadata: [
                "url": requestURL.absoluteString,
                "method": requestMethod.rawValue.uppercased(),
                "headers": headerDict.toJsonString(),
                "parameters": parameters.toJsonString(),
                "body": requestBodyText ?? ""
            ]
        )
        
        switch requestMethod {
        case .get:
            // 脚本若返回完整 URL（含 query），不再从 Dictionary 拼 query，避免参数顺序丢失
            let getParameters = preResult.urlOverridden ? [:] : parameters
            XYNetTool.get(url: requestURL, paramters: getParameters, headers: headerDict, success: onSuccess, failure: onFailure)
        case .post:
            if let bodyText = requestBodyText, let bodyData = bodyText.data(using: .utf8) {
                XYNetTool.post(url: requestURL, headers: headerDict, body: bodyData, success: onSuccess, failure: onFailure)
            } else {
                XYNetTool.post(url: requestURL, paramters: parameters, headers: headerDict, success: onSuccess, failure: onFailure)
            }
        }

    }
    
    
    /// 更新历史记录：请求同名覆盖，异名新建。
    func updateHistory(with item: XYItem) {
        if let existing = findRequestNode(byName: item.name ?? "") {
            existing.update(with: item)
            persistHistory()
            if currentHistory?.id == existing.id {
                currentHistory = existing
            }
            return
        }
        
        let node = HistoryNode.fromXYItem(item)
        let parentId = selectedNode?.isGroup == true ? selectedId : nil
        commitHistoryMutation { roots in
            if let parentId {
                _ = HistoryTree.insertNode(node, parentId: parentId, at: Int.max, in: &roots)
            } else {
                roots.append(node)
            }
        }
        if currentHistory?.name == item.name {
            currentHistory = node
        }
    }
}

extension NetworkDataModel {
    private func syncCurrentScriptSelection() {
        guard let currentHistory else { return }
        currentHistory.selectedPostScriptIDs = editor.selectedPostScriptIDsForCurrent
        persistHistory()
    }
    
    private func syncCurrentPreScriptSelection() {
        guard let currentHistory else { return }
        currentHistory.selectedPreScriptID = editor.selectedPreScriptIDForCurrent
        persistHistory()
    }

    func addGlobalPostScript() {
        globalPostScripts.append(GlobalPostScript())
    }
    
    func removeGlobalPostScript(id: UUID) {
        globalPostScripts.removeAll { $0.id == id }
    }
    
    func addGlobalPreScript() {
        globalPreScripts.append(GlobalPreScript())
    }
    
    func removeGlobalPreScript(id: UUID) {
        globalPreScripts.removeAll { $0.id == id }
    }

    private func loadGlobalPostScripts() {
        guard let data = UserDefaults.standard.data(forKey: globalPostScriptsStoreKey),
              let list = try? JSONDecoder().decode([GlobalPostScript].self, from: data) else {
            globalPostScripts = []
            return
        }
        globalPostScripts = list
    }
    
    private func saveGlobalPostScripts() {
        guard let data = try? JSONEncoder().encode(globalPostScripts) else { return }
        UserDefaults.standard.set(data, forKey: globalPostScriptsStoreKey)
    }
    
    private func loadGlobalPreScripts() {
        guard let data = UserDefaults.standard.data(forKey: globalPreScriptsStoreKey),
              let list = try? JSONDecoder().decode([GlobalPreScript].self, from: data) else {
            globalPreScripts = []
            return
        }
        globalPreScripts = list
    }
    
    private func saveGlobalPreScripts() {
        guard let data = try? JSONEncoder().encode(globalPreScripts) else { return }
        UserDefaults.standard.set(data, forKey: globalPreScriptsStoreKey)
    }
    
    private func sanitizeSelectedScriptReferences() {
        let validIDs = Set(globalPostScripts.map { $0.id.uuidString })
        let sanitizedCurrent = editor.selectedPostScriptIDsForCurrent.filter { validIDs.contains($0) }
        if sanitizedCurrent != editor.selectedPostScriptIDsForCurrent {
            editor.selectedPostScriptIDsForCurrent = sanitizedCurrent
        }
        
        var hasHistoryChange = false
        for item in HistoryTree.allRequestNodes(in: historyRoots) {
            let selected = item.selectedPostScriptIDs ?? []
            let sanitized = selected.filter { validIDs.contains($0) }
            if selected != sanitized {
                item.selectedPostScriptIDs = sanitized
                hasHistoryChange = true
            }
        }
        if hasHistoryChange {
            persistHistory()
        }
    }
    
    private func sanitizeSelectedPreScriptReferences() {
        let validIDs = Set(globalPreScripts.map { $0.id.uuidString })
        if let currentID = editor.selectedPreScriptIDForCurrent, validIDs.contains(currentID) == false {
            editor.selectedPreScriptIDForCurrent = nil
        }
        
        var hasHistoryChange = false
        for item in HistoryTree.allRequestNodes(in: historyRoots) {
            guard let selected = item.selectedPreScriptID else { continue }
            if validIDs.contains(selected) == false {
                item.selectedPreScriptID = nil
                hasHistoryChange = true
            }
        }
        if hasHistoryChange {
            persistHistory()
        }
    }

    func addVariable() {
        variables.append(NetworkVariable())
    }
    
    func removeVariable(id: UUID) {
        variables.removeAll { $0.id == id }
    }
    
    private func loadVariables() {
        guard let data = UserDefaults.standard.data(forKey: variablesStoreKey),
              let list = try? JSONDecoder().decode([NetworkVariable].self, from: data) else {
            variables = []
            return
        }
        variables = list
    }
    
    private func saveVariables() {
        guard let data = try? JSONEncoder().encode(variables) else { return }
        UserDefaults.standard.set(data, forKey: variablesStoreKey)
    }
    
    private func applyVariables(to text: String) -> String {
        if text.isEmpty { return text }
        guard case .success(let resolvedVariables) = resolvedVariableDictionary() else {
            return text
        }
        return replacePlaceholders(in: text) { key in
            resolvedVariables[key] ?? "{{\(key)}}"
        }
    }
    
    private func validateVariablesBeforeRequest() -> String? {
        let trimmedKeys = variables.map { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        if trimmedKeys.contains(where: { $0.isEmpty }) {
            return "变量配置错误：存在空 key，请先补全或删除该变量。"
        }
        
        var keyCounter: [String: Int] = [:]
        for key in trimmedKeys {
            keyCounter[key, default: 0] += 1
        }
        
        let duplicatedKeys = keyCounter
            .filter { $0.value > 1 }
            .map { $0.key }
            .sorted()
        
        if duplicatedKeys.isEmpty == false {
            return "变量配置错误：存在重复 key -> \(duplicatedKeys.joined(separator: ", "))"
        }
        
        if case .failure(let error) = resolvedVariableDictionary() {
            return error.message
        }
        
        return nil
    }
    
    private func runPostResponseScriptIfNeeded(for item: XYItem, responseText: String) {
        let selectedIDs = item.selectedPostScriptIDs ?? []
        if selectedIDs.isEmpty {
            AppLogger.shared.track(
                category: .network,
                name: "post_script_skipped",
                metadata: ["response": responseText]
            )
            return
        }
        
        let scriptsToRun = globalPostScripts.filter { selectedIDs.contains($0.id.uuidString) }
        if scriptsToRun.isEmpty {
            AppLogger.shared.track(
                category: .network,
                name: "post_scripts_finished",
                level: .warning,
                result: .failure,
                metadata: ["error": "no_valid_script_selected", "response": responseText]
            )
            DispatchQueue.main.async {
                self.status = "post-script skipped: no valid script selected"
            }
            return
        }
        
        let variablesJSON = variableDictionary().toJsonString()

        AppLogger.shared.track(
            category: .network,
            name: "post_scripts_started",
            metadata: [
                "scripts": scriptsToRun.map(\.name).joined(separator: ","),
                "response": responseText,
                "variables": variablesJSON
            ]
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            var mergedUpdates: [String: String] = [:]
            
            for scriptItem in scriptsToRun {
                let script = scriptItem.command.trimmingCharacters(in: .whitespacesAndNewlines)
                if script.isEmpty { continue }

                AppLogger.shared.track(
                    category: .network,
                    name: "post_script_started",
                    metadata: [
                        "script": scriptItem.name,
                        "command": script,
                        "response": responseText,
                        "variables": variablesJSON
                    ]
                )
                
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", script, "xy-post-script", responseText, variablesJSON]
                process.standardOutput = pipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    AppLogger.shared.track(
                        category: .network,
                        name: "post_script_finished",
                        level: .error,
                        result: .failure,
                        metadata: ["script": scriptItem.name, "error": error.localizedDescription]
                    )
                    DispatchQueue.main.async {
                        self.status = "post-script[\(scriptItem.name)] fail: \(error.localizedDescription)"
                    }
                    return
                }
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let err = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if err.isEmpty == false {
                    AppLogger.shared.track(
                        category: .network,
                        name: "post_script_finished",
                        level: .error,
                        result: .failure,
                        metadata: ["script": scriptItem.name, "stderr": err, "output": output]
                    )
                    DispatchQueue.main.async {
                        self.status = "post-script[\(scriptItem.name)] fail: \(err)"
                    }
                    return
                }
                
                if output.isEmpty {
                    AppLogger.shared.track(
                        category: .network,
                        name: "post_script_finished",
                        result: .success,
                        metadata: ["script": scriptItem.name, "output": ""]
                    )
                    continue
                }
                
                let updates = self.parseVariableUpdates(from: output)
                if updates.isEmpty {
                    AppLogger.shared.track(
                        category: .network,
                        name: "post_script_finished",
                        level: .error,
                        result: .failure,
                        metadata: [
                            "script": scriptItem.name,
                            "error": "invalid_output",
                            "output": output
                        ]
                    )
                    DispatchQueue.main.async {
                        self.status = "post-script[\(scriptItem.name)] fail: 输出格式无效"
                    }
                    return
                }
                
                for (key, value) in updates {
                    mergedUpdates[key] = value
                }
                AppLogger.shared.track(
                    category: .network,
                    name: "post_script_finished",
                    result: .success,
                    metadata: [
                        "script": scriptItem.name,
                        "output": output,
                        "variableUpdates": updates.toJsonString()
                    ]
                )
            }
            
            if mergedUpdates.isEmpty {
                AppLogger.shared.track(
                    category: .network,
                    name: "post_scripts_finished",
                    result: .success,
                    metadata: ["variableUpdates": "{}"]
                )
                DispatchQueue.main.async {
                    self.status = "complete (post-script no update)"
                }
                return
            }
            
            AppLogger.shared.track(
                category: .network,
                name: "post_scripts_finished",
                result: .success,
                metadata: ["variableUpdates": mergedUpdates.toJsonString()]
            )
            DispatchQueue.main.async {
                self.applyVariableUpdates(mergedUpdates)
                self.status = "complete (updated variables: \(mergedUpdates.keys.sorted().joined(separator: ", ")))"
            }
        }
    }
    
    private func variableDictionary() -> [String: String] {
        switch resolvedVariableDictionary() {
        case .success(let dict):
            return dict
        case .failure:
            var fallback: [String: String] = [:]
            for item in variables {
                let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
                if key.isEmpty { continue }
                fallback[key] = item.value
            }
            return fallback
        }
    }

    private func resolvedVariableDictionary() -> Swift.Result<[String: String], VariableResolveError> {
        let rawVariables = variables.reduce(into: [String: String]()) { partialResult, variable in
            let key = variable.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty { return }
            partialResult[key] = variable.value
        }
        
        var resolvedVariables: [String: String] = [:]
        var resolvingStack: [String] = []
        
        func resolve(_ key: String) -> Swift.Result<String, VariableResolveError> {
            if let resolved = resolvedVariables[key] {
                return .success(resolved)
            }
            
            if resolvingStack.contains(key) {
                let cyclePath = (resolvingStack + [key]).joined(separator: " -> ")
                return .failure(VariableResolveError(message: "变量配置错误：检测到循环引用 -> \(cyclePath)"))
            }
            
            guard let rawValue = rawVariables[key] else {
                return .success("{{\(key)}}")
            }
            
            resolvingStack.append(key)
            let resolvedValue = replacePlaceholders(in: rawValue) { nestedKey in
                switch resolve(nestedKey) {
                case .success(let value):
                    return value
                case .failure:
                    return "{{\(nestedKey)}}"
                }
            }
            _ = resolvingStack.popLast()
            
            resolvedVariables[key] = resolvedValue
            return .success(resolvedValue)
        }
        
        for key in rawVariables.keys {
            if case .failure(let error) = resolve(key) {
                return .failure(error)
            }
        }
        
        return .success(resolvedVariables)
    }
    
    private func replacePlaceholders(in text: String, resolver: (String) -> String) -> String {
        guard text.isEmpty == false else { return text }
        
        let pattern = #"\{\{\s*([^{}]+?)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        if matches.isEmpty { return text }
        
        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let wholeRange = Range(match.range(at: 0), in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            let key = String(result[keyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = key.isEmpty ? String(result[wholeRange]) : resolver(key)
            result.replaceSubrange(wholeRange, with: replacement)
        }
        
        return result
    }
    
    private func parseVariableUpdates(from output: String) -> [String: String] {
        if let data = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] {
            if let vars = json["variables"] as? [String: Any] {
                return vars.reduce(into: [:]) { partialResult, pair in
                    partialResult[pair.key] = "\(pair.value)"
                }
            }
            return json.reduce(into: [:]) { partialResult, pair in
                partialResult[pair.key] = "\(pair.value)"
            }
        }
        
        var kv: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count != 2 { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty { continue }
            kv[key] = value
        }
        return kv
    }
    
    private func applyVariableUpdates(_ updates: [String: String]) {
        for (key, value) in updates {
            if let index = variables.firstIndex(where: { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) == key }) {
                variables[index].value = value
            } else {
                variables.append(NetworkVariable(key: key, value: value))
            }
        }
    }

    /// 若当前请求绑定了前置脚本，则在发包前执行；否则原样返回。
    private func runPreScriptIfNeeded(
        url: String,
        method: HttpMethod,
        headersText: String,
        parametersText: String,
        headers: [String: String],
        parameters: [String: Any]
    ) -> PreScriptRunResult {
        guard let scriptID = editor.selectedPreScriptIDForCurrent,
              let scriptItem = globalPreScripts.first(where: { $0.id.uuidString == scriptID }) else {
            return .unchanged()
        }
        
        let command = scriptItem.command.trimmingCharacters(in: .whitespacesAndNewlines)
        if command.isEmpty {
            return .unchanged()
        }
        
        return runPreScript(
            command,
            scriptName: scriptItem.name,
            url: url,
            method: method,
            headersText: headersText,
            parametersText: parametersText,
            headers: headers,
            parameters: parameters
        )
    }
    
    private func runPreScript(
        _ command: String,
        scriptName: String,
        url: String,
        method: HttpMethod,
        headersText: String,
        parametersText: String,
        headers: [String: String],
        parameters: [String: Any]
    ) -> PreScriptRunResult {
        let requestPayload: [String: Any] = [
            "url": url,
            "method": method.rawValue.uppercased(),
            "headersText": headersText,
            "parametersText": parametersText,
            "headers": headers,
            "parameters": parameters
        ]
        let requestJSON = requestPayload.toJsonString()

        AppLogger.shared.track(
            category: .network,
            name: "pre_script_process_started",
            metadata: [
                "script": scriptName,
                "command": command,
                "request": requestJSON
            ]
        )
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // 与后置脚本一致：输入框直接写 shell 或指定外部路径。
        // 请求 JSON 通过环境变量注入，避免 $1 含双引号时在 shell 中被截断。
        process.arguments = ["-c", command, "xy-pre-script", requestJSON]
        var env = ProcessInfo.processInfo.environment
        env["XYDEV_PRE_REQUEST_JSON"] = requestJSON
        process.environment = env
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogger.shared.track(
                category: .network,
                name: "pre_script_process_finished",
                level: .error,
                result: .failure,
                metadata: ["script": scriptName, "error": error.localizedDescription]
            )
            return PreScriptRunResult(error: error.localizedDescription)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let err = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        AppLogger.shared.track(
            category: .network,
            name: "pre_script_process_finished",
            level: err.isEmpty ? .info : .error,
            result: err.isEmpty ? .success : .failure,
            metadata: [
                "script": scriptName,
                "terminationStatus": String(process.terminationStatus),
                "stdout": output,
                "stderr": err
            ]
        )
        
        if err.isEmpty == false {
            return PreScriptRunResult(error: err)
        }
        
        if output.isEmpty {
            return PreScriptRunResult(error: "前置脚本[\(scriptName.isEmpty ? "未命名" : scriptName)] 无输出")
        }
        
        return parsePreScriptOutput(output, scriptName: scriptName, fallbackHeaders: headers, fallbackParameters: parameters)
    }
    
    private func parsePreScriptOutput(
        _ output: String,
        scriptName: String,
        fallbackHeaders: [String: String],
        fallbackParameters: [String: Any]
    ) -> PreScriptRunResult {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            
            let params = text.asParams()
            if params.isEmpty { continue }
            
            if let error = params["error"] as? String, error.isEmpty == false {
                return PreScriptRunResult(error: error)
            }
            
            if let response = params["response"] {
                let responseText: String
                if let str = response as? String {
                    responseText = str
                } else if JSONSerialization.isValidJSONObject(response),
                          let data = try? JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted]),
                          let json = String(data: data, encoding: .utf8) {
                    responseText = json
                } else {
                    responseText = "\(response)"
                }
                return PreScriptRunResult(response: responseText)
            }
            
            var result = PreScriptRunResult()
            if let url = params["url"] as? String {
                result.url = url
                result.urlOverridden = true
            }
            
            if let methodText = params["method"] as? String {
                result.method = HttpMethod(rawValue: methodText.lowercased())
            }
            
            if let headersText = params["headersText"] as? String {
                result.headers = parseHeaderDictionary(from: headersText) ?? fallbackHeaders
            } else if let h = params["headers"] as? [String: String] {
                result.headers = h
            } else if let h = params["headers"] as? [String: Any] {
                result.headers = h.reduce(into: [:]) { partialResult, entry in
                    partialResult[entry.key] = "\(entry.value)"
                }
            }
            
            if let parametersText = params["parametersText"] as? String {
                result.bodyText = parametersText
                result.parameters = parseParameterDictionary(from: parametersText) ?? fallbackParameters
            } else if let p = params["parameters"] as? [String: Any] {
                result.parameters = p
            }
            
            let hasMutation = result.urlOverridden
                || result.method != nil
                || result.headers != nil
                || result.bodyText != nil
                || result.parameters != nil
            if hasMutation {
                return result
            }
        }
        
        return PreScriptRunResult(error: "前置脚本[\(scriptName.isEmpty ? "未命名" : scriptName)] 输出格式无效")
    }
    
    private func parseHeaderDictionary(from text: String) -> [String: String]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [:] }
        guard let data = trimmed.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else {
            return nil
        }
        return dict.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = "\(entry.value)"
        }
    }
    
    private func parseParameterDictionary(from text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [:] }
        guard let data = trimmed.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else {
            return nil
        }
        return dict
    }
}

struct Result: Model {
    
}

// MARK: - History list actions & environment

/// 历史列表操作入口（非 ObservableObject），避免列表订阅整个 NetworkDataModel。
final class HistoryListActions {
    private unowned let model: NetworkDataModel
    
    init(model: NetworkDataModel) {
        self.model = model
    }
    
    func historyRoots() -> [HistoryNode] { model.historyRoots }
    
    func selectHistory(id: String) { model.selectHistory(id: id) }
    func makeRequest() { model.makeRequest() }
    func createGroup() { model.createGroup() }
    func toggleGroupCollapsed(id: String) { model.toggleGroupCollapsed(id: id) }
    func setGroupCollapsed(id: String, collapsed: Bool) { model.setGroupCollapsed(id: id, collapsed: collapsed) }
    func removeHistory(id: String) { model.removeHistory(id: id) }
    func isRequestLocked(id: String) -> Bool { model.isRequestLocked(id: id) }
    func canMoveNode(_ nodeId: String, intoGroup groupId: String) -> Bool {
        model.canMoveNode(nodeId, intoGroup: groupId)
    }
    func moveNodeIntoGroup(id: String, groupId: String) { model.moveNodeIntoGroup(id: id, groupId: groupId) }
    func moveNode(id: String, toParentId: String?, atIndex: Int) {
        model.moveNode(id: id, toParentId: toParentId, atIndex: atIndex)
    }
    func applySiblingOrder(parentId: String?, orderedIds: [String]) {
        model.applySiblingOrder(parentId: parentId, orderedIds: orderedIds)
    }
    func renameGroup(id: String, to name: String) -> String? { model.renameGroup(id: id, to: name) }
    func deleteGroup(id: String, unwrapOnly: Bool) { model.deleteGroup(id: id, unwrapOnly: unwrapOnly) }
    func lockedRequestCount(inSubtreeOf groupId: String) -> Int { model.lockedRequestCount(inSubtreeOf: groupId) }
}

enum HistoryListLayout {
    static let rowHeight: CGFloat = max(28, NetworkDataModel.historyRowMinHeight)
    static let indentPerLevel: CGFloat = 12
}

/*
 创建配置<请求地址> -- 生成配置列表
 每个请求可以设置当前使用的配置
 */


/* 
 
 swift /Users/quxiaoyou/Desktop/Shell/swift.swift
 
 1. 支持传入两个参数, 均为字符串类型, 第一个是请求头,第二个是请求体
 2. 必须有一个输出值类型是一个 json 对象, 有两个参数 {"headers": ..., "parameters": ...}
 
 搜索
 https://{{host }}/api/search/resource
 {"search":  "桌面"}
 
 */
