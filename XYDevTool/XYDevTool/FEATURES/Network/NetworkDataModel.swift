//
//  NetworkDataModel.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import Foundation

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

class NetworkDataModel: ObservableObject, BaseDataProtocol {
    
    @Published var requesName: String = ""
    @Published var isLock: Bool = true {
        didSet {
            currentHistory?.isLock = isLock
        }
    }
    @Published var urlString: String = ""
    @Published var httpMethod: HttpMethod = .get
    @Published var httpHeaders: String = ""
    @Published var httpParameters: String = ""
    @Published var httpResponse: String = ""
    @Published var historyArray: [XYItem] = [] {
        didSet {
            print("didset")
            updateHistory()
        }
    }
    @Published var status: String = "Ready"
    
    @Published private(set) var currentHistory: XYItem?
    
    @Published var userScript: String = ""
    @Published var selectedPostScriptIDsForCurrent: [String] = [] {
        didSet {
            syncCurrentScriptSelection()
        }
    }
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
    
    init() {
        // init history
        if let data = NSData(contentsOfFile: history_path), let historys = MyObj.mapping(jsonData: data as Data) {
            historyArray = historys.item ?? []
        }
        loadVariables()
        loadGlobalPostScripts()
    }
}

extension NetworkDataModel {
    func exportNetworkConfigs(to folderURL: URL) throws {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let historyItems = historyArray.map { $0.toDictionary() }
        let historyDict: [String: Any] = ["item": historyItems]
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
        guard let historys = MyObj.mapping(jsonData: historyData) else {
            throw VariableResolveError(message: "导入失败：network_history.json 格式无效")
        }
        
        let decoder = JSONDecoder()
        let importedVariables = try decoder.decode([NetworkVariable].self, from: Data(contentsOf: variablesURL))
        let importedScripts = try decoder.decode([GlobalPostScript].self, from: Data(contentsOf: scriptsURL))
        
        historyArray = historys.item ?? []
        variables = importedVariables
        globalPostScripts = importedScripts
        currentHistory = nil
        selectedPostScriptIDsForCurrent = []
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
    
    
    /// 设置当前请求项, 当用户选择历史记录,则会将选中内容设置为当前项目
    /// - Parameter name: 名
    func setCurrentHistory(with name: String) {
        for item in historyArray {
            if item.name == name {
                self.currentHistory = item
                
                self.requesName = item.name ?? ""
                self.isLock = item.isLock ?? true
                self.urlString = item.request?.url ?? ""
                self.httpMethod = HttpMethod(rawValue: item.request?.method?.lowercased() ?? "") ?? .get
                self.httpHeaders = item.request?.header ?? ""
                self.httpParameters = item.request?.body ?? ""
                self.httpResponse = item.response ?? ""
                self.selectedPostScriptIDsForCurrent = item.selectedPostScriptIDs ?? []
                break
            }
        }
    }
    
    /// 更新历史记录列表
    func updateHistory() {
        
        // 每次关闭，写入最新数据
        let items = self.historyArray.map { item in
            item.toDictionary()
        }
        let dict = ["item": items]
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            let jsonStr = String(data: data, encoding: .utf8)
            try jsonStr?.write(toFile: history_path, atomically: true, encoding: .utf8)
            
            // showAlert(msg: jsonStr!)
            
        }catch{
            // 出错了，以后再说
            print(error)
        }
    }
    
    /// 开始发起请求
    func makeRequest() {
        if let variableError = validateVariablesBeforeRequest() {
            status = "request fail: \(variableError)"
            showAlert(msg: variableError)
            return
        }
        
        let urlStringApplied = applyVariables(to: urlString)
        let headersTextApplied = applyVariables(to: httpHeaders)
        let paramsTextApplied = applyVariables(to: httpParameters)

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
        item.isLock = isLock
        item.name = requesName
        item.selectedPostScriptIDs = selectedPostScriptIDsForCurrent
        let res = XYRequest()
        res.method = httpMethod.rawValue.uppercased()
        res.url = urlString
        res.header = httpHeaders
        res.body = httpParameters
        //res.url = urlStringApplied
        //res.header = headersTextApplied
        //res.body = paramsTextApplied
        item.request = res
        if item.name?.isEmpty == true {
            item.name = URL(string: urlString)?.host
            //item.name = URL(string: urlStringApplied)?.host
        }
        
        // 更正脚本, 如果直接返回 response 则直接展示
        let hp = correct(headers: headerDict, params: parameters)
        headerDict = hp.headers
        parameters = hp.params
        if let response = hp.response {
            self.httpResponse = response as? String ?? ""
            self.status = "complete"
            item.response = self.httpResponse
            self.updateHistory(with: item)
            return
        }
        
        let onSuccess: ([String: Any]) -> Void = { result in
            print("XYNetTool 请求成功 - \n\(result)")
            self.status = "complete"
            
            item.response = result.toJsonString()
            self.httpResponse = result.toJsonString()
            self.updateHistory(with: item)
            self.runPostResponseScriptIfNeeded(for: item, responseText: self.httpResponse)
        }
        
        let onFailure: (String) -> Void = { errMsg in
            print("XYNetTool 请求失败 - \n\(errMsg)")
            let message = errMsg.isEmpty ? "未知错误" : errMsg
            self.status = "request fail: \(message)"
        }
        
        switch httpMethod {
        case .get:
            XYNetTool.get(url: url, paramters: parameters, headers: headerDict, success: onSuccess, failure: onFailure)
        case .post:
            XYNetTool.post(url: url, paramters: parameters, headers: headerDict, success: onSuccess, failure: onFailure)
        }

    }
    
    
    /// 更新历史记录
    /// - Parameter with: 新记录
    func updateHistory(with item: XYItem) {
        var newItem: XYItem?
        for (idx, item_his) in self.historyArray.enumerated() {
            if item.name == item_his.name {
                item_his.update(with: item)
                newItem = item_his
                self.historyArray[idx...idx] = [item]
                break
            }
        }
        
        if newItem == nil {
            self.historyArray.append(item)
        }
        
        self.updateHistory()
        if currentHistory?.name == item.name {
            currentHistory = item
        }
    }
}

extension NetworkDataModel {
    private func syncCurrentScriptSelection() {
        guard let currentHistory else { return }
        currentHistory.selectedPostScriptIDs = selectedPostScriptIDsForCurrent
        updateHistory()
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
        let sanitizedCurrent = selectedPostScriptIDsForCurrent.filter { validIDs.contains($0) }
        if sanitizedCurrent != selectedPostScriptIDsForCurrent {
            selectedPostScriptIDsForCurrent = sanitizedCurrent
        }
        
        var hasHistoryChange = false
        for item in historyArray {
            let selected = item.selectedPostScriptIDs ?? []
            let sanitized = selected.filter { validIDs.contains($0) }
            if selected != sanitized {
                item.selectedPostScriptIDs = sanitized
                hasHistoryChange = true
            }
        }
        if hasHistoryChange {
            updateHistory()
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
        let fullCommand = "\(script) '\(urlString)' '\(httpMethod.rawValue.uppercased())' '\(headers.toString() ?? "")' '\(params.toString() ?? "")'"
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


