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
}
