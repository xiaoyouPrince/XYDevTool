//
//  XYNetTool.swift
//  XYUIKit
//
//  Created by 渠晓友 on 2022/4/26.
//

/*
 一个简单的 网络工具，用于开发过程中的网络请求/网络连接状态判断
 */

public typealias NetTool = XYNetTool
public struct XYNetTool {
    private init () {}
    
    public typealias AnyJsonCallback = ([String: Any])->()
    public typealias DataCallback = (Data)->()
    public typealias ErrorCallback = (_ errMsg: String)->()
    public typealias DownloadDataCallback = (_ filePath: URL?, _ error: Error?)->()
    
    /// GET 方式请求获取 JSON 数据
    /// - Parameters:
    ///   - url: 网络地址
    ///   - headers: 请求头
    ///   - success: 成功回调, 返回 json dictionary
    ///   - failure: 失败回调
    public static func get(url: URL,
                           paramters: [String: Any],
                           headers: [String: String]?,
                           success: @escaping AnyJsonCallback,
                           failure: @escaping ErrorCallback) {
        request(url: url, method: .GET, paramters: paramters, headers: headers, success: success, failure: failure)
    }
    
    /// POST 方式请求获取 JSON 数据
    /// - Parameters:
    ///   - url: 网络地址
    ///   - paramters: 请求参数
    ///   - headers: 请求头
    ///   - success: 成功回调, 返回 json dictionary
    ///   - failure: 失败回调
    public static func post(url: URL,
                            paramters: [String: Any],
                            headers: [String: String]?,
                            success: @escaping AnyJsonCallback,
                            failure: @escaping ErrorCallback) {
        request(url: url, method: .POST, paramters: paramters, headers: headers, success: success, failure: failure)
    }
    
    /// 下载数据, 直接返回网络接口拿到的 Data 数据
    /// - Parameters:
    ///   - url: 网络地址
    ///   - paramters: 请求参数
    ///   - headers: 请求头
    ///   - success: 成功回调, 参数为网络拿到的 Data 数据
    ///   - failure: 失败回调
    public static func download(url: URL,
                                paramters: [String: Any],
                                headers: [String: String]?,
                                success: @escaping DataCallback,
                                failure: @escaping ErrorCallback) {
        request(url: url, method: .POST, paramters: paramters, headers: headers, success: success, failure: failure)
    }
    
    /// 下载文件到指定 URL 地址(GET)
    /// - Parameters:
    ///   - url: 网络地址
    ///   - paramters: 请求参数
    ///   - headers: 请求头
    ///   - saveToUrl: 文件指定要存储的 fileURL
    ///   - completion: 完成回调, 参数为当前文件存储地址(成功的情况下为saveToUrl), 或者失败后的 error 信息
    public static func download(url: URL,
                                paramters: [String: Any],
                                headers: [String: String]?,
                                saveToUrl: URL,
                                completion: @escaping DownloadDataCallback) {
        request(url: url, method: .GET, paramters: paramters, headers: headers, saveToUrl: saveToUrl, completion: completion)
    }
    
}


private extension XYNetTool {
    enum RequestType: String {
        case GET, POST
    }
    
    /*
     目前支持:
     post / get 返回格式: ([String: Any])->()
     download 返回格式 (Data)->()
     */
    
    static func request(url: URL,
                        method: RequestType,
                        paramters: [String: Any],
                        headers: [String: String]?,
                        success: Any,
                        failure: @escaping (String)->()){
        
        let (request, session) = getRequestAndSession(url: url, method: method, paramters: paramters, headers: headers)
        
        session.dataTask(with: request) { data, response, error in
            if error != nil { // 网络异常
                DispatchQueue.main.async {
                    failure(error!.localizedDescription)
                }
                return;
            }
            
            // JSON 格式处理
            if let success = success as? AnyJsonCallback {
                if let data = data, let resultJson = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed), let dict = resultJson as? [String: Any] {
                    DispatchQueue.main.async {
                        success(dict)
                    }
                }else{
                    DispatchQueue.main.async {
                        failure(error?.localizedDescription ?? "")
                    }
                }
            }
            
            // 下载数据类型
            if let success = success as? DataCallback {
                success(data ?? .init())
            }
        }.resume()
    }
    
    static func request(url: URL,
                        method: RequestType,
                        paramters: [String: Any],
                        headers: [String: String]?,
                        saveToUrl: URL,
                        completion: @escaping DownloadDataCallback) {
        
        let (request, session) = getRequestAndSession(url: url, method: method, paramters: paramters, headers: headers)
        
        session.downloadTask(with: request) { tmpFileUrl, urlResponse, error in
            if let tmpFileUrl = tmpFileUrl {
                do {
                    try FileManager.default.moveItem(at: tmpFileUrl, to: saveToUrl)
                    completion(saveToUrl, nil)
                }catch{
                    print("NetTool download task did fail to move file with error: \(error.localizedDescription)")
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }.resume()
    }
    
    
    static func getRequestAndSession(url: URL,
                                     method: RequestType,
                                     paramters: [String: Any],
                                     headers: [String: String]?) -> (URLRequest, URLSession){
        let request = NSMutableURLRequest(url: url)
        request.timeoutInterval = 10
        request.httpMethod = method.rawValue
        
        if method == .GET {
            if paramters.isEmpty == false {
                var pStr = "?"
                paramters.forEach { (k, v) in
                    pStr.append("\(k)=\(v)&")
                }
                let pStrResult = String(pStr.dropLast())
                request.url = URL(string: url.absoluteString + pStrResult)
            }
        }else
        if method == .POST {
            
            
            
            if let data = try? JSONSerialization.data(withJSONObject: paramters, options: .fragmentsAllowed) {
                
                
                
                print("data ----- \(data)")
                print("dataString ----- \(String(data: data, encoding: .utf8))")
                
                request.httpBody = data
            }
        }
        
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue.main)
        
        return (request as URLRequest, session)
    }
}

