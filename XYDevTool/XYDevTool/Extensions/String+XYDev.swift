//
//  String+XYDev.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/6/6.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Foundation

extension String {
    
    /// 添加转义
    /// - Returns: 对于特殊字符进行转义
    public func addEscape() -> String {
        var result = removeEscape()
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        return result
    }
    
    /// 去除转义
    /// - Returns: 去除字符串内的转义字符
    public func removeEscape() -> String {
        
        let orign = self
        var result = ""
        
        // 0. 首尾是 \" 的字符串
        result = orign.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if result.hasPrefix("\"") {
            let firstIndex = result.startIndex...result.startIndex
            result = result.replacingCharacters(in: firstIndex, with: "")
        }
        if result.hasSuffix("\"") {
            let firstIndex = result.index(before: result.endIndex)..<result.endIndex
            result = result.replacingCharacters(in: firstIndex, with: "")
        }
        
        // 1. 去除 \
        result = result.replacingOccurrences(of: "\\", with: "")
        return result
    }
}

