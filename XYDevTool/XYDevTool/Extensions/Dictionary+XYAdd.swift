//
//  Dictionary+XYAdd.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/8/11.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import Foundation

extension Dictionary where Key == String, Value == Any {
    /// 将字典转为 json 字符串
    /// - Returns: json字符串
    func toJsonString() -> String {
        do {
            // 将字典转换为JSON数据
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: [])
            
            // 将JSON数据转换为字符串并进行URL编码
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("Error converting dictionary to JSON: \(error)")
        }
        return ""
    }
    
    /// 此函数将字典内部所有的 value 都转换为 string 类型
    public func asHttpHeader() -> [String: Any] {
        var rlt = self
        for k in self.keys {
            if self[k] is Int {
                rlt[k] = "\(self[k]!)"
            }
            if self[k] is Double {
                rlt[k] = "\(self[k]!)"
            }
            if self[k] is String {
                rlt[k] = "\(self[k]!)"
            }
            if self[k] is Array<Any> { // array 待优化实现
                rlt[k] = "\(self[k]!)"
            }
            if let subDict = self[k] as? Dictionary<String,Any> {
                rlt[k] = subDict.asHttpHeader()
            }
        }
        return rlt
    }
}
