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
        
        // 这里确保使用脚本签名更正过的值
        // 先写死
        let hp = correct(headers: headerDict, params: parameters)
        headerDict = hp.headers
        parameters = hp.params
        
        print("当前请求体: --- \(hp.params)")
        print("当前请求体序列化: --- \(hp.params.toString())")
        
    
        var request: URLRequest! = nil
        if httpMethod == .post {
            request = URLRequest(url: URL(string: urlString)!, timeoutInterval: Double.infinity)
            request.httpBody = parameters.toData()
        } else {// GET
            var params = ""
            if let bodyDict = srting2JsonObject(string: httpParameters) {
                for (index, kv) in bodyDict.enumerated() {
                    if index == 0 {
                        params += "?" + "\(kv.key)=\(kv.value)"
                    } else {
                        params += "&" + "\(kv.key)=\(kv.value)"
                    }
                }
            }
            
            if urlString.contains(where: {$0 == "?"}), let index = urlString.firstIndex(of: "?") {
                
                if params.isEmpty == false { // GET 请求， URL有参数且也输入了 JOSN 参数，按JSON 参数取值
                    urlString = String(urlString[urlString.startIndex..<index])
                    
                }
            }
            
            urlString += params
            
            request = URLRequest(url: URL(string: urlString)!, timeoutInterval: Double.infinity)
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key,value) in headerDict {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        request.httpMethod = httpMethod.rawValue.uppercased()//methodBtn.selectedItem?.title
        
        let item = XYItem()
        item.isLock = isLock
        item.name = requesName
        let res = XYRequest()
        res.method = request.httpMethod
        res.url = urlString
        res.header = httpHeaders
        res.body = httpParameters
        item.request = res
        if item.name?.isEmpty == true {
            item.name = request.url?.host
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            print("系统 task 请求结果:")
            
            // 如果当前是选中的那个,就直接更新历史记录,否则添加一个新纪录
            var updateItem: XYItem? = nil
            if (self.currentHistory?.name ?? "") == item.name {
                for item_his in self.historyArray {
                    if item.name == item_his.name {
                        item_his.update(with: item)
                        updateItem = item_his
                        break
                    }
                }
            } else {
                self.historyArray.append(item)
            }
            print("请求结果线程 - ", Thread.current)
            
            guard let data = data else {
                let errMsg = String(describing: error.debugDescription)
                DispatchQueue.main.async {
                    self.status = "Failed"
                    self.httpResponse = errMsg
                    item.response = errMsg
                    if let updateItem = updateItem,
                       let index = self.historyArray.firstIndex(where: { item in
                           item.name == updateItem.name})
                    {
                        updateItem.response = errMsg
                        self.historyArray.replaceSubrange(index...index, with: [updateItem])
                    }
                    self.updateHistory()
                }
                print(errMsg)
                return
            }
            
            var sucString = String(data: data, encoding: .utf8)!
            if sucString.isEmpty {
                sucString = response?.description ?? "请求完成，返回数据为空"
            }
            print("请求成功,结果如下:\n",sucString)
            DispatchQueue.main.async {
                self.status = "complete"
                
                item.response = sucString
                self.httpResponse = sucString
                if let updateItem = updateItem,
                   let index = self.historyArray.firstIndex(where: { item in
                       item.name == updateItem.name})
                {
                    updateItem.response = sucString
                    self.historyArray.replaceSubrange(index...index, with: [updateItem])
                }
                self.updateHistory()
            }
        }
        
        print("准备发起请求线程 - ", Thread.current)
        DispatchQueue.global().async {
            print("发起请求线程 - ", Thread.current)
            //task.resume()
        }
        
        
        //-------
        print("发起的请求头:", headerDict)
        print("发起的请求体:", parameters)
        
        
        XYNetTool.post(url: URL(string: urlString)!, paramters: parameters, headers: headerDict) { result in
            print("XYNetTool 请求成功 - \n\(result)")
            self.status = "complete"
            
            item.response = result.toJsonString()
            self.httpResponse = result.toJsonString()

        } failure: { errMsg in
            print("XYNetTool 请求失败 - \n\(errMsg)")
        }

    }
}

extension NetworkDataModel {

    /// 这里做更正 header 和 parameters, 为之后抽取出公用脚本准备
    /// - Parameters:
    ///   - headers: 用户直接设置的头
    ///   - params: 用户直接设置的请求参数
    /// - Returns: 处理之后的请求头和参数
    func correct(headers: [String: String], params: [String: Any]) -> (headers: [String: String], params: [String: Any]) {
        
        if !userAgent.isEmpty {
            let newP = runUserScript(userScript, headers: headers, params: params)
            return newP
        }
        
        var headers = headers
        var parameters = params
        
        parameters.updateValue([
            "platform": "iPhone",
            "platformVersion": "18",
            "versionName": "2.1.0",
            "versionCode": "1",
            "timezone": "Asia/Shanghai",
            "width": "375",
            "height": "667",
        ], forKey: "client")
        
        let SECRETKEY = "b2zf3etid4beca121xasi9cwkfdc29p"
        
        let time = "1727605744123"//String(Int(Date().timeIntervalSince1970 * 1000))
        let string = parameters.toJsonString() + SECRETKEY + time
        
        let sign = string.md5
        print("parameters.toJsonString() == ", parameters.toJsonString())
        print("string = ",string)
        print("sign = ",sign)
        let token = "Ak+LXVNQVAMDUndoYHsK.Ak8NUEBQVBAoMHJgYWxFSExBRlRMAkwbKzl0bWdqQkNAWEgTVh0KAyUjOQVwKxIWEB4QVEYmB0x6XWBjY25GQUBeUQMNR1sRKC0eeycqEgMwCTgTDkBfF2IjPw==.z4UJm3rdQiKDc9onU9FC8XkhelqnmltT/LediF6hcsrAbCr1kdhBVpuN5BIV3cwEmPnMAivOrKw0c1tXr++U6w=="
        
        headers.updateValue(time, forKey: "Time")
        headers.updateValue(sign.uppercased(), forKey: "Sign")
        headers.updateValue(token, forKey: "Token")
        headers.updateValue("application/json", forKey: "Content-Type")
//        headers.updateValue(userAgent, forKey: "User-Agent")
        
        return (headers, parameters)
    }
    
    /// User-Agent
    private var userAgent: String {
        if _userAgent == nil {
            let versionName = "1.17.0"
            let modelName = "iPhone"
            let sys = "iOS 18"
            let scale = String(format: "%.2f", 2.0)
            
            let customUserAgent = "WidgetOn/\(versionName) (\(modelName); \(sys); Scale/\(scale))"
            _userAgent = customUserAgent
        }
        return _userAgent!
    }
    
    // 运行用户脚本的函数
    func runUserScript(_ script: String, headers: [String: String], params: [String: Any]) -> (headers: [String: String], params: [String: Any]) {
        
        var rlt = ([String: String](), [String: Any]())
        if script.isEmpty {return rlt}
        
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        // 使用 /bin/bash 来执行用户的脚本
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        
        print("脚本传入的参数 ---- \(params)")
        print("脚本传入的参数toString ---- \(params.toString())")
        
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
            for (idx,item) in outputArr.enumerated() {
                let params = String(item).asParams()
                if params.isEmpty { continue }
                if params.keys.contains("headers") && params.keys.contains("parameters") {
//                    rlt = (params["headers"], params["parameters"])
                    if let h = params["headers"] as? [String: String], let p = params["parameters"] as? [String: Any] {
                        
                        // 理论上输出都是字符串, 这里服务器也是以字符串接收的, 需要手动都转换为字符串
                        // 可能有的服务器是以 Any 接收的, 以后遇到再处理
                        
                        print("脚本返回的的参数原始数据 ---- \(outputString)") // 原始数据是对的
                        print("脚本返回的的参数params ---- \(params)") // params 经过从 outputString 一层转化,已经走样
                        print("脚本返回的的参数p ---- \(p)") // p 直接从 params 中获取,没有走样
                        print("脚本返回的的参数toString11111 ---- \(p.toJsonString())") // 再次走样
                        let ppp = p.asHttpHeader() // ppp 经过一层转化,再次走样
                        print("脚本返回的参数toString222222 ---- \(ppp.toJsonString())")
                        
                        // 经过测试,明确这里如果经过多次对 paramsDict 转换,导致其多次 key 顺序调整
                        // 当前这个 item 是目标值, 由于有做md5加密, 所以必须原样返回, idx 是索引
                        
                        print("\n")
                        print("脚本返回的的参数原始数据正确的 ---- \(outputString)") // 原始数据是对的
                        print("脚本返回的的参数原始数据 item ---- \(item)") // 原始数据是对的
                        print("脚本返回的的参数原始数据 item.toDict ---- \(String(item).asParams())") // 原始数据是对的
                        
                        
                        
                        
                        
                        rlt = (h, p)
                        break
                    }
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

func getDict(targrtString: String) -> [String: Any] {
    let dict = String(targrtString).asParams()
    let tar = dict.toJsonString()
    
    
    print(tar)
    print(targrtString)
    
    
    if tar == targrtString {
        return dict
    } else {
        return getDict(targrtString: targrtString)
    }
}

var _userAgent: String?

/*
 创建配置<请求地址> -- 生成配置列表
 每个请求可以设置当前使用的配置
 */


/* 
 
 swift /Users/quxiaoyou/Desktop/Shell/swift.swift
 
 1. 支持传入两个参数, 均为字符串类型, 第一个是请求头,第二个是请求体
 2. 必须有一个输出值类型是一个 json 对象, 有两个参数 {"headers": ..., "parameters": ...}
 
 搜索
 https://stage.widget.haoqimiao.net/api/search/resource
 {"search":  "桌面"}
 
 */


