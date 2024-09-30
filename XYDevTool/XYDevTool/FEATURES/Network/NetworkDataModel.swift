//
//  NetworkDataModel.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import Foundation

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
    
    @Published var userScript: String = "swift /Users/quxiaoyou/Desktop/Shell/swift.swift"//TimeZone.current.identifier
    
    init() {
        // init history
        if let data = NSData(contentsOfFile: history_path), let historys = MyObj.mapping(jsonData: data as Data) {
            historyArray = historys.item ?? []
        }
    }
}

extension NetworkDataModel {
    
    /// 设置当前请求项, 当用户选择历史记录,则会将选中内容设置为当前项目
    /// - Parameter name: 名
    func setCurrentHistory(with name: String) {
        for item in historyArray {
            if item.name == name {
                self.currentHistory = item
                
                self.requesName = item.name ?? ""
                self.isLock = item.isLock ?? true
                self.urlString = item.request?.url ?? ""
                self.httpHeaders = item.request?.header ?? ""
                self.httpParameters = item.request?.body ?? ""
                self.httpResponse = item.response ?? ""
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
        
        // url
        guard urlString.isEmpty == false else {
            showAlert(msg: "网址有误，输入正确的网址")
            return
        }
        status = ("请求中，当前小🌈会转起来，因为我故意阻塞了主线程😂。。。稍等一下！")
        
        var headerDict: [String: String] = [:]
        if let headers = self.httpHeaders.data(using: .utf8), let dict = try?  JSONSerialization.jsonObject(with: headers, options: .fragmentsAllowed) as? [String: Any]{
            headerDict = dict.reduce([:], { partialResult, new in
                var partialResult = partialResult
                partialResult[new.key] = "\(new.value)"
                return partialResult
            })
        }
        
        var parameters: [String: Any] = [:]
        if let params = httpParameters.data(using: .utf8), let dict = try?  JSONSerialization.jsonObject(with: params, options: .fragmentsAllowed) as? [String: Any] {
            parameters = dict
        }
        
        let item = XYItem()
        item.isLock = isLock
        item.name = requesName
        let res = XYRequest()
        res.method = httpMethod.rawValue.uppercased()
        res.url = urlString
        res.header = httpHeaders
        res.body = httpParameters
        item.request = res
        if item.name?.isEmpty == true {
            item.name = URL(string: urlString)?.host
        }
        
        // 更正脚本, 如果直接返回 response 则直接展示
        let hp = correct(headers: headerDict, params: parameters)
        headerDict = hp.headers
        parameters = hp.params
        if let response = hp.response {
            self.httpResponse = response as? String ?? ""
            self.status = "Complete"
            item.response = self.httpResponse
            self.updateHistory(with: item)
            return
        }
        

        XYNetTool.post(url: URL(string: urlString)!, paramters: parameters, headers: headerDict) { result in
            print("XYNetTool 请求成功 - \n\(result)")
            self.status = "complete"
            
            item.response = result.toJsonString()
            self.httpResponse = result.toJsonString()
            self.updateHistory(with: item)
        } failure: { errMsg in
            print("XYNetTool 请求失败 - \n\(errMsg)")
            self.status = "request fail"
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
    }
}

extension NetworkDataModel {

    /// 这里做更正 header 和 parameters, 为之后抽取出公用脚本准备
    /// - Parameters:
    ///   - headers: 用户直接设置的头
    ///   - params: 用户直接设置的请求参数
    /// - Returns: 处理之后的请求头和参数
    func correct(headers: [String: String], params: [String: Any]) -> (headers: [String: String], params: [String: Any], response: Any?) {
        return runUserScript(userScript, headers: headers, params: params)
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
        let fullCommand = "\(script) '\(headers.toString() ?? "")' '\(params.toString() ?? "")'"
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


