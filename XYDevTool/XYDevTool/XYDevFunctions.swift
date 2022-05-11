//
//  XYDevFunctions.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/3.
//

import Cocoa

public func showAlert(msg: String){
    
    let a = NSAlert()
    a.icon = NSImage(named: "im")
    a.messageText = msg
    a.runModal()
}

extension Collection {
    
    func toData() -> Data? {
        if let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) {
            return data
        }
        return nil
    }
    
    func toString() -> String? {
        if let data = toData(), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
}

func srting2JsonObject(string: String) -> [String: Any]? {
    
    if string.isEmpty {
        return [:]
    }
    
    // 1. 字符串无法直接转换成json egg:"{\n    \"code\": 200,  =》 需要先保存文件，直接从file读取，然后转JSON
    // 2. 直接将完整的 JSON 转换为可读数据
    
    // 去掉空格和换行先
    var str = string.trimmingCharacters(in: .whitespacesAndNewlines)
    // 去掉里面的转义字符
    str = str.replacingOccurrences(of: "\\", with: "")
    
    // 写入文件， Dict 读取文件
    let path = Bundle.main.resourcePath! + "/dict.json"
    try? str.write(toFile: path, atomically: true, encoding: .utf8)
    
    if let data = NSData(contentsOfFile: path){
        
        do {
            if let dict =  try JSONSerialization.jsonObject(with: (data as Data), options: .topLevelDictionaryAssumed) as? [String: Any]{
                // "转换完成"
                return dict
            }
            
        }catch{
            
            print(error)
            let err = error as NSError
            let errMsg = err.userInfo.description
            showAlert(msg: errMsg)
        }
    }
    
    return nil
}

