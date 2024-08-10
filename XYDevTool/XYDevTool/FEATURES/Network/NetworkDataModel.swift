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
        if let headers = self.httpHeaders.data(using: .utf8), let dict = try?  JSONSerialization.jsonObject(with: headers, options: .fragmentsAllowed) as? [String: String]{
            headerDict = dict
        }
        
        let parameters = ""//bodyTV.string
        let postData = parameters.data(using: .utf8)
        
        // md: 这不是 Apple 的问题就是接口的问题。
        // 下面两个创建 request 的方式必须要直接用 string 实例来创建，草。。。浪费大半天时间
        // md: 必须直接用 urlTF.stringValue 创建 URL，入参数是 上面 url.absoutString 都不行
        // 实际上都能建立链接，但是接口返回的 下面的方式就是 200，反之就是 404 找不到请求的路径。 fuck！！！
        
        //var request = URLRequest(url: URL(string: "http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent")!,timeoutInterval: Double.infinity)
        
        var request: URLRequest! = nil
//        if methodBtn.selectedItem?.title == "POST" {
//            request = URLRequest(url: URL(string: urlTF.stringValue)!, timeoutInterval: Double.infinity)
//            request.httpBody = postData
//        }else{// GET
            var params = ""
//            if let bodyDict = srting2JsonObject(string: bodyTV.string) {
//                for (index, kv) in bodyDict.enumerated() {
//                    if index == 0 {
//                        params += "?" + "\(kv.key)=\(kv.value)"
//                    }else{
//                        params += "&" + "\(kv.key)=\(kv.value)"
//                    }
//                }
//            }
//            
//            if urlTF.stringValue.contains(where: {$0 == "?"}), let index = urlTF.stringValue.firstIndex(of: "?") {
//                
//                if params.isEmpty == false { // GET 请求， URL有参数且也输入了 JOSN 参数，按JSON 参数取值
//                    urlTF.stringValue = String(urlTF.stringValue[urlTF.stringValue.startIndex..<index])
//                }
//            }
//            
            request = URLRequest(url: URL(string: urlString)!, timeoutInterval: Double.infinity)
//        }
        
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
        res.url = request.url?.absoluteString
        res.header = headerDict.toString() ?? ""
        //res.body = bodyTV.string
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
        
        // 每次请求之后保存到本地。 暂时以 URL 做key，去重，后续扩展一个用户自定义名称来做 key
        
        
        
    }
}
