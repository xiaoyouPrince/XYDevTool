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

/// 历史列表专用 UI 状态，与编辑区字段分离，避免选中时整表重绘。
@Observable
final class HistoryListUIStore {
    var rows: [HistoryDisplayRow] = []
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
    
    fileprivate var isApplyingState = false
    fileprivate var onLockChanged: (() -> Void)?
    fileprivate var onScriptsChanged: (() -> Void)?
    
    /// 先加载轻量字段，让顶栏立刻刷新。
    fileprivate func loadMetadata(from node: HistoryNode) {
        isApplyingState = true
        requesName = node.name ?? ""
        isLock = node.isLock ?? true
        urlString = node.request?.url ?? ""
        httpMethod = HttpMethod(rawValue: node.request?.method?.lowercased() ?? "") ?? .get
        selectedPostScriptIDsForCurrent = node.selectedPostScriptIDs ?? []
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
    
    /// 历史列表行内上下 padding、拖拽把手边长（与 PanelHistoryView 保持一致）
    static let historyRowVerticalPadding: CGFloat = 3
    static let historyRowHandleSize: CGFloat = 22
    
    /// 历史列表单行目标高度（改此值即可统一调整）
    let historyRowHeight: CGFloat = 28
    
    /// 行内容撑开的最小高度，低于此值背景会重叠
    static var historyRowMinHeight: CGFloat {
        historyRowHandleSize + historyRowVerticalPadding * 2
    }
    
    /// 实际行高：布局与拖拽补偿共用，不会低于 historyRowMinHeight
    var effectiveHistoryRowHeight: CGFloat {
        max(historyRowHeight, Self.historyRowMinHeight)
    }
    
    let editor = NetworkEditorStore()
    var historyRoots: [HistoryNode] = []
    private(set) var selectedId: String?
    @Published var status: String = "Ready"
    
    /// 非 @Published：选中切换时不触发整窗 EnvironmentObject 刷新。
    private(set) var currentHistory: HistoryNode?
    
    /// 名称区每加深一层缩进（pt）
    let historyIndentPerLevel: CGFloat = 12
    
    @Published var userScript: String = ""
    @Published var globalPostScripts: [GlobalPostScript] = [] {
        didSet {
            saveGlobalPostScripts()
            sanitizeSelectedScriptReferences()
        }
    }
    @Published var variables: [NetworkVariable] = [] {
        didSet {
            saveVariables()
        }
    }
    
    private let variablesStoreKey = "xydev.network.variables"
    private let globalPostScriptsStoreKey = "xydev.network.globalPostScripts"
    private let exportHistoryFileName = "network_history.json"
    private let exportVariablesFileName = "network_variables.json"
    private let exportGlobalScriptsFileName = "network_global_scripts.json"
    
    let historyListUI = HistoryListUIStore()
    lazy var historyActions = HistoryListActions(model: self)
    private var historyPersistToken = UUID()
    private var selectionGeneration = 0
    
    init() {
        editor.onLockChanged = { [weak self] in self?.syncLockToSelectedRequest() }
        editor.onScriptsChanged = { [weak self] in self?.syncCurrentScriptSelection() }
        loadHistoryFromDisk()
        refreshHistoryListUI()
        loadVariables()
        loadGlobalPostScripts()
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
        currentHistory = nil
        selectedId = nil
        historyListUI.selectedId = nil
        editor.selectedPostScriptIDsForCurrent = []
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
        historyListUI.rows = HistoryTree.flatten(historyRoots)
        historyListUI.requestCount = HistoryTree.allRequestNodes(in: historyRoots).count
        historyListUI.selectedId = selectedId
        historyListUI.treeRevision += 1
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
    
    func flattenHistoryForDisplay() -> [HistoryDisplayRow] {
        HistoryTree.flatten(historyRoots)
    }
    
    func exportFileNamesDescription() -> String {
        "\(exportHistoryFileName), \(exportVariablesFileName), \(exportGlobalScriptsFileName)"
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
        }
    }
    
    /// 选中历史节点并加载请求到编辑区（仅 request 类型会填充表单）。
    func selectHistory(id: String) {
        selectionGeneration += 1
        let generation = selectionGeneration
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
        if let variableError = validateVariablesBeforeRequest() {
            status = "request fail: \(variableError)"
            showAlert(msg: variableError)
            return
        }
        
        let urlStringApplied = applyVariables(to: editor.urlString)
        let headersTextApplied = applyVariables(to: editor.httpHeaders)
        let paramsTextApplied = applyVariables(to: editor.httpParameters)

        // url
        guard urlStringApplied.isEmpty == false, let url = URL(string: urlStringApplied) else {
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
                showAlert(msg: "请求参数格式错误：请输入 JSON 对象，例如 {\"page\":1,\"size\":20}")
                return
            }
            parameters = dict
        }
        
        let item = XYItem()
        item.isLock = editor.isLock
        item.name = editor.requesName
        item.selectedPostScriptIDs = editor.selectedPostScriptIDsForCurrent
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
        
        // 更正脚本, 如果直接返回 response 则直接展示
        let hp = correct(headers: headerDict, params: parameters)
        headerDict = hp.headers
        parameters = hp.params
        if let response = hp.response {
            self.editor.httpResponse = response as? String ?? ""
            self.status = "complete"
            item.response = self.editor.httpResponse
            self.updateHistory(with: item)
            return
        }
        
        let onSuccess: ([String: Any]) -> Void = { result in
            print("XYNetTool 请求成功 - \n\(result)")
            self.status = "complete"
            
            item.response = result.toJsonString()
            self.editor.httpResponse = result.toJsonString()
            self.updateHistory(with: item)
            self.runPostResponseScriptIfNeeded(for: item, responseText: self.editor.httpResponse)
        }
        
        let onFailure: (String) -> Void = { errMsg in
            print("XYNetTool 请求失败 - \n\(errMsg)")
            let message = errMsg.isEmpty ? "未知错误" : errMsg
            self.status = "request fail: \(message)"
        }
        
        switch editor.httpMethod {
        case .get:
            XYNetTool.get(url: url, paramters: parameters, headers: headerDict, success: onSuccess, failure: onFailure)
        case .post:
            XYNetTool.post(url: url, paramters: parameters, headers: headerDict, success: onSuccess, failure: onFailure)
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

    func addGlobalPostScript() {
        globalPostScripts.append(GlobalPostScript())
    }
    
    func removeGlobalPostScript(id: UUID) {
        globalPostScripts.removeAll { $0.id == id }
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
        if selectedIDs.isEmpty { return }
        
        let scriptsToRun = globalPostScripts.filter { selectedIDs.contains($0.id.uuidString) }
        if scriptsToRun.isEmpty {
            DispatchQueue.main.async {
                self.status = "post-script skipped: no valid script selected"
            }
            return
        }
        
        let variablesJSON = variableDictionary().toJsonString()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var mergedUpdates: [String: String] = [:]
            
            for scriptItem in scriptsToRun {
                let script = scriptItem.command.trimmingCharacters(in: .whitespacesAndNewlines)
                if script.isEmpty { continue }
                
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
                    DispatchQueue.main.async {
                        self.status = "post-script[\(scriptItem.name)] fail: \(err)"
                    }
                    return
                }
                
                if output.isEmpty {
                    continue
                }
                
                let updates = self.parseVariableUpdates(from: output)
                if updates.isEmpty {
                    DispatchQueue.main.async {
                        self.status = "post-script[\(scriptItem.name)] fail: 输出格式无效"
                    }
                    return
                }
                
                for (key, value) in updates {
                    mergedUpdates[key] = value
                }
            }
            
            if mergedUpdates.isEmpty {
                DispatchQueue.main.async {
                    self.status = "complete (post-script no update)"
                }
                return
            }
            
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

    /// 这里做更正 header 和 parameters, 为之后抽取出公用脚本准备
    /// - Parameters:
    ///   - headers: 用户直接设置的头
    ///   - params: 用户直接设置的请求参数
    /// - Returns: 处理之后的请求头和参数
    func correct(headers: [String: String], params: [String: Any]) -> (headers: [String: String], params: [String: Any], response: Any?) {
        if !userScript.isEmpty {
            return runUserScript(userScript, headers: headers, params: params)
        }
        return (headers, params, nil)
    }
    
    // 运行用户脚本的函数
    func runUserScript(_ script: String, headers: [String: String], params: [String: Any]) -> (headers: [String: String], params: [String: Any], response: Any?) {
        
        let response: Any? = nil
        var rlt = ([String: String](), [String: Any](), response)
        if script.isEmpty {return rlt}
        
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        // 使用 /bin/bash 来执行用户的脚本
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        
        // 设置命令行参数，-c 参数表示执行传递的字符串，拼接 httpHeaders 和 httpParameters 作为传入参数
        let fullCommand = "\(script) '\(editor.urlString)' '\(editor.httpMethod.rawValue.uppercased())' '\(headers.toString() ?? "")' '\(params.toString() ?? "")'"
        process.arguments = ["-c", fullCommand]
        
        // 将标准输出和错误输出通过管道重定向
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        } catch {
            print("Failed to run the script: \(error)")
            self.status = "Failed to run the script: \(error)"
            return rlt
        }
        
        // 读取标准输出
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if let outputString = String(data: outputData, encoding: .utf8) {
            self.status = outputString
            let outputArr = outputString.split(separator: "\n", maxSplits: 100, omittingEmptySubsequences: true)
            for item in outputArr {
                let params = String(item).asParams()
                if params.isEmpty { continue }
                if params.keys.contains("headers") && params.keys.contains("parameters") {
                    if let h = params["headers"] as? [String: String], let p = params["parameters"] as? [String: Any] {
                        /*
                         如果脚本中参数经过摘要计算, 比如 md5 这类需要原样转发的数据, 则不能走此函数
                         因为 Dictionary 本身是 hash 表, 通过 json 解码之后的 key 是无序的,造成摘要错误
                         此场景适用于没有加密额外加密,且计算规则不想暴露的场合
                         */

                        rlt = (h, p, nil)
                        break
                    }
                }
                else if params.keys.contains("response") {
                    // 脚本直接进行网络请求并返回结果. 这种情况直接将结果返回, {"code":1,"message":"关键词不能为空"}
                    // 协议内容返回格式为 ["response": "jsonString..."]
                    rlt = ([:], [:], params["response"])
                    break
                }
            }
            print(self.status)
        }
        
        if let errorString = String(data: errorData, encoding: .utf8) {
            self.status = errorString
            print(self.status)
        }
        
        return rlt
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


