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
            task.resume()
        }
        
        
        //-------
        XYNetTool.post(url: URL(string: urlString)!, paramters: parameters, headers: headerDict) { result in
            print("请求成功 - \n\(result)")
        } failure: { errMsg in
            print("请求失败 - \n\(errMsg)")
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
        
        var headers = headers
        var parameters = params
        
        parameters.updateValue([
            "platform": "iPhone",
            "platformVersion": "18",
            "versionName": "1.17.0",
            "versionCode": "1",
            "timezone": TimeZone.current.identifier,
            "width": "375",
            "height": "667",
        ], forKey: "client")
        
        let SECRETKEY = "b2zf3etid4beca121xasi9cwkfdc29p"
        
        let time = String(Int(Date().timeIntervalSince1970 * 1000))
        let string = parameters.toJsonString() + SECRETKEY + time
        let sign = string.md5
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
}

var _userAgent: String?

/*
 创建配置<请求地址> -- 生成配置列表
 每个请求可以设置当前使用的配置
 */
